terraform {
  backend "s3" {
    bucket         = "courm-ecommerce-tf-state-storage"
    key            = "global/route53/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "courm-ecommerce-tf-locks"
    encrypt        = true
  }
}
