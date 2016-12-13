#!/bin/sh

# require AWS CLI 1.9.2~, jq

DATE=`date '+%Y%m%d%H%M%S'`
ASSET_FILE_URL="http://bit.ly/1TUTabE"
ASSET_OUTPUT_NAME="/tmp/serverless_handson_assets"

# Create S3 Bucket
S3_BUCKET_NAME=${DATE}-serverless-handson-`whoami`aws s3 mb s3://${S3_BUCKET_NAME} --region ap-northeast-1
aws s3 website s3://${S3_BUCKET_NAME} --index-document index.html
S3_BUCKET_POLICY_FILENAME=/tmp/s3_bucket_policy.json
echo '{
        "Version": "2012-10-17",
        "Statement": [
                {
                        "Sid": "PublicReadGetObject",
                        "Effect": "Allow",
                        "Principal": "*",
                        "Action": [
                                "s3:GetObject"
                        ],
                        "Resource": [
                                "arn:aws:s3:::'${S3_BUCKET_NAME}'/*"
                        ]
                }
        ]
}' > $S3_BUCKET_POLICY_FILENAME
aws s3api put-bucket-policy --bucket ${S3_BUCKET_NAME} --policy file://${S3_BUCKET_POLICY_FILENAME}

# Upload contents
wget $ASSET_FILE_URL -O $ASSET_OUTPUT_NAME.zip
rm -rf $ASSET_OUTPUT_NAME
unzip $ASSET_OUTPUT_NAME.zip -d $ASSET_OUTPUT_NAME
aws s3 cp ${ASSET_OUTPUT_NAME}/static_website/ s3://${S3_BUCKET_NAME} --recursive

# Create Cognito Identity Pool
COGNITO_IDPOOL_NAME=${DATE}HandsonPool
COGNITO_CREATE_IDPOOL_RES=`aws cognito-identity create-identity-pool --identity-pool-name  $COGNITO_IDPOOL_NAME --allow-unauthenticated-identities`
COGNITO_IDPOOL_ID=`echo $COGNITO_CREATE_IDPOOL_RES | jq -r ".IdentityPoolId"`
COGNITO_UNAUTH_ROLE_NAME=Cognito_${COGNITO_IDPOOL_NAME}Unauth_Role
COGNITO_UNAUTH_ROLE_ASSUME_POLICY_FILE_PATH=/tmp/cognito_unauth_assume_role_policy.json
echo '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "'$COGNITO_IDPOOL_ID'"
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "unauthenticated"
        }
      }
    }
  ]
}' > $COGNITO_UNAUTH_ROLE_ASSUME_POLICY_FILE_PATH

COGNITO_UNAUTH_ROLE_INLINE_POLICY_FILE_PATH=/tmp/cognito_unauth_inline_role_policy.json
echo '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "mobileanalytics:PutEvents",
        "cognito-sync:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}' > $COGNITO_UNAUTH_ROLE_INLINE_POLICY_FILE_PATH

COGNITO_CREATE_UNAUTH_ROLE_RES=`aws iam create-role --role-name $COGNITO_UNAUTH_ROLE_NAME --assume-role-policy-document file://$COGNITO_UNAUTH_ROLE_ASSUME_POLICY_FILE_PATH`
COGNITO_UNAUTH_ROLE_ARN=`echo $COGNITO_CREATE_UNAUTH_ROLE_RES | jq -r ".Role.Arn"`
aws iam put-role-policy --role-name $COGNITO_UNAUTH_ROLE_NAME --policy-name ${COGNITO_UNAUTH_ROLE_NAME}_policy --policy-document file://$COGNITO_UNAUTH_ROLE_INLINE_POLICY_FILE_PATH
aws cognito-identity set-identity-pool-roles --identity-pool-id $COGNITO_IDPOOL_ID --roles unauthenticated=$COGNITO_UNAUTH_ROLE_ARN

# Create DynamoDB Table
DYNAMODB_TABLE_NAME=${DATE}-serverless-handson
DYNAMODB_CREATE_TABLE_RES=`aws dynamodb create-table --table-name $DYNAMODB_TABLE_NAME --attribute-definitions AttributeName=Track,AttributeType=S AttributeName=Timestamp,AttributeType=N --key-schema AttributeName=Track,KeyType=HASH AttributeName=Timestamp,KeyType=RANGE --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5`


