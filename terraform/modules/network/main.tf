resource "google_compute_network" "network" {
  name    = "${var.name}-network"
  project = "${var.project}"
}

resource "google_compute_firewall" "allow-internal" {
  name    = "${var.name}-allow-internal"
  project = "${var.project}"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [
    "${var.cidr}",
  ]
}

resource "google_compute_firewall" "allow-ssh-from-everywhere-to-bastion" {
  name    = "${var.name}-allow-ssh-from-everywhere-to-bastion"
  project = "${var.project}"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["bastion"]
}

resource "google_compute_firewall" "allow-ssh-from-bastion-to-private-network" {
  name               = "${var.name}-allow-ssh-from-bastion-to-private-network"
  project            = "${var.project}"
  network            = "${google_compute_network.network.name}"
  direction          = "EGRESS"
  destination_ranges = "${var.private_subnets}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  #target_tags        = ["private-subnets"]
}

resource "google_compute_firewall" "allow-ssh-to-private-network-from-bastion" {
  name          = "${var.name}-allow-ssh-to-private-network-from-bastion"
  project       = "${var.project}"
  network       = "${google_compute_network.network.name}"
  direction     = "INGRESS"
  #source_ranges = ["${module.bastion.private_ip}"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_tags   = ["bastion"]
}

resource "google_compute_firewall" "allow-http-to-appservers" {
  name          = "${var.name}-allow-http-to-appservers"
  project       = "${var.project}"
  network       = "${google_compute_network.network.name}"
  direction     = "INGRESS"
  #source_ranges = "${var.private_subnets}"

  allow {
    protocol = "tcp"
    ports    = ["80", "1234"]
  }

  source_tags   = ["appserver"]
}

resource "google_compute_firewall" "allow-connection-to-db" {
  name          = "${var.name}-allow-connection-to-db"
  project       = "${var.project}"
  network       = "${google_compute_network.network.name}"
  direction     = "EGRESS"
  destination_ranges = ["${var.db_ip}"]

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }
}

module "public_subnet" {
  source = "./public_subnet"
  project = "${var.project}"
  name    = "${var.name}-public"
  region  = "${var.region}"
  network = "${google_compute_network.network.self_link}"
  cidrs   = "${var.public_subnets}"
}

module "private_subnet" {
  source  = "./private_subnet"
  project = "${var.project}"
  name    = "${var.name}-private"
  region  = "${var.region}"
  network = "${google_compute_network.network.self_link}"
  cidrs   = "${var.private_subnets}"
}

module "bastion" {
  source              = "./bastion"
  project             = "${var.project}"
  name                = "${var.name}-bastion"
  zones               = "${var.zones}"
  public_subnet_names = "${module.public_subnet.subnet_names}"
  image               = "${var.bastion_image}"
  instance_type       = "${var.bastion_instance_type}"
  user                = "${var.user}"
  ssh_key             = "${var.ssh_key}"
}
