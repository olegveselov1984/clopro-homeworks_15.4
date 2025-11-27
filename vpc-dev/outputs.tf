output "network_id" {
  value = yandex_vpc_network.develop.id
}

output "subnet1_id" {
    value = yandex_vpc_subnet.public1.id
}

output "subnet2_id" {
    value = yandex_vpc_subnet.public2.id
}

output "subnet3_id" {
    value = yandex_vpc_subnet.public3.id
}

output "subnet4_id" {
    value = yandex_vpc_subnet.private1.id
}

output "subnet5_id" {
    value = yandex_vpc_subnet.private2.id
}

output "subnet6_id" {
    value = yandex_vpc_subnet.private3.id
}



# output "private_id" {
#     value = yandex_vpc_subnet.private.id
# }