output "jenkins-server-ip" {
  value = aws_instance.jenkins_server.public_ip
}
# output "bastion-server-ip" {
#   value = aws_instance.bastion_server.public_ip
# }




