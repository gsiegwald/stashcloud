data "aws_iam_policy_document" "s3_access" {
  statement {
    sid    = "BucketAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.stashcloud.arn,
      "${aws_s3_bucket.stashcloud.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_policy" {
  name        = "stashcloud-s3-policy"
  description = "Least-privilege access for Filestash"
  policy      = data.aws_iam_policy_document.s3_access.json
}

output "s3_policy_arn" {
  value = aws_iam_policy.s3_policy.arn
}
