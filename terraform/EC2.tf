resource "aws_instance" "ec2" {
  ami                    = var.ami
  instance_type          = "t2.large"
  key_name               = var.key-name
  subnet_id              = var.subnet_cidrs[0]
  vpc_security_group_ids = [aws_security_group.security-group.id]
  iam_instance_profile   = aws_iam_instance_profile.instance-profile.name
  availability_zone      = var.azs[0]
  associate_public_ip_address = true

  monitoring = true
  root_block_device {
    volume_size = 30
  }
  user_data = templatefile("./jenkins_server_script.sh", {})

  tags = {
    Name = var.instance-name
  }
}

resource "aws_iam_instance_profile" "instance-profile" {
  name = "Jenkins-instance-profile"
  role = aws_iam_role.iam-role.name
}