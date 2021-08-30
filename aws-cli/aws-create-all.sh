#! /bin/bash

. ./configs.sh

# clean out results file from any previous runs
echo "Cleaning out aws command response file aws-results.out"
true > aws-results.out


read -p "This will install the AWS resources need for this demo.  Enter y if you are sure n to cancel " -n 2 install
      if [[  "${install}" == 'y' ]]; then

     # This command will create an AWS Secrets instance containing
     # all of the credentials your Lambda will need to communicate
     # with CCloud.
     # Once you've created the secrets instance if you have updated the
     # credentials, run the update-secret.sh script to get the new
     # values into the secret manager
     # This script depends on a JSON file 'aws-cli/aws-ccloud-creds.json'
     # that you create by running ./gradlew propsToJson with your
     # CCloud credentials saved to src/main/resources/confluent.properties (GitHub ignores confluent.properties)


     echo "Create the AWS secrets config to hold connection information"
     aws secretsmanager create-secret --profile "${PROFILE}" --region "${REGION}" \
                   --name "${CREDS_NAME}" \
                   --description "Credentials for connecting to Kafka and SR in CCloud" \
                   --secret-string file://aws-ccloud-creds.json  | tee aws-results.out


      # This commands are used to create an execution role for the
      # Lambda.  It also attaches a policy file to the role
      # with the permissions the Lambda has when running.
      # You only need to run this script once.  After that
      # you can refer to the role by name

      echo "Create the role needed for the lambda"
      aws iam create-role --profile "${PROFILE}" \
        --region "${REGION}" --role-name "${ROLE_NAME}" \
        --assume-role-policy-document file://trust-policy.json | tee -a aws-results.out

      echo "Add policy file inline (inline policy means other roles can't reuse the policy by AWS arn)"
      aws iam put-role-policy --profile "${PROFILE}" --region "${REGION}" \
        --role-name "${ROLE_NAME}" --policy-name "${POLICY_NAME}" \
        --policy-document file://lambda-and-security-manager-policy.json | tee -a aws-results.out

      # These commands will create a Lambda instance with the code from the
      # GitHub repository.  It also establishes a CCloud topic as the
      # event source for the Lambda.  You really only need to run
      # this script once.  If you need to update the Lambda code
      # you'll want to run ./gradlew clean build buildZip
      # then run the update-lambda-code.sh script

      echo "Waiting for 10 seconds for the role and policy to sync"
      sleep 10
      echo "Create the lambda"
      aws lambda  create-function --profile "${PROFILE}" --region "${REGION}" \
        --function-name "${FUNCTION_NAME}" \
        --memory-size 512 \
        --timeout 600 \
        --zip-file fileb://../build/distributions/confluent-lambda-serverless-1.0-SNAPSHOT.zip \
        --handler io.confluent.developer.CCloudStockRecordHandler::handleRequest \
        --runtime java11  --role arn:aws:iam::343223495109:role/"${ROLE_NAME}" | tee -a aws-results.out

      echo "Adding a CCloud topic as an event source "
      aws lambda create-event-source-mapping --profile "${PROFILE}" --region "${REGION}" \
          --topics user_trades \
          --source-access-configuration Type=BASIC_AUTH,URI=arn:aws:secretsmanager:us-west-2:343223495109:secret:"${CREDS_NAME}" \
          --function-name arn:aws:lambda:us-west-2:343223495109:function:"${FUNCTION_NAME}" \
          --self-managed-event-source '{"Endpoints":{"KAFKA_BOOTSTRAP_SERVERS":["'${BOOTSTRAP_SERVERS}'"]}}'  | tee -a aws-results.out

      else
        echo "Skipping install of information quitting now"
      fi