# serverless-api-example
Sample code to create a serverless API in AWS with the following goals:
- Enable access through AWS Direct Connect and PrivateLink to AWS Services
- Use resource-based policies where possible to account for potential account restrictions on IAM roles and polices
- Use AWS API Gateway, Lambda, DynamoDB, SQS and Cloudwatch Events to build out a reference architecture to support synchronous and asynchronous job processing

# Prerequisites
## Tools and utilities
Make sure the following are installed and in your path for the best experience:
- Download Hashicorp terraform and ensure it's in your path: https://www.terraform.io/downloads.html
- Optionally install the JSON utility `jq` if not already installed: https://stedolan.github.io/jq/
- Optionally install the AWS CLI tools: https://aws.amazon.com/cli/

## AWS
Some AWS services do not support "Resource-based policies". For those, it is required to have permissions established in a pre-existing role.
- api gateway role
  - create minimal role named for API Gateway (e.g. "serverless-apigw")
    ```
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "apigateway.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
    ```
  - BatchGetItem: attach a policy with the following permission
    ```{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "VisualEditor0",
                "Effect": "Allow",
                "Action": "dynamodb:BatchGetItem",
                "Resource": "arn:aws:dynamodb:<region>:<aws_account_id>:table/mystatus-*"
            }
        ]
    }
    ```
- lambda role
  - create minimal role named for Lambda (e.g. "serverless-lambda")
    ```
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "lambda.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
    ```
  - DynamoDB PutItem: attach a policy with the following permission:
    ```
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "postHostRequest",
          "Effect": "Allow",
          "Action": "dynamodb:PutItem",
          "Resource": "arn:aws:dynamodb:<region>:<aws_account_id>:table/mystatus-*"
        }
      ]
    }
    ```
  - Optionally, add the AWSLambdaBasicExecutionRole managed policy to this role to enable Amazon CloudWatch Logs. 
- VPC Endpoint
  A VPC endpoint should be created and firewalls and security policies should allow access for TCP port 443.

# Demo
## setup variables
Change these values as desired. The bucket name must be unique to the region
regardless of account so put something random in it.
```
export REGION=us-west-2
export BUCKET_NAME=bucket-${REGION}-`openssl rand -hex 4` 
export APP_VERSION=v0.1.0 # update this with the version of your app code
```

## remove existing bucket (if re-using existing bucket)
```
aws s3 rm s3://${BUCKET_NAME} --recursive
aws s3api delete-bucket --bucket=${BUCKET_NAME}
```

## put new code in bucket
```
cd functions/processMessage
zip ../processMessage.zip processMessage.js
cd ..
aws s3api create-bucket --bucket=${BUCKET_NAME} \
--create-bucket-configuration LocationConstraint=${REGION}
aws s3 cp processMessage.zip s3://${BUCKET_NAME}/${APP_VERSION}/processMessage.zip
aws s3 ls ${BUCKET_NAME}
cd ..
```

## Get this code and configure to run
```
git clone git@github.com:ComcastSamples/2019-Serverless-Computing-London-Demo-Code.git
terraform init
# Copy terraform.tfvars.sample to terraform.tfvars and edit with your defaults
cp terraform.tfvars.sample terraform.tfvars 
```

## deploy and test API
```
terraform apply -auto-approve -var="owner=${USER}"
export API_ID=<awsgwApiId>
```

### Test API

#### without Direct Connect
GET status example: 
```
HOSTLIST=`jq -r -c -n '["myhost"+(range(1;10)|tostring)] |join(",")'` \
sh -c '\
curl -G -s \
https://${API_ID}.execute-api.${REGION}.amazonaws.com/dev/host/status \
-d "hosts=$HOSTLIST" \
|jq '
```
POST job request example:
```
curl -s -X POST \
  https://${API_ID}.execute-api.${REGION}.amazonaws.com/dev/host/request \
  -H 'Content-Type: application/json' \
  -d '{"host-list":'"`jq -c -n '[range(1;10)|tostring] | [{fqdn:("myhost" + .[])}]'`"',"harden":true}' |jq
```

#### access an API Gateway endpoint via direct connect VPC
```
export VPC_ENDPOINT=vpce-xxxxxxxxxxxxxxxxx-xxxxxxxx.execute-api.${REGION}.vpce.amazonaws.com
HOSTLIST=`jq -r -c -n '["myhost"+(range(1;10)|tostring)] |join(",")'` \
sh -c '\
curl -G -s \
https://${VPC_ENDPOINT}/dev/host/status \
-d "hosts=$HOSTLIST" \
-H "x-apigw-api-id: ${API_ID}" \
|jq '
```
POST job request example:
```
curl -s -X POST \
  https://${VPC_ENDPOINT}/dev/host/request \
  -H "x-apigw-api-id: ${API_ID}" \
  -H 'Content-Type: application/json' \
  -d '{"host-list":'"`jq -c -n '[range(1;10)|tostring] | [{fqdn:("myhost" + .[])}]'`"',"harden":true}' |jq
```

## change API
### edit your lambda code and push to cloud
```
export APP_VERSION=v0.2.0
aws s3 cp processMessage.zip s3://${BUCKET_NAME}/${APP_VERSION}/processMessage.zip
terraform apply -auto-approve -var="app_version=${APP_VERSION}" 
```

### Test

#### via CLI
```
aws lambda invoke --region=${REGION} \
    --function-name=processMessage-${USER} output.txt \
    && cat output.txt
```

#### via API GW
```
time curl -s https://${API_ID}.execute-api.${REGION}.amazonaws.com/dev
```

## Clean-up
```
terraform destroy -auto-approve -var="owner=${USER}"
```
