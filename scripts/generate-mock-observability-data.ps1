Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    Split-Path -Parent $PSScriptRoot
}

function Get-PodName {
    param(
        [string]$Namespace,
        [string]$Label
    )

    $pod = kubectl get pods -n $Namespace -l $Label -o jsonpath="{.items[0].metadata.name}"
    if (-not $pod) {
        throw "Pod not found for $Label in namespace $Namespace."
    }
    return $pod.Trim()
}

function Wait-HttpReady {
    param(
        [string]$Url,
        [int]$Attempts = 30
    )

    for ($i = 0; $i -lt $Attempts; $i++) {
        try {
            Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2 | Out-Null
            return
        } catch {
            Start-Sleep -Seconds 1
        }
    }

    throw "Timed out waiting for $Url"
}

function New-MetricSampleLine {
    param(
        [string]$MetricName,
        [string]$Labels,
        [double]$Value,
        [long]$TimestampMs
    )

    $formattedValue = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0:0.###}", $Value)
    return "$MetricName{$Labels} $formattedValue $TimestampMs"
}

function Add-StreamEntry {
    param(
        [hashtable]$Streams,
        [string]$App,
        [datetimeoffset]$Timestamp,
        [hashtable]$Payload
    )

    $json = ($Payload | ConvertTo-Json -Compress -Depth 4)
    $epochNanos = (($Timestamp.ToUnixTimeMilliseconds()) * 1000000).ToString()
    $Streams[$App].Add(@($epochNanos, $json))
}

function Get-RequestRatePerMinute {
    param(
        [string]$ServiceName,
        [int]$MinuteOfDay
    )

    $hour = [math]::Floor($MinuteOfDay / 60)
    $baseRate =
        if ($hour -lt 6) { 10 }
        elseif ($hour -lt 9) { 18 }
        elseif ($hour -lt 18) { 28 }
        elseif ($hour -lt 22) { 20 }
        else { 12 }

    $jitter = ($MinuteOfDay % 7) - 3
    $rate = $baseRate + $jitter

    if ($MinuteOfDay -ge 1380 -and $MinuteOfDay -lt 1410) {
        $rate = 210 + (($MinuteOfDay * 11) % 45)
    }

    switch ($ServiceName) {
        "product" { return [math]::Max(1, [math]::Round($rate * 0.98, 0)) }
        "images" { return [math]::Max(1, [math]::Round($rate * 0.95, 0)) }
        default { return [math]::Max(1, $rate) }
    }
}

