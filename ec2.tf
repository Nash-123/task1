provider "aws" {
  region  = "ap-south-1"
  profile = "task11cloud"
}

resource "aws_security_group" "accesstohttp" {
  name        = "allow_http"
  description = "Security groups allocated!!"

  ingress {
    description = "http website access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

ingress {
    description = "ssh server access by any client"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http_ssh"
  }
}



resource "aws_instance" "web1" {
 ami = "ami-0447a12f28fddb066"
 instance_type = "t2.micro"
 key_name = "mykey111222"
 security_groups = [ "allow_http" ]
  
 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/mamab/Downloads/mykey111222.pem")
    host     = aws_instance.web1.public_ip
  } 



provisioner "remote-exec" {
   inline = [
    "sudo yum install httpd php git -y",
    "sudo systemctl restart httpd",
    "sudo systemctl enable httpd"
   
 ]
}




tags = {
    Name = "lwos1"
  }
}


resource "aws_ebs_volume" "ebs2" {
  availability_zone = aws_instance.web1.availability_zone
  size              = 1

  tags = {
    Name = "myfirstpendrive"
  }
}


resource "aws_ebs_snapshot" "ebs2_snapshot" {
  volume_id = "${aws_ebs_volume.ebs2.id}"

  tags = {
    Name = "nishansnap1"
  }
}


resource "aws_volume_attachment" "myebs" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs2.id
  instance_id = aws_instance.web1.id
  force_detach = true
}





resource "null_resource" "localexecfile" {
   provisioner "local-exec" {
      command = "echo ${aws_instance.web1.public_ip} > nishanip.txt"
   }
}




resource "null_resource" "remotevol2" {
depends_on = [
     aws_volume_attachment.myebs,
  ]


 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/mamab/Downloads/mykey111222.pem")
    host     = aws_instance.web1.public_ip
  }


provisioner "remote-exec" {
   inline = [
    "sudo mkfs.ext4 /dev/xvdh",
    "sudo mount /dev/xvdh  /var/www/html",
    "sudo rm -rf /var/www/html/*",
    "sudo git clone https://github.com/Nash-123/task1.git  /var/www/html"
   
  ]
 }
}


resource "aws_s3_bucket" "nishans3" {

    depends_on = [
     null_resource.remotevol2,
  ]

  bucket = "nishanlocalbucket"
  acl    = "public-read"

  tags = {
    Name        = "nishans3"
    Enviorment = "Dev"
  }
  
  versioning{
    enabled = true
   }

object_lock_configuration {
    object_lock_enabled = "Enabled"
  }
}


locals {
    s3_origin_id = "nishanorigin"
}




resource "aws_s3_bucket_object" "nishanobject1" {

   depends_on = [
     aws_s3_bucket.nishans3,
  ]

  bucket = "nishanlocalbucket"
  key    = "PHPtemp.jpg"
  source = "C:/Users/mamab/PHPtemp.jpg"
  acl = "public-read"
  content_type = "image or jpeg"

}
 

resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [
     aws_s3_bucket_object.nishanobject1,
  ]

  origin {
    domain_name = aws_s3_bucket.nishans3.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
}

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "cloud-front creati on process!!"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "nishanlocalbucket.s3.amazonaws.com"
    prefix          = "myprefix"
  }

 /* aliases = ["mysite.example.com", "yoursite.example.com"] */

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}




resource "null_resource" "nulllocal5" {

   depends_on = [
     aws_cloudfront_distribution.s3_distribution,
  ]

   provisioner "local-exec" {
       command = "chrome ${aws_instance.web1.public_ip}"
   }
}

output "OS-IP"{

  depends_on = [
    aws_cloudfront_distribution.s3_distribution_origin,
  ]

  value = aws_instance.web1.public_ip
}


