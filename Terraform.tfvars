aws_region                = "us-east-1"
blue_ami                  = "ami-xxxxxxxxxxxxxxxxx" # Replace with your Blue AMI
green_ami                 = "ami-yyyyyyyyyyyyyyyyy" # Replace with your Green AMI
instance_type             = "t2.micro"
hosted_zone_id            = "YOUR_HOSTED_ZONE_ID" # Replace with your Hosted Zone ID
blue_subdomain            = "blue.yourdomain.com"
green_subdomain           = "green.yourdomain.com"
primary_domain            = "app.yourdomain.com"
acm_certificate_arn_blue  = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # Replace with your Blue ALB certificate ARN
acm_certificate_arn_green = "arn:aws:acm:us-east-1:123456789012:certificate/yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" # Replace with your Green ALB certificate ARN