function New-MockDataset {
    $scenarioDate = [DateTimeOffset]::Now.Date.AddDays(-1)
    $start = [DateTimeOffset]::new($scenarioDate.Year, $scenarioDate.Month, $scenarioDate.Day, 0, 0, 0, [TimeSpan]::Zero)

    $services = @(
        @{
            Name = "ecommerce"
            MaxMb = 768
            PostGcMb = 210
            GrowthFactor = 0.90
            BaseThreads = 24
            NormalGcInterval = 90
        },
        @{
            Name = "product"
            MaxMb = 512
            PostGcMb = 150
            GrowthFactor = 0.62
            BaseThreads = 16
            NormalGcInterval = 110
        },
        @{
            Name = "images"
            MaxMb = 384
            PostGcMb = 105
            GrowthFactor = 0.48
            BaseThreads = 14
            NormalGcInterval = 120
        }
    )

    $metricLines = [System.Collections.Generic.List[string]]::new()
    $streams = @{
        ecommerce = [System.Collections.Generic.List[object]]::new()
        product   = [System.Collections.Generic.List[object]]::new()
        images    = [System.Collections.Generic.List[object]]::new()
    }

    $headers = @(
        "# TYPE jvm_memory_used_bytes gauge",
        "# TYPE jvm_memory_max_bytes gauge",
        "# TYPE jvm_threads_live_threads gauge",
        "# TYPE jvm_gc_pause_seconds_count counter",
        "# TYPE jvm_gc_pause_seconds_sum counter",
        "# TYPE jvm_gc_pause_seconds_max gauge",
        "# TYPE http_server_requests_seconds_count counter"
    )
    foreach ($header in $headers) {
        $metricLines.Add($header)
    }

    $serviceState = @{}
    $ecommerceGcEvents = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($service in $services) {
        $serviceState[$service.Name] = @{
            UsedMb = [double]$service.PostGcMb
            MinutesSinceGc = 0
            NextGcInterval = [int]$service.NormalGcInterval
            GcCount = 0.0
            GcSumSeconds = 0.0
            GcMaxSeconds = 0.0
            RequestCounter = 0.0
        }
    }

    for ($minute = 0; $minute -lt 1440; $minute++) {
        $timestamp = $start.AddMinutes($minute)
        $timestampMs = $timestamp.ToUnixTimeMilliseconds()
        $inBatchBurst = $minute -ge 1380 -and $minute -lt 1410

        foreach ($service in $services) {
            $name = $service.Name
            $state = $serviceState[$name]
            $requests = [double](Get-RequestRatePerMinute -ServiceName $name -MinuteOfDay $minute)
            $jitter = (($minute + $name.Length) % 5) - 2
            $batchThreadBoost = if ($inBatchBurst) { 14 } else { 0 }
            $gcInterval = if ($inBatchBurst) { 10 } else { [int]$service.NormalGcInterval }
            $heapGrowthMb = ($requests * $service.GrowthFactor / 10.0) + (0.12 * $service.BaseThreads) + (($minute % 4) * 0.7)
            $heapBeforeGc = $state.UsedMb + $heapGrowthMb
            $gcTriggered = $false
            $gcPauseSeconds = 0.0

            if ($state.MinutesSinceGc -ge $state.NextGcInterval) {
                $gcTriggered = $true
                $gcPauseSeconds =
                    if ($inBatchBurst) {
                        0.8 + ((($minute + $name.Length) % 7) * 0.18)
                    } else {
                        2.4 + ((($minute + $name.Length) % 6) * 0.42)
                    }

                $state.GcCount += 1
                $state.GcSumSeconds += $gcPauseSeconds
                $state.GcMaxSeconds = [math]::Max($state.GcMaxSeconds, $gcPauseSeconds)
                $state.UsedMb = $service.PostGcMb + (($minute + $name.Length) % 12)
                $state.MinutesSinceGc = 0
                $state.NextGcInterval = $gcInterval + ((($minute + $name.Length) % 5) - 2)

                if ($name -eq "ecommerce") {
                    $ecommerceGcEvents.Add(@{
                        Timestamp = $timestamp
                        PauseMs = [int]([math]::Round($gcPauseSeconds * 1000, 0))
                        HeapBeforeMb = [int]([math]::Round($heapBeforeGc, 0))
                        HeapAfterMb = [int]([math]::Round($state.UsedMb, 0))
                    })
                }
            } else {
                $state.UsedMb = [math]::Min($service.MaxMb * 0.93, $heapBeforeGc)
                $state.MinutesSinceGc += 1
            }

            $threads = [math]::Max(
                $service.BaseThreads,
                $service.BaseThreads + [math]::Round($requests / 6.0, 0) + $jitter + $batchThreadBoost
            )
            $state.RequestCounter += $requests

            $jobLabel = "job=`"$name`""
            $heapLabels = "$jobLabel,area=`"heap`""
            $metricLines.Add((New-MetricSampleLine -MetricName "jvm_memory_used_bytes" -Labels $heapLabels -Value ($state.UsedMb * 1MB) -TimestampMs $timestampMs))
            $metricLines.Add((New-MetricSampleLine -MetricName "jvm_memory_max_bytes" -Labels $heapLabels -Value ($service.MaxMb * 1MB) -TimestampMs $timestampMs))
            $metricLines.Add((New-MetricSampleLine -MetricName "jvm_threads_live_threads" -Labels $jobLabel -Value $threads -TimestampMs $timestampMs))
            $metricLines.Add((New-MetricSampleLine -MetricName "jvm_gc_pause_seconds_count" -Labels $jobLabel -Value $state.GcCount -TimestampMs $timestampMs))
            $metricLines.Add((New-MetricSampleLine -MetricName "jvm_gc_pause_seconds_sum" -Labels $jobLabel -Value $state.GcSumSeconds -TimestampMs $timestampMs))
            $metricLines.Add((New-MetricSampleLine -MetricName "jvm_gc_pause_seconds_max" -Labels $jobLabel -Value $state.GcMaxSeconds -TimestampMs $timestampMs))
            $metricLines.Add((New-MetricSampleLine -MetricName "http_server_requests_seconds_count" -Labels $jobLabel -Value $state.RequestCounter -TimestampMs $timestampMs))
        }
    }

    foreach ($serviceName in @("ecommerce", "product", "images")) {
        Add-StreamEntry -Streams $streams -App $serviceName -Timestamp $start.AddMinutes(1) -Payload @{
            timestamp = $start.AddMinutes(1).ToString("o")
            service = $serviceName
            level = "INFO"
            correlationId = [guid]::NewGuid().ToString()
            thread = "main"
            logger = "$serviceName.bootstrap"
            message = "Mock scenario data load marker for $serviceName"
        }
    }

    for ($minute = 0; $minute -lt 1440; $minute += 15) {
        $requestTime = $start.AddMinutes($minute).AddSeconds(($minute % 11) + 3)
        $correlationId = [guid]::NewGuid().ToString()
        $batchBurst = $minute -ge 1380 -and $minute -lt 1410
        $slowAroundGc = $ecommerceGcEvents | Where-Object {
            [math]::Abs((New-TimeSpan -Start $_.Timestamp -End $requestTime).TotalMinutes) -le 2
        } | Select-Object -First 1

        $productDuration = 45 + (($minute * 3) % 40)
        $imagesDuration = 30 + (($minute * 5) % 25)
        $ecommerceDuration =
            if ($slowAroundGc) {
                $slowAroundGc.PauseMs + 400 + (($minute * 13) % 1200)
            } elseif ($batchBurst) {
                420 + (($minute * 7) % 180)
            } else {
                120 + (($minute * 9) % 110)
            }

        Add-StreamEntry -Streams $streams -App "ecommerce" -Timestamp $requestTime -Payload @{
            timestamp = $requestTime.ToString("o")
            service = "ecommerce"
            level = "INFO"
            correlationId = $correlationId
            thread = "http-nio-8090-exec-" + (($minute % 9) + 1)
            logger = "com.amol.microservices.ecommerce.controller.ProductController"
            message = "Received GET /ecommerce-service/ecommerceProducts"
        }
        Add-StreamEntry -Streams $streams -App "product" -Timestamp $requestTime.AddMilliseconds(18) -Payload @{
            timestamp = $requestTime.AddMilliseconds(18).ToString("o")
            service = "product"
            level = "INFO"
            correlationId = $correlationId
            thread = "http-nio-8090-exec-" + (($minute % 7) + 1)
            logger = "com.amol.microservices.product.controller.ProductController"
            message = "Served GET /product-service/products durationMs=$productDuration"
        }
        Add-StreamEntry -Streams $streams -App "images" -Timestamp $requestTime.AddMilliseconds(24) -Payload @{
            timestamp = $requestTime.AddMilliseconds(24).ToString("o")
            service = "images"
            level = "INFO"
            correlationId = $correlationId
            thread = "http-nio-8090-exec-" + (($minute % 6) + 1)
            logger = "com.amol.microservices.images.controller.ImageController"
            message = "Served GET /image-service/images durationMs=$imagesDuration"
        }
        Add-StreamEntry -Streams $streams -App "ecommerce" -Timestamp $requestTime.AddMilliseconds($ecommerceDuration) -Payload @{
            timestamp = $requestTime.AddMilliseconds($ecommerceDuration).ToString("o")
            service = "ecommerce"
            level = ($(if ($slowAroundGc) { "WARN" } else { "INFO" }))
            correlationId = $correlationId
            thread = "http-nio-8090-exec-" + (($minute % 9) + 1)
            logger = "com.amol.microservices.ecommerce.assembler.ProductAssembler"
            message = "Completed GET /ecommerce-service/ecommerceProducts durationMs=$ecommerceDuration"
        }
    }

    foreach ($gcEvent in $ecommerceGcEvents) {
        Add-StreamEntry -Streams $streams -App "ecommerce" -Timestamp $gcEvent.Timestamp -Payload @{
            timestamp = $gcEvent.Timestamp.ToString("o")
            service = "ecommerce"
            level = "WARN"
            correlationId = [guid]::NewGuid().ToString()
            thread = "VM Thread"
            logger = "com.amol.microservices.ecommerce.jvm.GcMonitor"
            message = "Full GC pause detected durationMs=$($gcEvent.PauseMs) heapBeforeMb=$($gcEvent.HeapBeforeMb) heapAfterMb=$($gcEvent.HeapAfterMb)"
        }

        for ($i = 0; $i -lt 3; $i++) {
            $requestTime = $gcEvent.Timestamp.AddSeconds(($i * 14) - 18)
            $correlationId = [guid]::NewGuid().ToString()
            $slowDuration = $gcEvent.PauseMs + 800 + ($i * 260)

            Add-StreamEntry -Streams $streams -App "product" -Timestamp $requestTime.AddMilliseconds(40) -Payload @{
                timestamp = $requestTime.AddMilliseconds(40).ToString("o")
                service = "product"
                level = "INFO"
                correlationId = $correlationId
                thread = "http-nio-8090-exec-" + ($i + 2)
                logger = "com.amol.microservices.product.controller.ProductController"
                message = "Served GET /product-service/products durationMs=" + (75 + ($i * 12))
            }
            Add-StreamEntry -Streams $streams -App "images" -Timestamp $requestTime.AddMilliseconds(55) -Payload @{
                timestamp = $requestTime.AddMilliseconds(55).ToString("o")
                service = "images"
                level = "INFO"
                correlationId = $correlationId
                thread = "http-nio-8090-exec-" + ($i + 2)
                logger = "com.amol.microservices.images.controller.ImageController"
                message = "Served GET /image-service/images durationMs=" + (58 + ($i * 9))
            }
            Add-StreamEntry -Streams $streams -App "ecommerce" -Timestamp $requestTime.AddMilliseconds($slowDuration) -Payload @{
                timestamp = $requestTime.AddMilliseconds($slowDuration).ToString("o")
                service = "ecommerce"
                level = "WARN"
                correlationId = $correlationId
                thread = "http-nio-8090-exec-" + ($i + 4)
                logger = "com.amol.microservices.ecommerce.assembler.ProductAssembler"
                message = "Completed GET /ecommerce-service/ecommerceProducts durationMs=$slowDuration impactedByFullGc=true"
            }
        }
    }

    for ($minute = 1380; $minute -lt 1410; $minute++) {
        $eventTime = $start.AddMinutes($minute).AddSeconds(7)
        $correlationId = [guid]::NewGuid().ToString()
        $ecommerceDuration = 540 + (($minute * 19) % 210)
        $productDuration = 110 + (($minute * 5) % 55)
        $imagesDuration = 85 + (($minute * 3) % 35)

        Add-StreamEntry -Streams $streams -App "ecommerce" -Timestamp $eventTime -Payload @{
            timestamp = $eventTime.ToString("o")
            service = "ecommerce"
            level = "INFO"
            correlationId = $correlationId
            thread = "batch-runner-" + (($minute % 4) + 1)
            logger = "com.amol.microservices.ecommerce.jobs.NightlyBatchJob"
            message = "Batch job request queued for product aggregation"
        }
        Add-StreamEntry -Streams $streams -App "product" -Timestamp $eventTime.AddMilliseconds(35) -Payload @{
            timestamp = $eventTime.AddMilliseconds(35).ToString("o")
            service = "product"
            level = "INFO"
            correlationId = $correlationId
            thread = "http-nio-8090-exec-" + (($minute % 8) + 1)
            logger = "com.amol.microservices.product.controller.ProductController"
            message = "Served GET /product-service/products durationMs=$productDuration"
        }
        Add-StreamEntry -Streams $streams -App "images" -Timestamp $eventTime.AddMilliseconds(42) -Payload @{
            timestamp = $eventTime.AddMilliseconds(42).ToString("o")
            service = "images"
            level = "INFO"
            correlationId = $correlationId
            thread = "http-nio-8090-exec-" + (($minute % 7) + 1)
            logger = "com.amol.microservices.images.controller.ImageController"
            message = "Served GET /image-service/images durationMs=$imagesDuration"
        }
        Add-StreamEntry -Streams $streams -App "ecommerce" -Timestamp $eventTime.AddMilliseconds($ecommerceDuration) -Payload @{
            timestamp = $eventTime.AddMilliseconds($ecommerceDuration).ToString("o")
            service = "ecommerce"
            level = "WARN"
            correlationId = $correlationId
            thread = "batch-runner-" + (($minute % 4) + 1)
            logger = "com.amol.microservices.ecommerce.jobs.NightlyBatchJob"
            message = "Batch job request completed durationMs=$ecommerceDuration highLoadWindow=true"
        }

        if (($minute % 5) -eq 0) {
            foreach ($serviceName in @("ecommerce", "product", "images")) {
                Add-StreamEntry -Streams $streams -App $serviceName -Timestamp $eventTime.AddMilliseconds(80) -Payload @{
                    timestamp = $eventTime.AddMilliseconds(80).ToString("o")
                    service = $serviceName
                    level = "WARN"
                    correlationId = [guid]::NewGuid().ToString()
                    thread = "monitor-" + (($minute % 3) + 1)
                    logger = "com.amol.microservices.$serviceName.runtime.LoadMonitor"
                    message = "High request load detected activeThreads=" + (42 + ($minute % 9)) + " gcPressure=moderate"
                }
            }
        }
    }

    return @{
        ScenarioDate = $start
        MetricLines = $metricLines
        Streams = $streams
    }
}

