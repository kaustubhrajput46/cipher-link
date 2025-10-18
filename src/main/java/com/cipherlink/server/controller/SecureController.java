package com.cipherlink.server.controller;

import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.security.cert.X509Certificate;
import java.util.HashMap;
import java.util.Map;

@RestController
public class SecureController {

    private static final Logger logger = LoggerFactory.getLogger(SecureController.class);

    @GetMapping("/hello")
    public ResponseEntity<String> hello(HttpServletRequest request) {
        logger.info("Endpoint /hello accessed");

        return ResponseEntity.ok(
            "Hello from Cipher-Link secure server\n" +
            "Connection encrypted with TLS\n" +
            "Protocol: " + request.getProtocol()
        );
    }

    @GetMapping("/secure")
    public ResponseEntity<String> secure(HttpServletRequest request) {
        X509Certificate[] certs = (X509Certificate[])
            request.getAttribute("javax.servlet.request.X509Certificate");

        if (certs == null || certs.length == 0) {
            logger.warn("Access denied - no client certificate");
            return ResponseEntity.status(403).body("Access denied");
        }

        X509Certificate clientCert = certs[0];
        String clientDN = clientCert.getSubjectX500Principal().getName();

        logger.info("Secure endpoint accessed by: {}", clientDN);

        return ResponseEntity.ok(
            "Access granted\n" +
            "Client: " + clientDN
        );
    }

    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> info(HttpServletRequest request) {
        Map<String, Object> info = new HashMap<>();
        info.put("server", "Cipher-Link Secure Server");
        info.put("version", "1.0.0");
        info.put("protocol", request.getProtocol());

        X509Certificate[] certs = (X509Certificate[])
            request.getAttribute("javax.servlet.request.X509Certificate");

        if (certs != null && certs.length > 0) {
            X509Certificate clientCert = certs[0];
            Map<String, Object> certInfo = new HashMap<>();
            certInfo.put("subject", clientCert.getSubjectX500Principal().getName());
            certInfo.put("issuer", clientCert.getIssuerX500Principal().getName());
            info.put("clientCertificate", certInfo);
        } else {
            info.put("clientCertificate", "Not provided");
        }

        Map<String, Boolean> features = new HashMap<>();
        features.put("tlsEncryption", true);
        features.put("mTLSSupport", true);
        info.put("securityFeatures", features);

        return ResponseEntity.ok(info);
    }
}
