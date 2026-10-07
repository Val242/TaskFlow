resource "aws_key_pair" "Infra-key" {
  key_name   = "infra-key"
  public_key = var.public_key
}