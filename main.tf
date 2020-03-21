provider "aws" {
  region = "us-east-1"
}

variable "bucket_name" {
  description = "The name of the ELB Access logs bucket."
}

variable "elb_account_id" {
  #us-east-1 AWS ELB account id
  default = "127311923021"
  #List: https://docs.aws.amazon.com/elasticloadbalancing/latest/application//load-balancer-access-logs.html \
  description = "A list of AWS ELB account ids can be found on line. Please choose the one for your region."
}

variable "account_id" {
  description = "The AWS Account ID."
}

data "aws_s3_bucket" "s3_bucket" {
  bucket = var.bucket_name
}

locals {
  queue_name = "access-${var.bucket_name}"
  deadletter_queue_name = "access-${var.bucket_name}-deadletter"
}

resource "aws_sqs_queue" "sqs_queue_deadletter" {
  name = local.deadletter_queue_name
  delay_seconds = 300
  max_message_size = 262144
  message_retention_seconds = 345600
  receive_wait_time_seconds = 10
}

resource "aws_sqs_queue" "sqs_queue" {
  name = local.queue_name
  delay_seconds = 300
  max_message_size = 262144
  message_retention_seconds = 345600
  receive_wait_time_seconds = 10
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:*",
      "Resource": "arn:aws:sqs:*:*:${local.queue_name}",
      "Condition": {
        "ArnEquals": { "aws:SourceArn": "arn:aws:s3:::${var.bucket_name}" }
      }
    }
  ]
}
POLICY
  redrive_policy = <<REDRIVE
{
  "deadLetterTargetArn": "${aws_sqs_queue.sqs_queue_deadletter.arn}",
  "maxReceiveCount": 1000
}
REDRIVE
}

resource "aws_s3_bucket_notification" "s3_bucket_notification" {
  bucket = data.aws_s3_bucket.s3_bucket.id
  queue {
    queue_arn = aws_sqs_queue.sqs_queue.arn
    events = ["s3:ObjectCreated:*"]
    filter_suffix = ".log.gz"
  }
}

/*
resource "aws_s3_bucket" "s3_bucket" {
  name = var.bucket_name
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Id": "AccessLogs-Policy",
    "Statement": [
        {
            "Sid": "Root-Write",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${var.elb_account_id}:root"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${var.bucket_name}/AWSLogs/${var.account_id}/*"
        },
        {
            "Sid": "Log-Delivery-Write",
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${var.bucket_name}/AWSLogs/${var.account_id}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        },
        {
            "Sid": "Log-Delivery-AclCheck",
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${var.bucket_name}"
        }
    ]
}
POLICY
}
*/

