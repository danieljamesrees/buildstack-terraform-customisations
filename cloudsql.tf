resource "google_sql_database_instance" "db_instance" {
  region = "${var.region}"
  project = "${var.project_id}"

  settings {
    tier = "db-n1-standard-2"
    disk_autoresize = "true"

    ip_configuration {
      ipv4_enabled = "true"

      authorized_networks = [
        { value = "${module.terraform-gcp-natgateway.nat-gateway-ips["0"]}" }
      ]

    }

    backup_configuration {
      binary_log_enabled = "true"
      enabled = "true"
      start_time = "02:00"
    }

  }
}

resource "google_sql_database_instance" "db_failover" {
  region = "${var.region}"
  project = "${var.project_id}"
  depends_on = ["google_sql_database_instance.db_instance"]

  master_instance_name = "${google_sql_database_instance.db_instance.name}"
  replica_configuration {
    failover_target = "true"
  }

  settings {
    tier = "db-n1-standard-2"
    disk_autoresize = "true"

    ip_configuration {
      ipv4_enabled = "true"

      authorized_networks = [
        { value = "${module.terraform-gcp-natgateway.nat-gateway-ips["0"]}" }
      ]
    }

  }
}

resource "google_sql_database" "gerrit_db" {
  name = "reviewdb"
  instance = "${google_sql_database_instance.db_instance.name}"
  charset = "utf8"
  collation = "utf8_general_ci"
  depends_on = ["google_sql_database_instance.db_instance", "google_sql_database_instance.db_failover"]
}

resource "google_sql_user" "gerrit" {
  name = "gerrit"
  instance = "${google_sql_database_instance.db_instance.name}"
  host = "%"
  password = "${random_string.gerrit_mysql_password.result}"
  depends_on = ["google_sql_database_instance.db_instance", "google_sql_database_instance.db_failover"]
}

resource "random_string" "gerrit_mysql_password" {
  length = 16
  special = false
}

resource "google_sql_database" "sonar_db" {
  name = "sonar_db"
  instance = "${google_sql_database_instance.db_instance.name}"
  charset = "utf8"
  collation = "utf8_general_ci"
  depends_on = ["google_sql_database_instance.db_instance", "google_sql_database_instance.db_failover"]
}

resource "google_sql_user" "sonar" {
  name = "sonar"
  instance = "${google_sql_database_instance.db_instance.name}"
  host = "%"
  password = "${random_string.sonar_mysql_password.result}"
  depends_on = ["google_sql_database_instance.db_instance", "google_sql_database_instance.db_failover"]
}

resource "random_string" "sonar_mysql_password" {
  length = 16
  special = false
}

output "buildstack_db_instance_name" {
  value = "${google_sql_database_instance.db_instance.name}"
}

output "buildstack_db_instance_ip" {
  value = "${google_sql_database_instance.db_instance.ip_address.0.ip_address}"
}

output "gerrit_mysql_password" {
  value = "${random_string.gerrit_mysql_password.result}"
}

output "sonar_mysql_password" {
  value = "${random_string.sonar_mysql_password.result}"
}
