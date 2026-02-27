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
