provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "stashcloud" {
  bucket = var.bucket_name

  tags = {
    Name        = "stashcloud-bucket"
    Environment = "dev"
  }
}

resource "aws_s3_bucket_versioning" "stashcloud_versioning" {
  bucket = aws_s3_bucket.stashcloud.id

  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "stashcloud_sse" {
  bucket = aws_s3_bucket.stashcloud.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "stashcloud_lifecycle" {
  bucket = aws_s3_bucket.stashcloud.id
  rule {
    id     = "cleanup-delete-markers"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
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

