# Output the instance details
output "instance_details" {
  value = {
    machine_type = data.google_compute_instance.testserver.machine_type
    network_ip   = data.google_compute_instance.testserver.network_interface[0].network_ip
  }
  description = "Details of the testserver instance"
}