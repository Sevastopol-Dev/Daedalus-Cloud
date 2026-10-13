#!/usr/bin/env bash
set -e

ENDPOINT="http://localhost:4566"
ACCOUNT_ID="000000000000"
ROLE_NAME="swift-payment-gateway-operator"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
LOG_GROUP="/aws/events/daedalus-soc-alerts"
TOPIC_ARN="arn:aws:sns:us-east-1:${ACCOUNT_ID}:local-test-daedalus-soc-high-priority-alerts"
QUEUE_NAME="daedalus-soc-proof-sink"

echo "=========================================================="
echo " PROJECT DAEDALUS V2: AUTOMATED DECEPTION PROOF SUITE"
echo "=========================================================="

# 1. Capture Active IAM Policy Proof
echo -e "\n[+] 1. Fetching Canary Role Inline Policy..."
POLICY_NAME=$(aws --endpoint-url=$ENDPOINT iam list-role-policies --role-name $ROLE_NAME --query "PolicyNames[0]" --output text)
aws --endpoint-url=$ENDPOINT iam get-role-policy --role-name $ROLE_NAME --policy-name $POLICY_NAME > proof_iam_policy.json
echo "    ✔ IAM Policy dumped to proof_iam_policy.json"

# 2. Setup SQS Listener for SNS Alert Verification
echo -e "\n[+] 2. Setting up SQS Proof Sink for SNS..."
QUEUE_URL=$(aws --endpoint-url=$ENDPOINT sqs create-queue --queue-name $QUEUE_NAME --query "QueueUrl" --output text)
QUEUE_ARN=$(aws --endpoint-url=$ENDPOINT sqs get-queue-attributes --queue-url $QUEUE_URL --attribute-names QueueArn --query "Attributes.QueueArn" --output text)

SUB_ARN=$(aws --endpoint-url=$ENDPOINT sns subscribe \
  --topic-arn $TOPIC_ARN \
  --protocol sqs \
  --notification-endpoint $QUEUE_ARN \
  --query "SubscriptionArn" --output text)
echo "    ✔ Subscribed SQS ($QUEUE_ARN) to SNS Topic"

# 3. Trigger Canary Tripwire (Simulated Attacker AssumeRole)
echo -e "\n[+] 3. Triggering Canary Tripwire via sts:AssumeRole..."
SESSION_NAME="AttackerReconProof-$(date +%s)"
ASSUME_RES=$(aws --endpoint-url=$ENDPOINT sts assume-role \
  --role-arn $ROLE_ARN \
  --role-session-name $SESSION_NAME)
  
CALL=$(aws --endpoint-url=$ENDPOINT events put-events --entries '[
  {
    "Source": "aws.sts",
    "DetailType": "AWS API Call via CloudTrail",
    "Detail": "{\"eventName\":\"AssumeRole\",\"requestParameters\":{\"roleArn\":\"arn:aws:iam::000000000000:role/swift-payment-gateway-operator\"},\"userIdentity\":{\"arn\":\"arn:aws:sts::000000000000:assumed-role/swift-payment-gateway-operator/'$SESSION_NAME'\"},\"sourceIPAddress\":\"127.0.0.1\",\"userAgent\":\"aws-cli/2.0\"}",
    "EventBusName": "default"
  }
]')

echo "    ✔ STS AssumeRole executed successfully. Session: $SESSION_NAME"

# Short sleep to allow EventBridge async processing
sleep 2

# 4. Extract CloudWatch Encrypted Log Telemetry
echo -e "\n[+] 4. Querying CloudWatch SOC Alert Sink Log Group..."
aws --endpoint-url=$ENDPOINT logs filter-log-events \
  --log-group-name $LOG_GROUP > proof_cloudwatch_events.json
echo "    ✔ CloudWatch Event logs captured to proof_cloudwatch_events.json"

# 5. Extract Transformed Alert Message from SQS
echo -e "\n[+] 5. Retrieving Transformed SOC Alert from SQS..."
aws --endpoint-url=$ENDPOINT sqs receive-message \
  --queue-url $QUEUE_URL \
  --max-number-of-messages 1 > proof_sns_transformed_alert.json
echo "    ✔ SNS Transformed Alert captured to proof_sns_transformed_alert.json"

# Clean up temporary test queue
aws --endpoint-url=$ENDPOINT sqs delete-queue --queue-url $QUEUE_URL

echo -e "\n=========================================================="
echo " ALL PROOF ARTIFACTS GENERATED SUCCESSFULLY!"
echo " Files Created:"
echo "   - proof_iam_policy.json"
echo "   - proof_cloudwatch_events.json"
echo "   - proof_sns_transformed_alert.json"
echo "=========================================================="
