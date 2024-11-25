#!/bin/bash

# Enable global debug mode for the script
set -x

if [ -z "$1" ]; then
  echo "Error: TF_API_TOKEN is required as the first argument."
  echo "Usage: $0 <TF_API_TOKEN>"
  exit 1
fi

# Set your Terraform Cloud details
ORG_NAME="TeraSky"                                # Your Terraform Cloud organization name
WORKSPACE_NAME="ws-kbECHwuPVjDHExcN"              # Your Terraform Cloud workspace name
TF_API_TOKEN="$1"                                 # Your Terraform Cloud API token
BUILD_FOLDER="./"                                 # Define your build folder for storing temp credentials

# URLs for Terraform Cloud API
TF_VAR_URL="https://app.terraform.io/api/v2/workspaces/${WORKSPACE_NAME}/vars"
TF_DELETE_URL="https://app.terraform.io/api/v2/vars"

# Log in to AWS SSO
echo "Logging in to AWS SSO..."
aws sso login --profile default

# Export AWS credentials for the profile
temp_creds=$(aws configure export-credentials --profile default)

if [ $? -ne 0 ]; then
  echo "Failed to export credentials for profile default"
  exit 1
fi

# Write credentials to a temporary file
echo "[default]
aws_access_key_id=$(echo $temp_creds | jq -r .AccessKeyId)
aws_secret_access_key=$(echo $temp_creds | jq -r .SecretAccessKey)
aws_session_token=$(echo $temp_creds | jq -r .SessionToken)
" > "$BUILD_FOLDER/temp_aws_credentials"

echo "Temporary AWS credentials have been written to $BUILD_FOLDER/temp_aws_credentials"

# Extract AWS credentials
AWS_ACCESS_KEY_ID=$(echo $temp_creds | jq -r .AccessKeyId)
AWS_SECRET_ACCESS_KEY=$(echo $temp_creds | jq -r .SecretAccessKey)
AWS_SESSION_TOKEN=$(echo $temp_creds | jq -r .SessionToken)

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
  echo "Failed to retrieve AWS credentials. Please check your AWS SSO login."
  exit 1
fi

# Function to fetch and delete existing Terraform Cloud variables
delete_existing_vars() {
  echo "Fetching existing variables for workspace: $WORKSPACE_NAME"
  var_ids=$(curl --silent \
    --header "Authorization: Bearer $TF_API_TOKEN" \
    $TF_VAR_URL | jq -r '.data[] | .id')

  for var_id in $var_ids; do
    echo "Deleting variable with ID: $var_id"
    curl --silent \
      --header "Authorization: Bearer $TF_API_TOKEN" \
      --header "Content-Type: application/vnd.api+json" \
      --request DELETE \
      "$TF_DELETE_URL/$var_id"
  done
}

# Function to create JSON payload
create_payload() {
  cat <<EOF
{
  "data": {
    "type": "vars",
    "attributes": {
      "key": "$1",
      "value": "$2",
      "category": "env",
      "hcl": false,
      "sensitive": true
    }
  }
}
EOF
}

# Function to create Terraform Cloud variable
create_tf_var() {
  local key=$1
  local value=$2

  payload=$(create_payload "$key" "$value")

  echo "Creating variable: $key"
  curl --silent \
    --header "Authorization: Bearer $TF_API_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request POST \
    --data "$payload" \
    "$TF_VAR_URL"
}

# Delete existing variables
delete_existing_vars

# Create new variables
echo "Creating new AWS credentials variables in Terraform Cloud..."
create_tf_var "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID"
create_tf_var "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY"
create_tf_var "AWS_SESSION_TOKEN" "$AWS_SESSION_TOKEN"

echo "AWS SSO credentials have been successfully updated in Terraform Cloud workspace: $WORKSPACE_NAME"