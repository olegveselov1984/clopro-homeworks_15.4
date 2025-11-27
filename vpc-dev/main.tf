#создаем облачную сеть
resource "yandex_vpc_network" "develop" {
  name = var.env_name_network #"develop"
}

#создаем подсеть
resource "yandex_vpc_subnet" "public1" {
  name           = var.env_name_subnet1 #"develop-ru-central1-a"
  zone           = var.zone1#"ru-central1-a"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = var.cidr1 
}

#создаем подсеть
resource "yandex_vpc_subnet" "public2" {
  name           = var.env_name_subnet2 #"develop-ru-central1-a"
  zone           = var.zone2 #"ru-central1-a"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = var.cidr2
}

#создаем подсеть
resource "yandex_vpc_subnet" "public3" {
  name           = var.env_name_subnet3 #"develop-ru-central1-a"
  zone           = var.zone3 #"ru-central1-a"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = var.cidr3
}

# #создаем подсеть 3
resource "yandex_vpc_subnet" "private1" {
  name           = var.env_name_subnet4 #"develop-ru-central1-a"
  zone           = var.zone4 #"ru-central1-a"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = var.cidr4
#  route_table_id = var.route_table_id
}

# #создаем подсеть 2
resource "yandex_vpc_subnet" "private2" {
  name           = var.env_name_subnet5 #"develop-ru-central1-a"
  zone           = var.zone5 #"ru-central1-a"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = var.cidr5
# route_table_id = var.route_table_id
}

# #создаем подсеть 3
resource "yandex_vpc_subnet" "private3" {
  name           = var.env_name_subnet6 #"develop-ru-central1-a"
  zone           = var.zone6 #"ru-central1-a"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = var.cidr6
#  route_table_id = var.route_table_id
}