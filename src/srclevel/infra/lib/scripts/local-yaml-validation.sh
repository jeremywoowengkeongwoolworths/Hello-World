echo "Validating config files:"
yamale config -s modules/input.schema.yaml

yamale metadata.yaml -s ../../../infra/lib/terragrunt/metadata.schema.yaml
