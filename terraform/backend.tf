terraform {
  backend "s3" {
    bucket         = "terraform-state-eks-blueprint"  # Replace with your S3 bucket name
    key            = "terraform.tfstate"
    region         = "eu-north-1"                    # Match your project region
    encrypt        = true
    dynamodb_table = "terraform-state-lock"         # Replace with your DynamoDB table name
  }
}