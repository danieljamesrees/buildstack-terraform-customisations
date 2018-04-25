resource "google_compute_global_address" "nexus-address" {
  name = "${var.env_id}-nexus"
}

resource "google_compute_global_forwarding_rule" "nexus-https-forwarding-rule" {
  name       = "${var.env_id}-nexus-https"
  ip_address = "${google_compute_global_address.nexus-address.address}"
  target     = "${google_compute_target_https_proxy.nexus-https-lb-proxy.self_link}"
  port_range = "443"
}

resource "google_compute_target_https_proxy" "nexus-https-lb-proxy" {
  name             = "${var.env_id}-nexus-https-proxy"
  description      = "really a load balancer but listed as an https proxy"
  url_map          = "${google_compute_url_map.nexus-https-lb-url-map.self_link}"
  ssl_certificates = ["${google_compute_ssl_certificate.buildstack-cert.self_link}"]
}

resource "google_compute_url_map" "nexus-https-lb-url-map" {
  name = "${var.env_id}-nexus-https"
  default_service = "${google_compute_backend_service.nexus-router-lb-backend-service.self_link}"
}

resource "google_compute_health_check" "nexus-public-health-check" {
  name = "${var.env_id}-nexus-public"
  http_health_check {
    port         = 8081
    request_path = "/"
  }
}

resource "google_compute_firewall" "nexus-health-check" {
  name       = "${var.env_id}-nexus-health-check"
  depends_on = ["google_compute_network.bbl-network"]
  network    = "${google_compute_network.bbl-network.name}"

  allow {
    protocol = "tcp"
    ports    = ["8081", "80"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["${google_compute_backend_service.nexus-router-lb-backend-service.name}"]
}


resource "google_compute_instance_group" "nexus-router-lb-0" {
  name        = "${var.env_id}-nexus-router-lb-0-europe-west1-b"
  description = "terraform generated instance group that is multi-zone for https loadbalancing"
  zone        = "europe-west1-b"

  named_port {
    name = "http"
    port = "8081"
  }
}

resource "google_compute_instance_group" "nexus-router-lb-1" {
  name        = "${var.env_id}-nexus-router-lb-1-europe-west1-c"
  description = "terraform generated instance group that is multi-zone for https loadbalancing"
  zone        = "europe-west1-c"

  named_port {
    name = "http"
    port = "8081"
  }
}

resource "google_compute_instance_group" "nexus-router-lb-2" {
  name        = "${var.env_id}-nexus-router-lb-2-europe-west1-d"
  description = "terraform generated instance group that is multi-zone for https loadbalancing"
  zone        = "europe-west1-d"

  named_port {
    name = "http"
    port = "8081"
  }
}

resource "google_compute_backend_service" "nexus-router-lb-backend-service" {
  name        = "${var.env_id}-nexus-router-lb"
  port_name   = "http"
  protocol    = "HTTP"
  timeout_sec = 900
  enable_cdn  = false

  backend {
    group = "${google_compute_instance_group.nexus-router-lb-0.self_link}"
  }

  backend {
    group = "${google_compute_instance_group.nexus-router-lb-1.self_link}"
  }

  backend {
    group = "${google_compute_instance_group.nexus-router-lb-2.self_link}"
  }

  health_checks = ["${google_compute_health_check.nexus-public-health-check.self_link}"]
}

resource "google_dns_record_set" "nexus-dns" {
  name       = "nexus.${google_dns_managed_zone.env_dns_zone.dns_name}"
  depends_on = ["google_compute_global_address.nexus-address", "google_dns_managed_zone.env_dns_zone"]
  type       = "A" 
  ttl        = 300 
  managed_zone = "${google_dns_managed_zone.env_dns_zone.name}"
  rrdatas = ["${google_compute_global_address.nexus-address.address}"]
}
