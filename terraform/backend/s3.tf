provider "aws" {
  region = var.aws_region
}

variable "bucket_name" {
  description = "gsiegwald-stashcloud-s3-bucket"
  type        = string
}

resource "aws_s3_bucket" "stashcloud" {
  bucket = var.bucket_name
  acl    = "private"

  tags = {
    Name        = "stashcloud-bucket"
    Environment = "dev"
  }

  versioning { enabled = true }

  server_side_encryption_configuration {
    rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
  }

  lifecycle_rule {
    id                                   = "CleanupDeleteMarkers"
    enabled                              = true
    abort_incomplete_multipart_upload_days = 7
    noncurrent_version_expiration { noncurrent_days = 90 }
  }
}

resource "aws_s3_bucket_public_access_block" "stashcloud_block" {
  bucket                  = aws_s3_bucket.stashcloud.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket_arn" {
  value = aws_s3_bucket.stashcloud.arn
}

