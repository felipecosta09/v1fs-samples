# V1FS Stack example

This example shows how to use the [V1FS Python SDK](https://github.com/trendmicro/tm-v1-fs-python-sdk) to create a new stack that automatically scan files applied to a different use-cases.

## Requirements

- Have a [Vision One](https://www.trendmicro.com/visionone) account. [Sign up for a free trial now](https://resources.trendmicro.com/vision-one-trial.html) if it's not already the case!
- An [API key](https://docs.trendmicro.com/en-us/documentation/article/trend-vision-one-__api-keys-2) with V1FS **Run file scan via SDK** permissions;
- Terraform CLI [installed](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform)
- AWS CLI [installed](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html).


## Usage

There are different types of scan for different storage types such as S3 and EFS. These examples shows how to create a stack that automatically scan files in these storages. Go to the storage folder to see the examples and choose the desire IaC framework that you like to use.
