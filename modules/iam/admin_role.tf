data "aws_caller_identity" "current" {}

resource "aws_iam_role" "admin" {
  name               = var.admin_role_name
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "${data.aws_caller_identity.current.arn}"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
