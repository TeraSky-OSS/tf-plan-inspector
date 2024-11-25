#!/bin/bash

# Define paths to the version files and the Terraform directory
BAD_VERSION="versions/ec2-main-bad.tf"
GOOD_VERSION="versions/ec2-main-good.tf"
TERRAFORM_DIR="terraform"
TARGET_FILE="$TERRAFORM_DIR/ec2-main.tf"
CREDENTIALS_FILE="/Users/$USER/.terraform.d/credentials.tfrc.json"

# Validate input arguments
if [ -z "$1" ]; then
    echo "Please specify a mode: 'init', 'good', or 'bad'."
    exit 1
fi

# Function to update the Terraform credentials
update_credentials() {
    local token="$1"
    if [ -z "$token" ]; then
        echo "A token is required for 'init' mode."
        exit 1
    fi

    echo "Updating or creating Terraform credentials file..."
    mkdir -p "$(dirname "$CREDENTIALS_FILE")"
    if [ -f "$CREDENTIALS_FILE" ]; then
        # Update the existing file
        jq --arg token "$token" '.credentials["app.terraform.io"].token = $token' "$CREDENTIALS_FILE" > "${CREDENTIALS_FILE}.tmp" && mv "${CREDENTIALS_FILE}.tmp" "$CREDENTIALS_FILE"
    else
        # Create the file
        echo "{
  \"credentials\": {
    \"app.terraform.io\": {
      \"token\": \"$token\"
    }
  }
}" > "$CREDENTIALS_FILE"
    fi
    echo "Terraform credentials updated successfully."
}

# Function to initialize Terraform
init_terraform() {
    local token="$1"
    update_credentials "$token"

    echo "Initializing Terraform..."
    cd $TERRAFORM_DIR
    terraform init -input=false
    cd ..
}

# Function to apply a Terraform configuration
apply_configuration() {
    local version="$1"
    if [ "$version" == "bad" ]; then
        echo "Applying the 'bad' version of Terraform configuration..."
        cp $BAD_VERSION $TARGET_FILE
    elif [ "$version" == "good" ]; then
        echo "Applying the 'good' version of Terraform configuration..."
        cp $GOOD_VERSION $TARGET_FILE
    else
        echo "Invalid configuration specified. Use 'good' or 'bad'."
        exit 1
    fi

    cd $TERRAFORM_DIR
    terraform plan
    cd ..
}

# Main script logic
MODE="$1"
TOKEN="$2"

case $MODE in
    init)
        init_terraform "$TOKEN"
        ;;
    good)
        apply_configuration "good"
        ;;
    bad)
        apply_configuration "bad"
        ;;
    *)
        echo "Invalid mode specified. Use 'init', 'good', or 'bad'."
        exit 1
        ;;
esac