$rootDir = Get-RepoRoot
$tempDir = Join-Path $rootDir ".mock-observability-data"
$metricsFile = Join-Path $tempDir "mock-prometheus.om"
$blocksDir = Join-Path $tempDir "blocks"

if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}
New-Item -ItemType Directory -Path $tempDir | Out-Null
New-Item -ItemType Directory -Path $blocksDir | Out-Null

$dataset = New-MockDataset
[void]$dataset.MetricLines.Add("# EOF")
[System.IO.File]::WriteAllLines($metricsFile, $dataset.MetricLines)

$prometheusPod = Get-PodName -Namespace "observability" -Label "app=prometheus"
$lokiPod = Get-PodName -Namespace "observability" -Label "app=loki"

Write-Host "Clearing existing Prometheus data..."
kubectl exec -n observability $prometheusPod -- sh -c "rm -rf /prometheus/* && mkdir -p /prometheus"

Write-Host "Generating Prometheus TSDB blocks..."
& docker run --rm -v "${tempDir}:/work" prom/prometheus:v2.54.1 promtool tsdb create-blocks-from openmetrics /work/mock-prometheus.om /work/blocks
if ($LASTEXITCODE -ne 0) {
    throw "promtool block creation failed."
}

$blockFolders = Get-ChildItem -Path $blocksDir -Directory
if ($blockFolders.Count -eq 0) {
    throw "No Prometheus blocks were generated."
}

