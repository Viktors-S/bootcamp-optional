terraform {
    //download the required providers
    required_providers{
        aws={
            source = "hashicorp/aws"
            version = "~> 3.5.0"
        }
    }
}

//setup provider region
provider "aws" {
    region = "eu-central-1"
}


//vpc
resource "aws_vpc" "custom_vpc" {
  cidr_block = "192.168.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "TVACustomVPC"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.custom_vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "eu-central-1"
  map_public_ip_on_launch = true
  tags = {
    Name = "TVAPublicSubnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.custom_vpc.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "eu-central-1"
  tags = {
    Name = "TVAPrivateSubnet"
  }
}




