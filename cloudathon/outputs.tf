# Output the instance details
output "instance_details" {
  value = {
    self_link    = data.google_compute_instance.testserver.self_link
    machine_type = data.google_compute_instance.testserver.machine_type
    network_ip   = data.google_compute_instance.testserver.network_interface[0].network_ip
    status       = data.google_compute_instance.testserver.status
  }
  description = "Details of the testserver instance"
}