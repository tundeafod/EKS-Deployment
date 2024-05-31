#!/bin/bash
aws s3api create-bucket --bucket mytodoeksbucket --region eu-west-2 --create-bucket-configuration LocationConstraint=eu-west-2
echo "bucket created"

aws dynamodb create-table --table-name eks-backend --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region eu-west-2
echo "dynamo DB created"