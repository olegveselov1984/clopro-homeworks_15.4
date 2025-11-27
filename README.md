# Домашнее задание к занятию «Кластеры. Ресурсы под управлением облачных провайдеров»

### Цели задания 

1. Организация кластера Kubernetes и кластера баз данных MySQL в отказоустойчивой архитектуре.
2. Размещение в private подсетях кластера БД, а в public — кластера Kubernetes.

---
## Задание 1. Yandex Cloud

1. Настроить с помощью Terraform кластер баз данных MySQL.

<img width="1019" height="1109" alt="image" src="https://github.com/user-attachments/assets/ed4dcc6b-8bb2-486c-9898-e3895c0895f6" />


 - Используя настройки VPC из предыдущих домашних заданий, добавить дополнительно подсеть private в разных зонах, чтобы обеспечить отказоустойчивость.

 <img width="1621" height="682" alt="image" src="https://github.com/user-attachments/assets/9fe5a8db-090d-4e27-803f-58b0111a1311" />

 - Разместить ноды кластера MySQL в разных подсетях.

<img width="1729" height="368" alt="image" src="https://github.com/user-attachments/assets/d6228f28-a148-4b80-8809-82e6372f6c29" />


 - Необходимо предусмотреть репликацию с произвольным временем технического обслуживания.
```
  maintenance_window {
    type  = "WEEKLY"
    day   = "MON"
    hour  = 3
  }
```


 - Использовать окружение Prestable, платформу Intel Broadwell с производительностью 50% CPU и размером диска 20 Гб.   
```
  resources {
    resource_preset_id = "s2.micro" # "b1.medium" - не создается в сети d, поэтому другой
    disk_size          = 20
    disk_type_id       = "network-ssd"
  }
```

 - Задать время начала резервного копирования — 23:59.  
```
  backup_window_start {
    hours   = 23
    minutes = 59
  }
```

 - Включить защиту кластера от непреднамеренного удаления.  
```
  deletion_protection = false
}
```


 - Создать БД с именем `netology_db`, логином и паролем.  
```
resource "yandex_mdb_mysql_database" "db_netology" {
  cluster_id = yandex_mdb_mysql_cluster.mysql_cluster.id
  name       = "netology_db"
}

resource "yandex_mdb_mysql_user" "db_user" {
  cluster_id = yandex_mdb_mysql_cluster.mysql_cluster.id
  name       = "netology_user"      
  password   = "password"

  permission {
    database_name = yandex_mdb_mysql_database.db_netology.name
    roles = ["ALL"]
  }
 }
```


2. Настроить с помощью Terraform кластер Kubernetes.

 - Используя настройки VPC из предыдущих домашних заданий, добавить дополнительно две подсети public в разных зонах, чтобы обеспечить отказоустойчивость.

<img width="1635" height="485" alt="image" src="https://github.com/user-attachments/assets/e02bfd95-ce7f-4ba3-8daf-1b232666a6c2" />

 - Создать отдельный сервис-аккаунт с необходимыми правами.  
```
# Service Account for Kubernetes Cluster
resource "yandex_iam_service_account" "k8s_cluster_manager" {
  name        = "k8s-cluster-manager"
  description = "Service account to manage Kubernetes cluster resources"
}

# Assign necessary roles for cluster management and image pulling
resource "yandex_iam_service_account_iam_binding" "k8s_manager_roles" {
  service_account_id = yandex_iam_service_account.k8s_cluster_manager.id
  role               = "k8s.admin"
  members            = [
    "serviceAccount:${yandex_iam_service_account.k8s_cluster_manager.id}"
  ]
}

resource "yandex_iam_service_account_iam_binding" "k8s_manager_pull" {
  service_account_id = yandex_iam_service_account.k8s_cluster_manager.id
  role               = "container-registry.images.puller"
  members            = [
    "serviceAccount:${yandex_iam_service_account.k8s_cluster_manager.id}"
  ]
}

# Assign the 'k8s.clusters.agent' and 'vpc.publicAdmin' roles to the service account
resource "yandex_resourcemanager_folder_iam_binding" "k8s_cluster_admin" {
  folder_id = var.folder_id
  role      = "k8s.clusters.agent"
  members   = [
    "serviceAccount:${yandex_iam_service_account.k8s_cluster_manager.id}"
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "vpc_public_admin" {
  folder_id = var.folder_id
  role      = "vpc.publicAdmin"

  members = [
    "serviceAccount:${yandex_iam_service_account.k8s_cluster_manager.id}"
  ]
}
```

 - Создать региональный мастер Kubernetes с размещением нод в трёх разных подсетях.
