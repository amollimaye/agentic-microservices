import argparse
import datetime as dt
import http.server
import json
import math
import os
import pathlib
import random
import socketserver
import threading
import time
from typing import Dict, List


ROOT = pathlib.Path(__file__).resolve().parent.parent
METRICS_DIR = ROOT / "generated-metrics"
LOGS_DIR = ROOT / "generated-logs"
STATE_FILE = METRICS_DIR / "manifest.json"
SEED = 20260513
SCENARIO_DATE = dt.date(2026, 5, 13)
SERVICES = ["ecommerce", "product", "images", "observability-agent"]
METRIC_NAMES = [
    "jvm_heap_used_mb",
    "jvm_threads_live",
    "http_requests_per_second",
    "http_request_duration_p95",
    "jvm_gc_pause_seconds",
    "cpu_usage_percent",
]


def minute_range() -> List[dt.datetime]:
    start = dt.datetime(2026, 5, 13, 6, 0, tzinfo=dt.timezone.utc)
    end = dt.datetime(2026, 5, 13, 23, 30, tzinfo=dt.timezone.utc)
    current = start
    points = []
    while current <= end:
        points.append(current)
        current += dt.timedelta(minutes=1)
    return points


def reset_output_dirs() -> None:
    for directory in (METRICS_DIR, LOGS_DIR):
        directory.mkdir(parents=True, exist_ok=True)
    if STATE_FILE.exists():
        STATE_FILE.unlink(missing_ok=True)
    for service in SERVICES:
        service_dir = METRICS_DIR / service
        service_dir.mkdir(parents=True, exist_ok=True)
        for path in service_dir.glob("*.prom"):
            path.unlink(missing_ok=True)
    for path in LOGS_DIR.glob("*.log"):
        path.unlink(missing_ok=True)


def normal_load(minute_of_day: int) -> float:
    if minute_of_day < 480:
        return 7
    if minute_of_day < 720:
        return 14
    if minute_of_day < 1020:
        return 22
    if minute_of_day < 1260:
        return 16
    if minute_of_day < 1380:
        return 10
    if minute_of_day <= 1410:
        return 65
    return 5


def service_multiplier(service: str) -> float:
    return {
        "ecommerce": 1.0,
        "product": 0.96,
        "images": 0.92,
        "observability-agent": 0.10,
    }[service]


