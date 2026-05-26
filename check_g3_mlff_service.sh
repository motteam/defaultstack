#!/bin/bash
#Author Bogdan Mosneagu Bogdan-Constantin.Mosneagu@kapsch.net September-October 2025

#Usage
#List of services 
#	OMAD Backup
#	Mlff Tools Log Collection
#	Rss Log Collection
#	RavenDB Tools
#	ETCS Data Interface Service
#	Configuration Service
#	Collect and Evaluate Service
#	REMS
#	AutoPASS
#check_g3_mlff_service.sh -s "service name"


API_KEY=""
BASE_URL="https://IP:8766"
AUTH_URL="$BASE_URL/api/users/authenticate"
STATUS_URL="$BASE_URL/api/status/services/current"

# Default service name
#SERVICE_NAME="OMAD Backup"

usage() {
  echo "Usage: $0 [-s service_name]"
  echo "  -s service_name    Name of the service to check (default: 'OMAD Backup')"
  echo "                    Special shorthand: REMS → 'Csa Norway REMS', AutoPASS → 'Csa Norway AutoPASS'"
  exit 3
}

# Parse options
while getopts ":s:h" opt; do
  case $opt in
    s)
      input_name="$OPTARG"
      if [[ "$input_name" == "REMS" ]]; then
        SERVICE_NAME="Csa Norway REMS"
      elif [[ "$input_name" == "AutoPASS" ]]; then
        SERVICE_NAME="Csa Norway AutoPASS"
      else
        SERVICE_NAME="$input_name"
      fi
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument."
      usage
      ;;
  esac
done

# Authenticate and get token
auth_response=$(curl -sk -X POST \
  -H "Content-Type: text/plain" \
  -H "Accept: application/json" \
  --data "$API_KEY" \
  "$AUTH_URL")

auth_token=$(echo "$auth_response" | jq -r '.user.token')

if [[ -z "$auth_token" || "$auth_token" == "null" ]]; then
  echo "UNKNOWN - Authentication failed"
  exit 3
fi

# Get status response with HTTP code
status_response=$(curl -sk \
  -w "\nHTTP_CODE:%{http_code}" \
  -H "Authorization: Bearer $auth_token" \
  -H "Accept: application/json" \
  "$STATUS_URL")

http_body=$(echo "$status_response" | sed '/^HTTP_CODE:/d')
http_code=$(echo "$status_response" | grep 'HTTP_CODE' | cut -d':' -f2)

if [[ "$http_code" != "200" ]]; then
  echo "UNKNOWN - Failed to fetch status (HTTP $http_code)"
  exit 3
fi

if ! echo "$http_body" | jq empty 2>/dev/null; then
  echo "UNKNOWN - Invalid JSON response"
  exit 3
fi

# Extract service status code dynamically based on $SERVICE_NAME
status_code=$(echo "$http_body" | jq -r --arg svc "$SERVICE_NAME" '
  .serviceStatusList.serviceStatus[]
  | select(.sourceName == $svc)
  | .status
')

if [[ -z "$status_code" || "$status_code" == "null" ]]; then
  echo "UNKNOWN - $SERVICE_NAME status not found"
  exit 3
fi

# Map status to Nagios exit codes and messages
case "$status_code" in
  1)
    echo "OK - $SERVICE_NAME status is OK"
    exit 0
    ;;
  2)
    echo "WARNING - $SERVICE_NAME status is WARNING"
    exit 1
    ;;
  3)
    echo "CRITICAL - $SERVICE_NAME status is ERROR"
    exit 2
    ;;
  *)
    echo "UNKNOWN - $SERVICE_NAME status is unknown ($status_code)"
    exit 3
    ;;
esac