```

# Kubernetes Cluster with Regional Master
resource "yandex_kubernetes_cluster" "primary" {
  name                 = "primary-cluster"
  network_id           = module.vpc-dev.network_id
  service_account_id   = yandex_iam_service_account.k8s_cluster_manager.id
  node_service_account_id = yandex_iam_service_account.k8s_cluster_manager.id

  master {
    #version = "1.14"
    public_ip = true

    regional {
      region = "ru-central1"
      location {
        zone      = "${"ru-central1-a"}"
        subnet_id = "${module.vpc-dev.subnet1_id}"
      }
      location {
        zone      = "${"ru-central1-b"}"
        subnet_id = "${module.vpc-dev.subnet2_id}"
      }
      location {
        zone      = "${"ru-central1-d"}"
        subnet_id = "${module.vpc-dev.subnet3_id}"
      }
    }
  }

  # # Encryption with KMS Key
  # kms_provider {
  #   key_id = yandex_kms_symmetric_key.k8s_encryption_key.id
  # }
}
```


 - Добавить возможность шифрования ключом из KMS, созданным в предыдущем домашнем задании.
```
# KMS Key for encryption
resource "yandex_kms_symmetric_key" "k8s_encryption_key" {
  name              = "k8s-encryption-key"
  description       = "Encryption key for Kubernetes secrets"
  default_algorithm = "AES_256"
  rotation_period   = "8760h"  # One year
}
```
```
  # Encryption with KMS Key
  kms_provider {
    key_id = yandex_kms_symmetric_key.k8s_encryption_key.id
  }
```


 - Создать группу узлов, состояющую из трёх машин с автомасштабированием до шести.
```
# Node Group with Autoscaling
resource "yandex_kubernetes_node_group" "primary_nodes" {
  cluster_id = yandex_kubernetes_cluster.primary.id
  name       = "primary-node-group"

  scale_policy {
    auto_scale {
      max     = 6
      min     = 3
      initial = 3
    }
  }

  instance_template {
    platform_id = "standard-v2"
    
    network_interface {
      nat        = true
      subnet_ids = [module.vpc-dev.subnet1_id]
    }

    resources {
      cores  = 2
      memory = 2
    }

    labels = {
      my_label = "my_value"
    }
  }

  allocation_policy {
    location {
      zone      = "${"ru-central1-a"}"
    }
  }
}
```


 - Подключиться к кластеру с помощью `kubectl`.
