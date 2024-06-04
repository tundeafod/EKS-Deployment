output "remote-server-ip" {
  value = aws_instance.cluster-access.public_ip
}