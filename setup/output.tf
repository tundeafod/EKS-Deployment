output "vpc-id" {
  value = aws_vpc.vpc.id
}
output "pubsub01-id" {
  value = aws_subnet.pubsub01.id
}
output "pubsub02-id" {
  value = aws_subnet.pubsub02.id
}
output "prvtsub01" {
  value = aws_subnet.prvtsub01.id
}
output "prvtsub02" {
  value = aws_subnet.prvtsub02.id
}
output "jenkins-server-ip" {
  value = aws_instance.jenkins_server.public_ip
}
output "bastion-server-ip" {
  value = aws_instance.bastion_server.public_ip
}

output "jenkins_dns_name" {
  value = aws_elb.jenkins_lb.dns_name
}

output "jenkins_zone_id" {
  value = aws_elb.jenkins_lb.zone_id
}

output "jenkins_record" {
  value = aws_route53_record.jenkins_record.id
}

output "acm_certificate" {
  value = aws_acm_certificate.acm_certificate.arn
}
