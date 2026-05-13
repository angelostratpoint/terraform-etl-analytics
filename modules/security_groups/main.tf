resource "aws_security_group" "glue" {
  name        = "cdcu-${var.environment}-glue-sg"
  description = "Security group for AWS Glue connections and jobs"
  vpc_id      = var.vpc_id

  # Glue requires self-referencing ingress for ETL jobs running in VPC mode
  ingress {
    description = "Glue self-referencing traffic"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Outbound HTTPS to AWS service endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "cdcu-${var.environment}-glue-sg"
  })
}
