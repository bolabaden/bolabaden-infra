# WordPress Services
# This job handles WordPress CMS and MariaDB database

job "wordpress" {
  datacenters = ["dc1"]
  type        = "service"

  # MariaDB database
  group "mariadb" {
    count = 1

    network {
      mode = "bridge"
      port "mariadb" {
        static = 3306
      }
    }

    service {
      name = "mariadb"
      port = "mariadb"

      tags = ["internal", "database"]

      check {
        type     = "script"
        command  = "/usr/bin/mysqladmin"
        args     = ["ping", "-h", "127.0.0.1", "-u", "root", "-p${var.wordpress_db_root_password}"]
        interval = "30s"
        timeout  = "20s"
      }
    }

    task "mariadb" {
      driver = "docker"

      config {
        image = "mariadb:11"
        ports = ["mariadb"]
        volumes = [
          "${var.config_path}/wordpress/mariadb-data:/var/lib/mysql:rw"
        ]
      }

      env {
        MYSQL_ROOT_PASSWORD = var.wordpress_db_root_password
        MYSQL_DATABASE      = var.wordpress_db_name
        MYSQL_USER          = var.wordpress_db_user
        MYSQL_PASSWORD      = var.wordpress_db_password
        TZ                  = var.tz
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }

  # WordPress CMS
  group "wordpress" {
    count = 1

    network {
      mode = "bridge"
      port "wordpress" {
        static = 80
      }
    }

    service {
      name = "wordpress"
      port = "wordpress"

      tags = [
        "traefik.enable=true",
        "traefik.http.middlewares.gzip.compress=true",
        "traefik.http.routers.wordpress.middlewares=gzip",
        "traefik.http.routers.wordpress.rule=Host(`wordpress.${var.domain}`)",
        "traefik.http.services.wordpress.loadbalancer.server.port=80"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "10s"
      }
    }

    task "wordpress" {
      driver = "docker"

      config {
        image = "wordpress:latest"
        ports = ["wordpress"]
        volumes = [
          "${var.config_path}/wordpress/wordpress-files:/var/www/html:rw"
        ]
      }

      env {
        WORDPRESS_DB_HOST     = "mariadb"
        WORDPRESS_DB_USER     = var.wordpress_db_user
        WORDPRESS_DB_PASSWORD = var.wordpress_db_password
        WORDPRESS_DB_NAME     = var.wordpress_db_name
        TZ                    = var.tz
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }
}