```
ubuntu@ubuntu:~/src/clopro/15.4/clopro-homeworks_15.4$ yc init
Welcome! This command will take you through the configuration process.
Pick desired action:
 [1] Re-initialize this profile 'default' with new settings 
 [2] Create a new profile
Please enter your numeric choice: 1
Please go to https://oauth.yandex.ru/authorize?response_type=token&client_id=1a6990aa636648e9b2ef855fa7bec2fb in order to obtain OAuth token.
 Please enter OAuth token: y0__xCpl8AEGMHdEyD4xZOME_U1Ep7DQJvdK6Zr9Kcg-mGlTgCS
You have one cloud available: 'cloud-a112-03' (id = b1g8fa5kgacq5ib1h509). It is going to be used by default.
Please choose folder to use:
 [1] default (id = b1gtnnmljkg2pphuqpge)
 [2] Create a new folder
Please enter your numeric choice: 1
Your current folder has been set to 'default' (id = b1gtnnmljkg2pphuqpge).
Do you want to configure a default Compute zone? [Y/n] 
Which zone do you want to use as a profile default?
 [1] ru-central1-a
 [2] ru-central1-b
 [3] ru-central1-d
 [4] Don't set default zone
Please enter your numeric choice: 1
Your profile default Compute zone has been set to 'ru-central1-a'.
```
```
ubuntu@ubuntu:~/src/clopro/15.4/clopro-homeworks_15.4$ yc managed-kubernetes cluster get-credentials  catcq95ikntq1pltnsp7 --external  --force

Context 'yc-primary-cluster' was added as default to kubeconfig '/home/ubuntu/.kube/config'.
Check connection to cluster using 'kubectl cluster-info --kubeconfig /home/ubuntu/.kube/config'.

Note, that authentication depends on 'yc' and its config profile 'default'.
To access clusters using the Kubernetes API, please use Kubernetes Service Account.
```
```
ubuntu@ubuntu:~/src/clopro/15.4/clopro-homeworks_15.4$ kubectl cluster-info --kubeconfig /home/ubuntu/.kube/config
Kubernetes control plane is running at https://158.160.208.203
CoreDNS is running at https://158.160.208.203/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

```
ubuntu@ubuntu:~/src/clopro/15.4/clopro-homeworks_15.4$ kubectl get nodes 
NAME                        STATUS   ROLES    AGE   VERSION
cl1qopb9fjo0v2mheika-amug   Ready    <none>   54s   v1.32.1
cl1qopb9fjo0v2mheika-ibut   Ready    <none>   53s   v1.32.1
cl1qopb9fjo0v2mheika-ylir   Ready    <none>   60s   v1.32.1
```

Кластер создается ОЧЕНЬ долго

<img width="811" height="1378" alt="image" src="https://github.com/user-attachments/assets/6ad7c545-a272-47a0-b214-e5643056c6b3" />


 - *Запустить микросервис phpmyadmin и подключиться к ранее созданной БД.
 - *Создать сервис-типы Load Balancer и подключиться к phpmyadmin. Предоставить скриншот с публичным адресом и подключением к БД.

Полезные документы:

- [MySQL cluster](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/mdb_mysql_cluster).
- [Создание кластера Kubernetes](https://cloud.yandex.ru/docs/managed-kubernetes/operations/kubernetes-cluster/kubernetes-cluster-create)
- [K8S Cluster](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_cluster).
- [K8S node group](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_node_group).

--- 
## Задание 2*. Вариант с AWS (задание со звёздочкой)

Это необязательное задание. Его выполнение не влияет на получение зачёта по домашней работе.

**Что нужно сделать**

1. Настроить с помощью Terraform кластер EKS в три AZ региона, а также RDS на базе MySQL с поддержкой MultiAZ для репликации и создать два readreplica для работы.
 
 - Создать кластер RDS на базе MySQL.
 - Разместить в Private subnet и обеспечить доступ из public сети c помощью security group.
 - Настроить backup в семь дней и MultiAZ для обеспечения отказоустойчивости.
 - Настроить Read prelica в количестве двух штук на два AZ.

2. Создать кластер EKS на базе EC2.

 - С помощью Terraform установить кластер EKS на трёх EC2-инстансах в VPC в public сети.
 - Обеспечить доступ до БД RDS в private сети.
 - С помощью kubectl установить и запустить контейнер с phpmyadmin (образ взять из docker hub) и проверить подключение к БД RDS.
 - Подключить ELB (на выбор) к приложению, предоставить скрин.

Полезные документы:

- [Модуль EKS](https://learn.hashicorp.com/tutorials/terraform/eks).

### Правила приёма работы

Домашняя работа оформляется в своём Git репозитории в файле README.md. Выполненное домашнее задание пришлите ссылкой на .md-файл в вашем репозитории.
Файл README.md должен содержать скриншоты вывода необходимых команд, а также скриншоты результатов.
Репозиторий должен содержать тексты манифестов или ссылки на них в файле README.md.
