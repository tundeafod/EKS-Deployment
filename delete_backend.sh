#!/bin/bash
aws s3 rb s3://mytodoeksbucket --force
echo "bucket deleted"

aws dynamodb delete-table --table-name eks-backend --region eu-west-2
echo "table deleted"