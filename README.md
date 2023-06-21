# AMaaS Stack example

This example shows how to use the [AMaaS Python SDK](https://github.com/trendmicro/cloudone-antimalware-python-sdk/) to create a new stack that automatically scan files uploaded to an S3 bucket.

## Requirements

- Have a [Cloud One](https://www.trendmicro.com/cloudone) account. [Sign up for a free trial now](https://cloudone.trendmicro.com/register) if it's not already the case!
- An [API key](https://cloudone.trendmicro.com/docs/account-and-user-management/c1-api-key/#create-a-new-api-key) with minimum **"Read Only Access"** permission;
- Terraform CLI [installed](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform)
- AWS CLI [installed](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html).


## Usage

There are different types of scan for different storage types such as S3 and EFS. These examples shows how to create a stack that automatically scan files in these storages. Go to the storage folder to see the examples.
