provider "google" {
  project     = "${var.project-name}"
  region      = "${var.region}"
}

// Create a new instance
resource "google_compute_instance" "default" {
  // strip underscores from provided name b/c GCE doesn't like them
  name         = "${replace(var.instance-name,"_","")}"
  machine_type = "n1-standard-1"
  zone         = "us-central1-c"

  tags = ["allow-8080", "allow-3000", "allow-k8s-nodeports"]

  boot_disk {
    initialize_params {
      image = "ubuntu-1804-lts"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // An Ephemeral IP will be assigned
    }
  }

  // startup script:
  // 1. install microk8s
  // 2. program instance for self-deletion
  // use heredoc format b/c terraform doesn't support multi-line strings
  metadata = {
    startup-script = <<-SCRIPT
    sudo snap install microk8s --classic 
    microk8s.status --wait-ready --timeout=180
    microk8s.enable dns
    microk8s.status --wait-ready --timeout=180
    echo "gcloud compute instances delete $(hostname) --zone $(curl -H Metadata-Flavor:Google http://metadata.google.internal/computeMetadata/v1/instance/zone -s | cut -d/ -f4) -q" | at Now + ${var.self-destruct-timeout-minutes} Minutes
    SCRIPT
  }

  service_account {
    scopes = [
      // default GCE scopes
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/pubsub",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append",
      // grant permission to compute API so this instance can delete itself
      "https://www.googleapis.com/auth/compute",
      ]
  }

}

output "ip" {
    value = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
}