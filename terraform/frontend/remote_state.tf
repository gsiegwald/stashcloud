#data "terraform_remote_state" "backend" {
#  backend = "local"
#  config  = { path = "../backend/terraform.tfstate" }
#}

#locals {
#  bucket_arn = data.terraform_remote_state.backend.outputs.bucket_arn
#}
