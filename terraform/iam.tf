resource "aws_iam_role_policy_attachment" "iam-policy" {
  role       = aws_iam_role.iam-role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # Just for testing, don't try to give administrator access
}

resource "aws_iam_role" "iam-role" {
  name               = var.iam-role
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
 ]
}
EOF
}
