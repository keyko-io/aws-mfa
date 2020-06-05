#!/bin/bash


# Sample for getting temp session token from AWS STS
#
# aws --profile youriamuser sts get-session-token --duration 3600 \
# --serial-number arn:aws:iam::012345678901:mfa/user --token-code 012345
#
# Once the temp token is obtained, you'll need to feed the following environment
# variables to the aws-cli:
#
# export AWS_ACCESS_KEY_ID='KEY'
# export AWS_SECRET_ACCESS_KEY='SECRET'
# export AWS_SESSION_TOKEN='TOKEN'


if sed --help >/dev/null 2>&1; then
  aliassed=sed
elif gsed --help >/dev/null 2>&1; then
  aliassed=gsed
fi

AWS_CLI=$(which aws)

if [ $? -ne 0 ]; then
  echo "AWS CLI is not installed; exiting"
  exit 1
else
  echo "Using AWS CLI found at $AWS_CLI"
fi

# 1 or 2 args ok
if [[ $# -ne 1 && $# -ne 2 ]]; then
  echo "Usage: $0 <MFA_TOKEN_CODE> <AWS_CLI_PROFILE>"
  echo "Where:"
  echo "   <MFA_TOKEN_CODE> = Code from virtual MFA device"
  echo "   <AWS_CLI_PROFILE> = aws-cli profile usually in $HOME/.aws/config"
  exit 2
fi

echo "Reading config..."
if [ -r ~/.aws/mfa.cfg ]; then
  source ~/.aws/mfa.cfg
else
  echo "No config found.  Please create your mfa.cfg.  See README.txt for more info."
  exit 2
fi

AWS_CLI_PROFILE=${3:-ologin}
MFA_TOKEN_CODE=$1
ARN_OF_MFA=${!AWS_CLI_PROFILE}
CREDENTIALS_FILE=${CREDENTIALS_FILE:-$HOME/.aws/credentials}

echo "AWS-CLI Profile: $AWS_CLI_PROFILE"
echo "MFA ARN: $ARN_OF_MFA"
echo "MFA Token Code: $MFA_TOKEN_CODE"

echo "Your Temporary Creds:"
aws --profile $AWS_CLI_PROFILE sts get-session-token --duration 129600 \
  --serial-number $ARN_OF_MFA --token-code $MFA_TOKEN_CODE --output text \
  | awk '{printf("export AWS_ACCESS_KEY_ID=\"%s\"\nexport AWS_SECRET_ACCESS_KEY=\"%s\"\nexport AWS_SESSION_TOKEN=\"%s\"\nexport AWS_SECURITY_TOKEN=\"%s\"\n",$2,$4,$5,$5)}' | tee ~/.aws/.token_file

source ~/.aws/.token_file
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN} AWS_SECURITY_TOKEN=${AWS_SECURITY_TOKEN}

# Replace profile credentials for keyko
line=$(grep -rne '\[keyko\]' ${CREDENTIALS_FILE} | cut -f2 -d':')
if [ -z "$line" ]; then
  echo '' >> ${CREDENTIALS_FILE}
  echo '[keyko]' >> ${CREDENTIALS_FILE}
  line=$(grep -rne '\[keyko\]' ${CREDENTIALS_FILE} | cut -f2 -d':')
fi
$aliased -i -e "$(( line + 1 )),$(( line + 4 ))d" ${CREDENTIALS_FILE}
# echo '' >> ${CREDENTIALS_FILE}
$aliased -i "$(( line + 1))i\aws_security_token = $AWS_SECURITY_TOKEN" ${CREDENTIALS_FILE}
$aliased -i "$(( line + 1))i\aws_session_token = $AWS_SESSION_TOKEN" ${CREDENTIALS_FILE}
$aliased -i "$(( line + 1))i\aws_secret_access_key = $AWS_SECRET_ACCESS_KEY" ${CREDENTIALS_FILE}
$aliased -i "$(( line + 1))i\aws_access_key_id = $AWS_ACCESS_KEY_ID" ${CREDENTIALS_FILE}
export AWS_PROFILE='keyko'

