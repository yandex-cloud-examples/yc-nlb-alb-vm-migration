# Infrastructure for the Yandex Application Load Balancer
#
# RU: https://yandex.cloud/ru/docs/tutorials/security/migration-from-nlb-to-alb/nlb-with-target-resource-vm/terraform
# EN: https://yandex.cloud/en/docs/tutorials/security/migration-from-nlb-to-alb/nlb-with-target-resource-vm/terraform

# Specify the following settings:
locals {
  # The following settings are to be specified by the user. Change them as you wish.
  domain_name = "" # Domain name of your service
  network_id  = "" # ID of the network where the VMs are located
  certificate = "" # Path to a file with a certificate
  private_key = "" # Path to a file with a private key

  # The following settings are predefined. Change them only if necessary.
  network_name        = "alb-network"        # Network name
  subnet_a_name       = "alb-subnet-a"       # Subnet-a name
  subnet_b_name       = "alb-subnet-b"       # Subnet-b name
  subnet_d_name       = "alb-subnet-d"       # Subnet-d name
  security_group_name = "alb-security-group" # Security group name
  static_address_name = "alb-static-address" # Static address name
  target_group_name   = "alb-target-group"   # Target group name
  backend_group_name  = "alb-backend-group"  # Backend group name
  backend_name        = "alb-backend"        # Backend name
  router_name         = "alb-router"         # HTTP router name
  host_name           = "alb-host"           # Virtual host name
  route_name          = "alb-route"          # Route name
  alb_name            = "alb"                # Application Load Balancer name
  listener_http_name  = "alb-listener-http"  # HTTP protocol listener name
  listener_https_name = "alb-listener-https" # HTTPS protocol listener name
  sws_profile_name    = "sws-profile"        # Security profile name
  cert_name           = "user-certificate"   # User certificate name
}

# Network infrastructure

resource "yandex_vpc_subnet" "alb-subnet-a" {
  description    = "Subnet-a in the ru-central1-a availability zone for Application Load Balancer network"
  name           = local.subnet_a_name
  zone           = "ru-central1-a"
  network_id     = local.network_id
  v4_cidr_blocks = ["10.51.0.0/16"]
}

resource "yandex_vpc_subnet" "alb-subnet-b" {
  description    = "Subnet-b in the ru-central1-b availability zone for Application Load Balancer network"
  name           = local.subnet_b_name
  zone           = "ru-central1-b"
  network_id     = local.network_id
  v4_cidr_blocks = ["10.52.0.0/16"]
}

resource "yandex_vpc_subnet" "alb-subnet-d" {
  description    = "Subnet-d in the ru-central1-d availability zone for Application Load Balancer network"
  name           = local.subnet_d_name
  zone           = "ru-central1-d"
  network_id     = local.network_id
  v4_cidr_blocks = ["10.53.0.0/16"]
}

resource "yandex_vpc_security_group" "alb-security-group" {
  description = "Security group for the Application Load Balancer"
  name        = local.security_group_name
  network_id  = local.network_id

  ingress {
    description    = "Ext-http"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    description    = "Ext-https"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    description       = "Healthchecks"
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks"
    port              = 30080
  }

  egress {
    description    = "Allow all outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_address" "static-address" {
  description = "Static public IP address for the Application Load Balancer"
  name        = "alb-static-address"
  external_ipv4_address {
    zone_id                  = "ru-central1-a"
    ddos_protection_provider = "qrator"
  }
}

# Infrastructure for the Certificate Manager

resource "yandex_cm_certificate" "user-certificate" {
  description = "Custom TLS сertificate"
  name        = local.cert_name

  self_managed {
    certificate = file(local.certificate)
    private_key = file(local.private_key)
  }
}

# Infrastructure for the Smart Web Security

resource "yandex_sws_security_profile" "sws-profile" {
  description    = "Security profile for the Application Load Balancer"
  name           = local.sws_profile_name
  default_action = "ALLOW"

  security_rule {
    description = "Smart protection is enabled in full mode"
    name        = "smart-protection-rule"
    dry_run     = true
    priority    = 999900
    smart_protection {
      mode = "FULL"
    }
  }
}

# Infrastructure for the Application Load Balancer

resource "yandex_alb_target_group" "alb-target-group" {
  description = "Target group for the Application Load Balancer"
  name        = local.target_group_name

  target {
    subnet_id  = "<идентификатор_подсети>"
    ip_address = "<внутренний_IP-адрес_ВМ_1>"
  }
  target {
    subnet_id  = "<идентификатор_подсети>"
    ip_address = "<внутренний_IP-адрес_ВМ_2>"
  }
  target {
    subnet_id  = "<идентификатор_подсети>"
    ip_address = "<внутренний_IP-адрес_ВМ_N>"
  }
}

resource "yandex_alb_backend_group" "alb-backend-group" {
  description = "Backend group for the Application Load Balancer"
  name        = local.backend_group_name

  #  session_affinity {
  #    connection {
  #      source_ip = true
  #    }
  #  }

  http_backend {
    name             = local.backend_name
    target_group_ids = [yandex_alb_target_group.alb-target-group.id]
    port             = 80
    healthcheck {
      timeout             = "1s"
      interval            = "1s"
      healthy_threshold   = 2
      unhealthy_threshold = 3
      healthcheck_port    = 80
      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "alb-router" {
  description = "HTTP router for the Application Load Balancer"
  name        = local.router_name
}

# Virtual host for the HTTP router
resource "yandex_alb_virtual_host" "alb-host" {
  name           = local.host_name
  authority      = [local.domain_name]
  http_router_id = yandex_alb_http_router.alb-router.id

  route {
    name = local.route_name
    http_route {
      http_match {
        path {
          prefix = "/"
        }
      }
      http_route_action {
        backend_group_id = yandex_alb_backend_group.alb-backend-group.id
      }
    }
  }

  route_options {
    security_profile_id = yandex_sws_security_profile.sws-profile.id
  }
}

resource "yandex_alb_load_balancer" "alb" {
  description        = "Application Load Balancer"
  name               = local.alb_name
  network_id         = local.network_id
  security_group_ids = [yandex_vpc_security_group.alb-security-group.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.alb-subnet-a.id
    }
    location {
      zone_id   = "ru-central1-b"
      subnet_id = yandex_vpc_subnet.alb-subnet-b.id
    }
    location {
      zone_id   = "ru-central1-d"
      subnet_id = yandex_vpc_subnet.alb-subnet-d.id
    }
  }

  listener {
    name = local.listener_http_name
    endpoint {
      address {
        external_ipv4_address {
          address = yandex_vpc_address.static-address.external_ipv4_address[0].address
        }
      }
      ports = [80]
    }
    http {
      redirects {
        http_to_https = true
      }
    }
  }

  listener {
    name = local.listener_https_name
    endpoint {
      address {
        external_ipv4_address {
          address = yandex_vpc_address.static-address.external_ipv4_address[0].address
        }
      }
      ports = [443]
    }
    tls {
      default_handler {
        certificate_ids = [yandex_cm_certificate.user-certificate.id]
        http_handler {
          http_router_id = yandex_alb_http_router.alb-router.id
        }
      }
    }
  }
}