def build_series() -> Dict[str, List[dict]]:
    rng = random.Random(SEED)
    points = minute_range()
    state = {
        "ecommerce": {"heap": 340.0, "gc_cycle": 0, "threads": 32},
        "product": {"heap": 220.0, "gc_cycle": 0, "threads": 22},
        "images": {"heap": 180.0, "gc_cycle": 0, "threads": 20},
        "observability-agent": {"heap": 140.0, "gc_cycle": 0, "threads": 14},
    }
    max_heap = {
        "ecommerce": 820.0,
        "product": 540.0,
        "images": 420.0,
        "observability-agent": 300.0,
    }
    series = {service: [] for service in SERVICES}

    for timestamp in points:
        minute_of_day = timestamp.hour * 60 + timestamp.minute
        batch_window = 1380 <= minute_of_day <= 1410
        for service in SERVICES:
            base_load = normal_load(minute_of_day) * service_multiplier(service)
            if service == "observability-agent" and batch_window:
                base_load = 12
            jitter = ((minute_of_day + len(service)) % 5) - 2
            request_rate = max(1.0, base_load + jitter)
            if service == "observability-agent":
                request_rate = max(0.5, base_load + 0.2 * jitter)

            thread_base = {
                "ecommerce": 24,
                "product": 18,
                "images": 16,
                "observability-agent": 10,
            }[service]
            thread_boost = 14 if batch_window and service != "observability-agent" else 4 if batch_window else 0
            threads = max(thread_base, int(round(thread_base + request_rate * 1.3 + thread_boost)))

            state[service]["gc_cycle"] += 1
            gc_interval = 85 if service == "ecommerce" else 105 if service == "product" else 115 if service == "images" else 140
            if batch_window and service != "observability-agent":
                gc_interval = max(9, gc_interval // 8)

            full_gc = state[service]["gc_cycle"] >= gc_interval
            gc_pause = 0.0
            if full_gc:
                gc_pause = round(1.4 + (request_rate / 18.0) + (0.3 if service == "ecommerce" else 0.1), 3)
                state[service]["heap"] = max_heap[service] * (0.32 if service == "ecommerce" else 0.36)
                state[service]["gc_cycle"] = 0
            else:
                growth = request_rate * (3.8 if service == "ecommerce" else 2.6 if service == "product" else 2.1 if service == "images" else 1.2)
                state[service]["heap"] = min(max_heap[service] * 0.92, state[service]["heap"] + growth)

            cpu = min(95.0, round(18 + request_rate * (1.4 if service == "ecommerce" else 1.1), 2))
            latency = round(180 + request_rate * (12 if service == "ecommerce" else 8), 2)
            if gc_pause > 0:
                latency += gc_pause * 1100
            if batch_window and service != "observability-agent":
                latency += 550

            series[service].append(
                {
                    "timestamp": timestamp.isoformat().replace("+00:00", "Z"),
                    "jvm_heap_used_mb": round(state[service]["heap"], 2),
                    "jvm_threads_live": threads,
                    "http_requests_per_second": round(request_rate, 2),
                    "http_request_duration_p95": round(latency, 2),
                    "jvm_gc_pause_seconds": gc_pause,
                    "cpu_usage_percent": cpu,
                    "full_gc": full_gc,
                }
            )

    return series


def write_metric_files(series: Dict[str, List[dict]]) -> None:
    for service, points in series.items():
        service_dir = METRICS_DIR / service
        for point in points:
            file_name = point["timestamp"].replace(":", "").replace("-", "")
            path = service_dir / f"{file_name}.prom"
            lines = []
            for metric_name in METRIC_NAMES:
                value = point[metric_name]
                lines.append(f"# TYPE {metric_name} gauge")
                lines.append(f'{metric_name}{{service="{service}"}} {value}')
            path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")

    manifest = {
        "scenarioDate": SCENARIO_DATE.isoformat(),
        "startTimestamp": series["ecommerce"][0]["timestamp"],
        "services": {
            service: [point["timestamp"].replace(":", "").replace("-", "") + ".prom" for point in points]
            for service, points in series.items()
        },
    }
    STATE_FILE.write_text(json.dumps(manifest, indent=2), encoding="utf-8")


def request_id(index: int) -> str:
    return f"req-{index:05d}"


def trace_id(index: int) -> str:
    return f"trace-{index:05d}"


def log_line(timestamp: dt.datetime, level: str, request: str, trace: str, service: str, endpoint: str, duration_ms: int, message: str) -> str:
    return f'{timestamp.strftime("%Y-%m-%dT%H:%M:%SZ")} {level} requestId={request} traceId={trace} service={service} endpoint={endpoint} durationMs={duration_ms} message="{message}"'


def write_log_files(series: Dict[str, List[dict]]) -> None:
    logs = {service: [] for service in SERVICES}
    req_index = 1
    for idx, point in enumerate(series["ecommerce"]):
        timestamp = dt.datetime.strptime(point["timestamp"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc)
        request = request_id(req_index)
        trace = trace_id(req_index)
        req_index += 1

        ecommerce_duration = int(point["http_request_duration_p95"])
        product_duration = max(120, int(ecommerce_duration * 0.34))
        images_duration = max(95, int(ecommerce_duration * 0.28))

        logs["ecommerce"].append(log_line(timestamp, "INFO", request, trace, "ecommerce", "/ecommerce-service/ecommerceProducts", 0, "Request received"))
        logs["product"].append(log_line(timestamp + dt.timedelta(milliseconds=25), "INFO", request, trace, "product", "/product-service/products", product_duration, "Downstream request completed"))
        logs["images"].append(log_line(timestamp + dt.timedelta(milliseconds=45), "INFO", request, trace, "images", "/image-service/images", images_duration, "Downstream request completed"))

        if point["full_gc"]:
            gc_duration = max(5200, ecommerce_duration)
            logs["ecommerce"].append(log_line(timestamp + dt.timedelta(milliseconds=20), "WARN", request, trace, "ecommerce", "/ecommerce-service/ecommerceProducts", gc_duration, "Full GC pause detected"))
            logs["product"].append(log_line(timestamp + dt.timedelta(milliseconds=30), "WARN", request, trace, "product", "/product-service/products", max(5100, product_duration), "Slow request during upstream GC pressure"))
            logs["images"].append(log_line(timestamp + dt.timedelta(milliseconds=35), "WARN", request, trace, "images", "/image-service/images", max(5050, images_duration), "Slow request during upstream GC pressure"))

        logs["ecommerce"].append(log_line(timestamp + dt.timedelta(milliseconds=ecommerce_duration), "INFO" if ecommerce_duration < 5000 else "WARN", request, trace, "ecommerce", "/ecommerce-service/ecommerceProducts", ecommerce_duration, "Request completed"))

        if idx % 12 == 0:
            agent_duration = 70 + (idx % 6) * 15
            logs["observability-agent"].append(
                log_line(timestamp + dt.timedelta(seconds=4), "INFO", request, trace, "observability-agent", "/api/observability/metrics/request-rate/ecommerce", agent_duration, "Observability query completed")
            )

    for service, entries in logs.items():
        (LOGS_DIR / f"{service}.log").write_text("\n".join(entries) + "\n", encoding="utf-8", newline="\n")


class MetricHandler(http.server.BaseHTTPRequestHandler):
    manifest = {}
    start_time = time.time()
    seconds_per_minute = 1.0

    def do_GET(self):
        service = self.path.strip("/").replace(".prom", "")
        if service not in self.manifest["services"]:
            self.send_response(404)
            self.end_headers()
            return

        elapsed = max(0.0, time.time() - self.start_time)
        index = min(int(elapsed / self.seconds_per_minute), len(self.manifest["services"][service]) - 1)
        file_name = self.manifest["services"][service][index]
        content = (METRICS_DIR / service / file_name).read_text(encoding="utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
        self.end_headers()
        self.wfile.write(content.encode("utf-8"))

    def log_message(self, format, *args):
        return


def serve_metrics(port: int, seconds_per_minute: float) -> None:
    manifest = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    MetricHandler.manifest = manifest
    MetricHandler.start_time = time.time()
    MetricHandler.seconds_per_minute = seconds_per_minute
    with socketserver.TCPServer(("", port), MetricHandler) as server:
        server.serve_forever()


def generate() -> None:
    reset_output_dirs()
    series = build_series()
    write_metric_files(series)
    write_log_files(series)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["generate", "serve"])
    parser.add_argument("--port", type=int, default=9105)
    parser.add_argument("--seconds-per-minute", type=float, default=1.0)
    args = parser.parse_args()

    if args.command == "generate":
        generate()
        print(f"Generated metrics in {METRICS_DIR}")
        print(f"Generated logs in {LOGS_DIR}")
        return

    serve_metrics(args.port, args.seconds_per_minute)


if __name__ == "__main__":
    main()
