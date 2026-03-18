output "bucket_arn" {
  description = "ARN of the Stashcloud S3 bucket"
  value       = aws_s3_bucket.stashcloud.arn
}

output "s3_policy_arn" {
  description = "ARN of the S3 least-privilege policy"
  value       = aws_iam_policy.s3_policy.arn
}
