data "aws_caller_identity" "current" {}

# TIER 1: Security Group (Deception Ingress)

resource "aws_security_group" "tier1_app_sg" {
  name        = "${var.environment}-daedalus-swift-bridge-sg"
  description = "Tier 1 Ingress: Access control for synthetic SWIFT messaging gateway"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.mandatory_tags, {
    Name = "${var.environment}-swift-iso20022-gateway-sg"
  })
}

# TIER 2: Deception Assets (Canary Role + Honeytoken Secrets)

# 1. Canary IAM Role (SWIFT Payment Operator)
resource "aws_iam_role" "canary_swift_operator" {
  name = "swift-payment-gateway-operator"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      }
    ]
  })

  tags = merge(var.mandatory_tags, {
    Name    = "SWIFT Operator Role"
    Service = "PaymentGateway"
  })
}

resource "aws_iam_role_policy" "canary_stealth_trap" {
  name = "swift-operator-policy"
  role = aws_iam_role.canary_swift_operator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

# 2. Honeytoken Secrets (Core Ledger DB Credentials)
resource "aws_secretsmanager_secret" "honeytoken_db_creds" {
  name                    = "prod/swift/core-ledger-db-credentials"
  recovery_window_in_days = 0

  tags = merge(var.mandatory_tags, {
    Name = "SWIFT Core Ledger Secret"
  })
}

resource "aws_secretsmanager_secret_version" "honeytoken_db_creds_val" {
  secret_id     = aws_secretsmanager_secret.honeytoken_db_creds.id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = "core-ledger-db.prod.internal.bank"
    username = "swift_gw_service"
    password = "Pkt_Live_391028471_SWIFT_Secured"
  })
}

# Tier 3: AUDIT TELEMETRY & KMS ENCRYPTION (PCI-DSS / HIPAA)

resource "aws_kms_key" "daedalus_log_key" {
  description             = "KMS Key for Daedalus Audit Log Encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = var.mandatory_tags
}

resource "aws_cloudwatch_log_group" "soc_alert_sink" {
  name              = "/aws/events/daedalus-soc-alerts"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.daedalus_log_key.arn

  tags = var.mandatory_tags
}

resource "aws_sns_topic" "soc_alerts" {
  name              = "${var.environment}-daedalus-soc-high-priority-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = var.mandatory_tags
}

resource "aws_sns_topic_policy" "allow_eventbridge_publish" {
  arn = aws_sns_topic.soc_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeToPublish"
        Effect = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.soc_alerts.arn
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.canary_tripwire.arn }
        }
      }
    ]
  })
}

# Tier 4: EVENTBRIDGE DETECTION PIPE

resource "aws_cloudwatch_event_rule" "canary_tripwire" {
  name        = "${var.environment}-daedalus-swift-canary-alert"
  description = "Detects authentication attempts on the SWIFT Canary Role"

  event_pattern = jsonencode({
    source      = ["aws.sts"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = ["AssumeRole"]
      requestParameters = {
        roleArn = [aws_iam_role.canary_swift_operator.arn]
      }
    }
  })

  tags = var.mandatory_tags
}

resource "aws_cloudwatch_event_target" "send_to_log_group" {
  rule      = aws_cloudwatch_event_rule.canary_tripwire.name
  target_id = "SendToSOCLogGroup"
  arn       = aws_cloudwatch_log_group.soc_alert_sink.arn
}

resource "aws_cloudwatch_event_target" "send_to_sns" {
  rule      = aws_cloudwatch_event_rule.canary_tripwire.name
  target_id = "SendToSOCSNSTopic"
  arn       = aws_sns_topic.soc_alerts.arn

  input_transformer {
    input_paths = {
      account   = "$.account"
      time      = "$.time"
      region    = "$.region"
      principal = "$.detail.userIdentity.arn"
      source_ip = "$.detail.sourceIPAddress"
      user_agent= "$.detail.userAgent"
    }

    input_template = "\"CRITICAL ALERT: Daedalus Deception Tripwire Triggered! Account: <account> | Region: <region> | Time: <time> | Principal: <principal> | Source IP: <source_ip> | User-Agent: <user_agent>\""
  }

  depends_on = [aws_sns_topic_policy.allow_eventbridge_publish]
}

# OPTIONAL: AWS CloudTrail Infrastructure (Conditional for Production)

resource "aws_s3_bucket" "cloudtrail_bucket" {
  count         = var.enable_cloudtrail ? 1 : 0
  bucket        = "${var.environment}-daedalus-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = var.mandatory_tags
}

resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_bucket[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_bucket[0].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_bucket[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "daedalus_trail" {
  count                         = var.enable_cloudtrail ? 1 : 0
  name                          = "${var.environment}-daedalus-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket[0].id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true

  depends_on = [aws_s3_bucket_policy.cloudtrail_bucket_policy]
}
