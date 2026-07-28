# Uncomment and configure for remote state management
# terraform {
#   backend "s3" {
#     bucket         = "flowharbor-terraform-state"
#     key            = "jenkins-demo/terraform.tfstate"
#     region         = "ap-south-1"
#     encrypt        = true
#     dynamodb_table = "flowharbor-terraform-locks"
#   }
# }
