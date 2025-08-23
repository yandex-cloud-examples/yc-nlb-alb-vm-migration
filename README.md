# Миграция сервисов с балансировщика NLB с целевыми ресурсами из виртуальных машин на L7-балансировщик ALB с помощью Terraform

Сервисы могут быть развернуты в Yandex Cloud с использованием балансировщика [Yandex Network Load Balancer](https://yandex.cloud/ru/docs/network-load-balancer) (NLB), который распределяет трафик по облачным ресурсам. Трафик, поступающий на сетевой балансировщик, может быть распределен по виртуальным машинам, которые расположены в целевых группах за ним.

Для защиты таких сервисов от DDoS-атак и ботов на уровне приложений (L7) с помощью [Yandex Smart Web Security](https://yandex.cloud/ru/docs/smartwebsecurity) потребуется мигрировать сервис с сетевого балансировщика на L7-балансировщик [Yandex Application Load Balancer](https://yandex.cloud/ru/docs/application-load-balancer) (ALB).

Подготовка инфраструктуры через Terraform описана в [практическом руководстве](https://yandex.cloud/ru/docs/tutorials/security/migration-from-nlb-to-alb/nlb-with-target-resource-vm/terraform). Необходимые для настройки конфигурационные файлы [alb-vm-http.tf](alb-vm-http.tf) и [alb-vm-https.tf](alb-vm-https.tf) расположены в этом репозитории.
