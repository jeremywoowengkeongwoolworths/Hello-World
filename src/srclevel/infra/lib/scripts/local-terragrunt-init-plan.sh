set -a && source .env && set +a
terragrunt init -cloud=false
tflint
terragrunt plan
