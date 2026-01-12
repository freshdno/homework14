terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "0.177.0"
    }
  }
}

provider "yandex" {
  zone = "ru-central1-a"
}

resource "yandex_compute_disk" "boot-disk-1" {
  name     = "boot-disk-1"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = "20"
  image_id = "fd861t36p9dqjfrqm0g4"
}

resource "yandex_compute_instance" "vm-1" {
  name = "builder"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-1.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "serega:${file("~/.ssh/id_rsa.pub")}"
  }

  connection {
    type        = "ssh"
    user        = "serega"
    private_key = file("~/.ssh/id_rsa")
    host        = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install default-jdk maven git curl -y",
      "sudo mkdir -p /opt/tomcat && sudo curl -O https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.112/bin/apache-tomcat-9.0.112.tar.gz && sudo tar xzvf apache-tomcat-9.0.112.tar.gz -C /opt/tomcat/ --strip-component=1",
      "cd /opt/tomcat/ && sudo sh -c 'chmod +x /opt/tomcat/bin/*.sh' && sudo mkdir -p /opt/tomcat/app && cd /opt/tomcat/app && sudo git clone https://github.com/boxfuse/boxfuse-sample-java-war-hello.git",
      "cd /opt/tomcat/app/boxfuse-sample-java-war-hello && sudo mvn package",
      "sudo cp /opt/tomcat/app/boxfuse-sample-java-war-hello/target/hello-1.0.war /opt/tomcat/webapps",
      "sudo tee /etc/systemd/system/tomcat.service <<EOF\n[Unit]\nDescription=Apache Tomcat\nAfter=network.target\n\n[Service]\nType=forking\nUser=serega\nGroup=serega\nEnvironment=JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64\nEnvironment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid\nEnvironment=CATALINA_HOME=/opt/tomcat\nExecStart=/opt/tomcat/bin/catalina.sh start\nExecStop=/opt/tomcat/bin/catalina.sh stop\nRestart=on-failure\n\n[Install]\nWantedBy=multi-user.target\nEOF",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable tomcat",
      "sudo systemctl start tomcat"
    ]
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}


output "external_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}