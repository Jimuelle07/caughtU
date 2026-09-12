data "aws_ami" "dlami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Deep Learning OSS Nvidia Driver AMI GPU PyTorch*(Ubuntu 22.04)*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH into the inference instance for debugging; leave null to disable inbound entirely"
  type        = string
  default     = null
}

resource "aws_security_group" "inference" {
  name        = "caughtu-inference"
  description = "No inbound needed for normal operation; SSH only if ssh_allowed_cidr is set"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.ssh_allowed_cidr == null ? [] : [var.ssh_allowed_cidr]
    content {
      description = "SSH for debugging"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "inference" {
  ami                    = data.aws_ami.dlami.id
  instance_type          = "g4dn.xlarge"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.inference.id]
  iam_instance_profile   = aws_iam_instance_profile.inference.name

  # Get this wrong and "stop" silently becomes "terminate" -- the instance
  # (and its EBS-cached model weights) disappear instead of just pausing.
  instance_initiated_shutdown_behavior = "stop"

  user_data = templatefile("${path.module}/../scripts/bootstrap_ec2.sh", {
    bucket_name = aws_s3_bucket.media.bucket
    aws_region  = var.aws_region
  })

  tags = {
    Name = "caughtu-inference"
  }
}

output "instance_id" {
  value = aws_instance.inference.id
}
