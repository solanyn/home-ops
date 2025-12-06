#!/bin/sh
set -e

# Only auto-create for OIDC logins
if [ "$SFTPGO_LOGIND_PROTOCOL" != "OIDC" ]; then
  exit 0
fi

# Check if user exists (id = 0 means user doesn't exist)
USER_ID=$(echo "$SFTPGO_LOGIND_USER" | jq -r '.id // 0')

if [ "$USER_ID" -eq 0 ]; then
  # User doesn't exist, create new user
  USERNAME=$(echo "$SFTPGO_LOGIND_USER" | jq -r '.username')
  
  # Create user with basic permissions
  cat <<EOF
{
  "username": "$USERNAME",
  "status": 1,
  "home_dir": "/data/$USERNAME",
  "permissions": {
    "/": ["*"]
  },
  "filesystem": {
    "provider": 0
  }
}
EOF
fi


