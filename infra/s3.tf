# S3 has no real directories: incoming/, processed/, crops/, models/ are just
# key prefixes and need no resource of their own — they appear as objects are
# uploaded under them.
resource "aws_s3_bucket" "media" {
  bucket = "caughtu-media-${var.bucket_suffix}"
}

resource "aws_s3_bucket_lifecycle_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    id     = "expire-processed"
    status = "Enabled"
    filter { prefix = "processed/" }
    expiration { days = 90 }
  }

  rule {
    id     = "expire-crops"
    status = "Enabled"
    filter { prefix = "crops/" }
    expiration { days = 90 }
  }
}

# No CI/CD pipeline (see system-design.md): the EC2 instance fetches its own
# code from here at every boot instead of a build artifact store.
resource "aws_s3_object" "inference_code" {
  for_each = fileset("${path.module}/../inference", "*.py")
  bucket   = aws_s3_bucket.media.id
  key      = "code/${each.value}"
  source   = "${path.module}/../inference/${each.value}"
  etag     = filemd5("${path.module}/../inference/${each.value}")
}

resource "aws_s3_object" "inference_requirements" {
  bucket = aws_s3_bucket.media.id
  key    = "code/requirements.txt"
  source = "${path.module}/../inference/requirements.txt"
  etag   = filemd5("${path.module}/../inference/requirements.txt")
}
