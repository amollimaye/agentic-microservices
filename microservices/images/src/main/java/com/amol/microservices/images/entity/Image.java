package com.amol.microservices.images.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;

/**
 * @author Amol Limaye
 **/
@Entity
public class Image {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long Id;

    private int productId;

    private String path;

    public Long getId() {
        return Id;
    }

    public void setId(Long id) {
        Id = id;
    }

    public int getProductId() {
        return productId;
    }

    public void setProductId(int productId) {
        this.productId = productId;
    }

    public String getPath() {
        return path;
    }

    public void setPath(String path) {
        this.path = path;
    }
}
