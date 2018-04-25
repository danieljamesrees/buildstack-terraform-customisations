resource "google_compute_global_address" "sonar-address" {
  name = "${var.env_id}-sonar"
}

resource "google_compute_global_forwarding_rule" "sonar-https-forwarding-rule" {
  name       = "${var.env_id}-sonar-https"
  ip_address = "${google_compute_global_address.sonar-address.address}"
  target     = "${google_compute_target_https_proxy.sonar-https-lb-proxy.self_link}"
  port_range = "443"
}

resource "google_compute_target_https_proxy" "sonar-https-lb-proxy" {
  name             = "${var.env_id}-sonar-https-proxy"
  description      = "really a load balancer but listed as an https proxy"
  url_map          = "${google_compute_url_map.sonar-https-lb-url-map.self_link}"
  ssl_certificates = ["${google_compute_ssl_certificate.buildstack-cert.self_link}"]
}

resource "google_compute_url_map" "sonar-https-lb-url-map" {
  name = "${var.env_id}-sonar-https"
  default_service = "${google_compute_backend_service.sonar-router-lb-backend-service.self_link}"
}

resource "google_compute_health_check" "sonar-public-health-check" {
  name = "${var.env_id}-sonar-public"
  http_health_check {
    port         = 9000
    request_path = "/"
  }
}

resource "google_compute_firewall" "sonar-health-check" {
  name       = "${var.env_id}-sonar-health-check"
  depends_on = ["google_compute_network.bbl-network"]
  network    = "${google_compute_network.bbl-network.name}"

  allow {
    protocol = "tcp"
    ports    = ["9000", "80"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["${google_compute_backend_service.sonar-router-lb-backend-service.name}"]
}


resource "google_compute_instance_group" "sonar-router-lb-0" {
  name        = "${var.env_id}-sonar-router-lb-0-europe-west1-b"
  description = "terraform generated instance group that is multi-zone for https loadbalancing"
  zone        = "europe-west1-b"

  named_port {
    name = "http"
    port = "9000"
  }
}

resource "google_compute_instance_group" "sonar-router-lb-1" {
  name        = "${var.env_id}-sonar-router-lb-1-europe-west1-c"
  description = "terraform generated instance group that is multi-zone for https loadbalancing"
  zone        = "europe-west1-c"

  named_port {
    name = "http"
    port = "9000"
  }
}

resource "google_compute_instance_group" "sonar-router-lb-2" {
  name        = "${var.env_id}-sonar-router-lb-2-europe-west1-d"
  description = "terraform generated instance group that is multi-zone for https loadbalancing"
  zone        = "europe-west1-d"

  named_port {
    name = "http"
    port = "9000"
  }
}

resource "google_compute_backend_service" "sonar-router-lb-backend-service" {
  name        = "${var.env_id}-sonar-router-lb"
  port_name   = "http"
  protocol    = "HTTP"
  timeout_sec = 900
  enable_cdn  = false

  backend {
    group = "${google_compute_instance_group.sonar-router-lb-0.self_link}"
  }

  backend {
    group = "${google_compute_instance_group.sonar-router-lb-1.self_link}"
  }

  backend {
    group = "${google_compute_instance_group.sonar-router-lb-2.self_link}"
  }

  health_checks = ["${google_compute_health_check.sonar-public-health-check.self_link}"]
}

resource "google_dns_record_set" "sonar-dns" {
  name       = "sonar.${google_dns_managed_zone.env_dns_zone.dns_name}"
  depends_on = ["google_compute_global_address.sonar-address", "google_dns_managed_zone.env_dns_zone"]
  type       = "A" 
  ttl        = 300 
  managed_zone = "${google_dns_managed_zone.env_dns_zone.name}"
  rrdatas = ["${google_compute_global_address.sonar-address.address}"]
}
