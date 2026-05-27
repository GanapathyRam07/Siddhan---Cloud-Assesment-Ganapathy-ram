# ─── CloudWatch Dashboard ────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "ECS CPU Utilization"
          period = 60
          metrics = [
            ["AWS/ECS", "CPUUtilization",
              "ClusterName", var.cluster_name,
              "ServiceName", var.service_name]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title  = "ECS Memory Utilization"
          period = 60
          metrics = [
            ["AWS/ECS", "MemoryUtilization",
              "ClusterName", var.cluster_name,
              "ServiceName", var.service_name]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title  = "ALB Request Count"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount",
              "LoadBalancer", var.alb_arn]
          ]
        }
      }
    ]
  })
}

# ─── CPU High Alarm ───────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project}-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU above 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }
}

# ─── Memory High Alarm ────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.project}-${var.environment}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS Memory above 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }
}

# ─── ALB 5xx Alarm ────────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project}-${var.environment}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB 5xx errors above 10 in 1 minute"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn
  }
}