foreach ($blockFolder in $blockFolders) {
    kubectl cp $blockFolder.FullName "observability/${prometheusPod}:/prometheus/$($blockFolder.Name)"
}

kubectl rollout restart deployment/prometheus -n observability | Out-Null
kubectl rollout status deployment/prometheus -n observability

Write-Host "Clearing existing Loki data..."
kubectl exec -n observability $lokiPod -- sh -c "rm -rf /loki/chunks/* /loki/index/* /loki/boltdb-cache/* /loki/rules/*"
kubectl rollout restart deployment/loki -n observability | Out-Null
kubectl rollout status deployment/loki -n observability

$portForward = Start-Process -FilePath "kubectl" -ArgumentList @("port-forward", "-n", "observability", "svc/loki", "3100:3100", "--address", "127.0.0.1") -PassThru -WindowStyle Hidden

try {
    Wait-HttpReady -Url "http://127.0.0.1:3100/ready"

    foreach ($app in @("ecommerce", "product", "images")) {
        $entries = $dataset.Streams[$app]
        for ($offset = 0; $offset -lt $entries.Count; $offset += 500) {
            $end = [math]::Min($offset + 499, $entries.Count - 1)
            $values = @()
            for ($i = $offset; $i -le $end; $i++) {
                $values += ,$entries[$i]
            }

            $payload = @{
                streams = @(
                    @{
                        stream = @{
                            namespace = "ecommerce"
                            app = $app
                            service = $app
                        }
                        values = $values
                    }
                )
            } | ConvertTo-Json -Compress -Depth 8

            Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:3100/loki/api/v1/push" -ContentType "application/json" -Body $payload | Out-Null
        }
    }
} finally {
    if ($portForward -and -not $portForward.HasExited) {
        Stop-Process -Id $portForward.Id -Force
    }
}

Write-Host ""
Write-Host "Mock observability data inserted successfully."
Write-Host "Scenario date: $($dataset.ScenarioDate.ToString("yyyy-MM-dd")) UTC"
Write-Host "Scenario 1: full-day ecommerce sawtooth heap with slow requests during full GC."
Write-Host "Scenario 2: 23:00-23:30 high load burst with elevated threads and more frequent GC."