# Create Lambda Function
LAMBDA_DYNAMO_ROLE_NAME=Lambda_ExecuteDynamoDB_Role
LAMBDA_DYNAMO_ROLE_ASSUME_POLICY_FILE=/tmp/lambda_dynamo_assume_policy.json
echo '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}' > $LAMBDA_DYNAMO_ROLE_ASSUME_POLICY_FILE

LAMBDA_DYNAMO_ROLE_INLINE_POLICY_FILE=/tmp/lambda_dynamo_inline_policy.json
echo '{

  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1428341300017",
      "Action": [
        "dynamodb:DeleteItem",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:UpdateItem"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Sid": "",
      "Resource": "*",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow"
    }
  ]

}' > $LAMBDA_DYNAMO_ROLE_INLINE_POLICY_FILE

LAMBDA_CREATE_ROLE_RES=`aws iam create-role --role-name $LAMBDA_DYNAMO_ROLE_NAME --assume-role-policy-document file://$LAMBDA_DYNAMO_ROLE_ASSUME_POLICY_FILE`
LAMBDA_ROLE_ARN=`aws iam get-role --role-name ${LAMBDA_DYNAMO_ROLE_NAME}  | jq -r ".Role.Arn"`
aws iam put-role-policy --role-name $LAMBDA_DYNAMO_ROLE_NAME --policy-name ${LAMBDA_DYNAMO_ROLE_NAME}_policy --policy-document file://$LAMBDA_DYNAMO_ROLE_INLINE_POLICY_FILE

LAMBDA_READ_TIMELINE_JSFILE=lambda_readTimeline.js
cat ${ASSET_OUTPUT_NAME}/lambda_functions/readTimeline.js | sed "s/YYYYMMDD-serverless-handson/${DYNAMODB_TABLE_NAME}/" > $LAMBDA_READ_TIMELINE_JSFILE
zip $LAMBDA_READ_TIMELINE_JSFILE.zip $LAMBDA_READ_TIMELINE_JSFILE
LAMBDA_CREATE_READ_FUNCTION_RES=`aws lambda create-function --function-name ${DATE}handsonReadTimeline --runtime nodejs --handler index.handler --role $LAMBDA_ROLE_ARN --zip-file fileb://$LAMBDA_READ_TIMELINE_JSFILE.zip --publish`
LAMBDA_CREATE_READ_FUNCTION_ARN=`echo $LAMBDA_CREATE_READ_FUNCTION_RES | jq -r ".FunctionArn"`
rm $LAMBDA_READ_TIMELINE_JSFILE $LAMBDA_READ_TIMELINE_JSFILE.zip

LAMBDA_WRITE_TIMELINE_JSFILE=lambda_writeTimeline.js
cat ${ASSET_OUTPUT_NAME}/lambda_functions/writeTimeline.js  | sed "s/YYYYMMDD-serverless-handson/${DYNAMODB_TABLE_NAME}/" > $LAMBDA_WRITE_TIMELINE_JSFILE
zip $LAMBDA_WRITE_TIMELINE_JSFILE.zip $LAMBDA_WRITE_TIMELINE_JSFILE
LAMBDA_CREATE_WRITE_FUNCTION_RES=`aws lambda create-function --function-name ${DATE}handsonWriteTimeline --runtime nodejs --handler index.handler --role $LAMBDA_ROLE_ARN --zip-file fileb://$LAMBDA_WRITE_TIMELINE_JSFILE.zip --publish`
LAMBDA_CREATE_WRITE_FUNCTION_ARN=`echo $LAMBDA_CREATE_WRITE_FUNCTION_RES | jq -r ".FunctionArn"`
rm $LAMBDA_WRITE_TIMELINE_JSFILE $LAMBDA_WRITE_TIMELINE_JSFILE.zip

#
# Let's setup & automate API Gateway, and Configure IAM Roles.
# See http://docs.aws.amazon.com/cli/latest/
#


