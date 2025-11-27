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


# KMS Key for encryption
resource "yandex_kms_symmetric_key" "k8s_encryption_key" {
  name              = "k8s-encryption-key"
  description       = "Encryption key for Kubernetes secrets"
  default_algorithm = "AES_256"
  rotation_period   = "8760h"  # One year
}

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

  # Encryption with KMS Key
  kms_provider {
    key_id = yandex_kms_symmetric_key.k8s_encryption_key.id
  }
}

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