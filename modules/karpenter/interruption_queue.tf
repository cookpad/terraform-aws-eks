resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "Karpenter-${var.cluster_config.name}"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.url
  policy    = data.aws_iam_policy_document.karpenter_interruption_queue_policy.json
}

data "aws_iam_policy_document" "karpenter_interruption_queue_policy" {
  statement {
    sid       = "SqsWrite"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.karpenter_interruption.arn]
    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
        "sqs.amazonaws.com",
      ]
    }
  }
}

locals {
  karpenter_events = {
    health_event = {
      name        = "HealthEvent"
      description = "Karpenter interrupt - AWS health event"
      event_pattern = {
        source      = ["aws.health"]
        detail-type = ["AWS Health Event"]
      }
    }
    spot_interupt = {
      name        = "SpotInterrupt"
      description = "Karpenter interrupt - EC2 spot instance interruption warning"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Spot Instance Interruption Warning"]
      }
    }
    instance_rebalance = {
      name        = "InstanceRebalance"
      description = "Karpenter interrupt - EC2 instance rebalance recommendation"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance Rebalance Recommendation"]
      }
    }
    instance_state_change = {
      name        = "InstanceStateChange"
      description = "Karpenter interrupt - EC2 instance state-change notification"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
      }
    }
  }
}

resource "aws_cloudwatch_event_rule" "karpenter" {
  for_each = local.karpenter_events

  name          = "Karpenter${each.value.name}-${var.cluster_config.name}"
  description   = each.value.description
  event_pattern = jsonencode(each.value.event_pattern)
}

resource "aws_cloudwatch_event_target" "karpenter" {
  for_each  = local.karpenter_events
  rule      = aws_cloudwatch_event_rule.karpenter[each.key].name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}
