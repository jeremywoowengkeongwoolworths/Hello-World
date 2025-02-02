# Infrastructure

For IaC we are using Terraform with Terragrunt for templating. 
Terraform Cloud is used as state backend.
The deployment is achieved through Azure Pipelines.

For the `yaml` file schema validation we are using [Yamale](https://pypi.org/project/yamale/).

## Code structure

> **NOTES:**
>  We are heavily relying on symlinks for the terraform modules loading since it
>  is not working well on Terraform Cloud outherwise.
>  This does not work so straight forward in Windows so is recommended to use WSL

- `infra/core/` Core Infrastructure configuration for components and shared resources.
  - `COMPONENT_NAME/`: Different components directories (Algolia, CommerceTools, etc)
    - `modules/` : Symbolic link to the `infra/lib/modules` directory.
    - `config` : Configuration for the component.
      - `core` : Core configuration for the component.
      - `tenants` : Tenant configuration overrides for the component.
    - `terragrunt.hcl` : Terragrunt configuration for the component.
    - `*.tf`: Terraform files for the component.
    - `azure_pipeline.yaml`: Azure pipeline for deploying component infrastructure.
    - `metadata.yaml`: Infrastrucutre component configuration file.

- `infra/lib/` Shared reusable terraform modules, pipeline templates, scripts, etc.
  - `modules/`: Shared terraform modules.
  - `pipelines/`: Infrastructure Azure Devops Pipelines templates.
  - `scripts/`: Powershell, bash scripts.
  - `terragrunt/`: Terragrunt configuration templates.

- `src/DOMAIN_NAME/infra` Domain specific configuration for components and specific domain resources.
  - `modules/` : Symbolic link to the `infra/lib/modules` directory.
  - `config` : Configuration for the component.
    - `core` : Core configuration for the component.
    - `tenants` : Tenant configuration overrides for the component.
  - `terragrunt.hcl` : Terragrunt configuration for the component.
  - `*.tf`: Terraform files for the component.
  - `azure_pipeline.yaml`: Azure pipeline for deploying component infrastructure.
  - `metadata.yaml`: Infrastrucutre component configuration file.

## Terraform Cloud

The Terraform cloud workspace is deployed as part of the service 
[Landing Zone](https://woolworthsdigital.atlassian.net/wiki/spaces/CAPE/pages/26657719456/Landing+Zones).

The configuration to use the appropiate Landingzone is based on the pipeline and 
terragrunt configuration files.

Following the current Workspaces availables:

| **Component**         | **DEV**        | **UAT**        | **PT**        | **PROD**        |
| --------------------- | -------------- | -------------- | ------------- | --------------- |
| FDC WNZ Algolia       | az-fna-dev-aae | az-fna-uat-aae | az-fna-pt-aae | az-fna-prod-aae |
| FDC WNZ Browse        | az-fnb-dev-aae | az-fnb-uat-aae | az-fnb-pt-aae | az-fnb-prod-aae |
| FDC WNZ Commercetools | az-fnc-dev-aae | az-fnc-uat-aae | az-fnc-pt-aae | az-fnc-prod-aae |
| FDC WNZ Messaging     | az-fnm-dev-aae | az-fnm-uat-aae | az-fnm-pt-aae | az-fnm-prod-aae |
| FDC WNZ Product       | az-fnp-dev-aae | az-fnp-uat-aae | az-fnp-pt-aae | az-fnp-prod-aae |


### Terraform Cloud notes:
The following is sorted in the terragrunt common configuration but leaving it 
here for the record.

For Terraform Cloud backend to work properly the tag configuration is required 
(`fnc` for WNZ Commercetools in the example):

```hcl
terraform {
  ...
  cloud {
    organization = "WooliesX"
    workspaces {
      tags = ["fnc"]
    }
  }
}
```

Note that we can not pass environment variables to Terraform Cloud unless they
are `TF_VAR_`. As an example in the CT provider we use this approach instead of 
using the environments mentioned in the 
[documentation](https://registry.terraform.io/providers/labd/commercetools/latest/docs#using-the-provider)

```hcl
provider "commercetools" {
  client_id     = var.CTP_CLIENT_ID
  client_secret = var.CTP_CLIENT_SECRET
  project_key   = var.CTP_PROJECT_KEY
  scopes        = var.CTP_SCOPES
  api_url       = "https://api.australia-southeast1.gcp.commercetools.com"
  token_url     = "https://auth.australia-southeast1.gcp.commercetools.com"
}
```


## Terragrunt

We are using Terragrunt as templating to generate the terraform configuration 
dinamically based on a `yaml` file configuration.

- Common locals
- Provider configuration
- Variables for providers
- Main configuration for the component
- Common Variables for the component

Following an example to compile the files `tg_*.tf` that contain the Terraform 
code built with Terragrunt:
```bash
# Go to the infra directory:
cd src/product/infra/

# Set ENV and run terragrunt commands:
export TF_VAR_TLA=fnp
...
terragrunt init -cloud=false
terragrunt plan

# Or:
../../../infra/lib/scripts/local-terragrunt-init-plan.sh 
```

### Infrastructure configuration (`metadata.yaml`)

The `metadata.yaml` holds the multitenat configuration. Each terraform module is
expected to support multitenancy and this file specifies what modules to use, 
on which landing zone to deploy. Modules can be specified at the domain level 
or at the tenant level.

Example:

```yaml
landingzones:
  fnp:
    description: "Product Domain Landing Zone"
    modules:
      - domain
    tenants:
      wnz:
        modules:
          - algolia
          - commercetools
          - service
      wau:
        modules:
          - commercetools
```

The schema validation is based on the file [lib/terragrunt/metadata.schema.yaml](lib/terragrunt/metadata.schema.yaml)


### Modules configuration (`/infra/config`)
The modules configuration is based on yaml files in the `config` directory.

The schema validation is based on the file [lib/modules/input.schema.yaml](lib/modules/input.schema.yaml)


### Yaml validation
Run the validation locally:
``` bash
# Make sure you have Yamale installed:
pip install yamale

# Go to the infra directory:
cd src/product/infra/

# Run the validation:
yamale metadata.yaml -s ../../../infra/lib/terragrunt/metadata.schema.yaml 
yamale config -s modules/input.schema.yaml 

# or:
../../../infra/lib/scripts/local-yaml-validation.sh 
```

## Pipelines

Each component is being deployed as a separated pipeline. Use the following 
naming convention:

```text
fdc-infra-[core|domain]-[component_name]-[TLA]
```

Use this pipeline as example `infrastructure/core/commercetools/azure_pipeline.yaml`:

- Uses this [pipeline template](lib/pipelines/pipeline-terraform.yaml):
  - It currently runs a terraform plan for each environment available if is not the main branch.
  - If runs in the main branch it will run the terraform apply.
- The pipeline definition needs the following values to be adapted to the component:
  - `trigger.paths.include`
  - `parameters.path`
  - `parameters.tla`
- The terraform vars `TLA`, `ENV` and `REGION` get autopopulated on the 
  [stage-terraform.yaml template](lib/pipelines/stage-terraform.yaml) using the parameters.
  - These are useful for parametrzing the Azure resources, check the file `infrastructure/core/commercetools/locals.tf` 
    for an example.
- The provider configuration should be based on tf vars: 
  - These are stored in a pipeline library using the `TF_VAR` prefix.
  - The pipeline library name follows this naming convention:

    ```text
    fdc-[provider_name]-provider-[environment-name]
    ```

  - The variables are loaded based on the list of providers in the parameter 
    `tfProviders` on the [stage-terraform.yaml template](lib/pipelines/stage-terraform.yaml) 

For using the terraform vars, they need to be stored in the `tfvars` directory 
and with the same name as the Terraform Workspace for the 
[ADO template](https://dev.azure.com/wowonline/Platform%20Engineering/_git/vsts-build-templates?path=/terraform/terraform-job.yaml&version=GBmaster&_a=contents) 
to pick it.
