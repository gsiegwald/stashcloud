resource "aws_iam_role" "filestash_role" {
  name = "stashcloud-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3" {
  role       = aws_iam_role.filestash_role.name
  policy_arn = local.s3_policy_arn
}

resource "aws_iam_instance_profile" "filestash_profile" {
  name = "stashcloud-ec2-profile"
  role = aws_iam_role.filestash_role.name
}

####################################
# Policy CloudWatch Logs
####################################
data "aws_iam_policy_document" "logs_policy_doc" {
  statement {
    sid    = "ContainerWriteLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "logs_policy" {
  name   = "stashcloud-logs-policy"
  policy = data.aws_iam_policy_document.logs_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "attach_logs" {
  role       = aws_iam_role.filestash_role.name
  policy_arn = aws_iam_policy.logs_policy.arn
}
