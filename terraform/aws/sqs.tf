# The job queue between the API and the worker (introspection jobs, realtime fan-out).

resource "aws_sqs_queue" "jobs_dead_letter" {
  name                              = "${local.name}-jobs-dlq"
  message_retention_seconds         = 1209600 # 14 days, to leave time to investigate
  kms_master_key_id                 = aws_kms_key.data.arn
  kms_data_key_reuse_period_seconds = 300
}

resource "aws_sqs_queue" "jobs" {
  name                              = "${local.name}-jobs"
  visibility_timeout_seconds        = 120
  message_retention_seconds         = 345600 # 4 days
  receive_wait_time_seconds         = 20     # long polling
  kms_master_key_id                 = aws_kms_key.data.arn
  kms_data_key_reuse_period_seconds = 300

  # A job that fails five times moves to the dead-letter queue instead of looping forever.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.jobs_dead_letter.arn
    maxReceiveCount     = 5
  })
}

# Refuse any request that is not encrypted in transit.
data "aws_iam_policy_document" "jobs_queue" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.jobs.arn, aws_sqs_queue.jobs_dead_letter.arn]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "jobs" {
  queue_url = aws_sqs_queue.jobs.id
  policy    = data.aws_iam_policy_document.jobs_queue.json
}
