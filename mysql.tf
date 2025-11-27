# Создание кластера MySQL в Yandex Cloud
resource "yandex_mdb_mysql_cluster" "mysql_cluster" {
  name        = "mysql-cluster"
  environment = "PRESTABLE"
  network_id  = module.vpc-dev.network_id #yandex_vpc_network.vpc.id
  version     = "8.0"
#  security_group_ids  = [ yandex_vpc_security_group.mysql-sg.id ]
#  deletion_protection = each.value.prot 

  # Настройка ресурсов кластера
  resources {
    resource_preset_id = "s2.micro" # "b1.medium" - не создается в сети d
    disk_size          = 20
    disk_type_id       = "network-ssd"
  }
#yandex_vpc_subnet.private1.id


  # Конфигурация хостов в разных зонах для отказоустойчивости
  host {
    zone      = "ru-central1-a"
    subnet_id = module.vpc-dev.subnet4_id
  }

  host {
    zone      = "ru-central1-b"
    subnet_id = module.vpc-dev.subnet5_id
  }

  host {
    zone      = "ru-central1-d"
    subnet_id = module.vpc-dev.subnet6_id
  }

  # Настройка окна для резервного копирования
  backup_window_start {
    hours   = 23
    minutes = 59
  }

  # Настройка окна технического обслуживания
  maintenance_window {
    type  = "WEEKLY"
    day   = "MON"
    hour  = 3
  }

  # Включение защиты от случайного удаления
  deletion_protection = false
}

# Создание базы данных внутри кластера MySQL
resource "yandex_mdb_mysql_database" "db_netology" {
  cluster_id = yandex_mdb_mysql_cluster.mysql_cluster.id
  name       = "netology_db"
}

# Создание пользователя базы данных с определенными правами доступа
resource "yandex_mdb_mysql_user" "db_user" {
  cluster_id = yandex_mdb_mysql_cluster.mysql_cluster.id
  name       = var.db_user_name      # Использование переменной для имени пользователя
  password   = var.db_user_password  # Использование переменной для пароля

  # Настройка прав доступа пользователя
  permission {
    database_name = yandex_mdb_mysql_database.db_netology.name
    roles = "ALL"
  }
 }