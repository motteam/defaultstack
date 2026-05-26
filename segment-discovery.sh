#!/bin/bash
#Author Bogdan Mosneagu Bogdan-Constantin.Mosneagu@kapsch.net January 2026
# List all segments
# Run the script to discover the Domain, TollingPoints, TollingSegments and the names assigned to them
#######Result example###########
##Domain	TollingPoint	TollingSegment	SourceName
##26	    201	          1	              P201TS1
##26	    202	          1	              P202TS1
##26	    110	          1	              P110TS1

set -euo pipefail

API_KEY=""
BASE_URL="https://:8766"
AUTH_URL="$BASE_URL/api/users/authenticate"
STATUS_URL="$BASE_URL/api/status/segments/current"
#STATUS_URL="$BASE_URL/api/notifications/current"
#
OUTPUT_FILE="tolling.csv"

# ---------------- Authentication ----------------
auth_response=$(curl -sk --connect-timeout 5 --max-time 10 \
  -X POST \
  -H "Content-Type: text/plain" \
  -H "Accept: application/json" \
  --data "$API_KEY" \
  "$AUTH_URL")

auth_token=$(echo "$auth_response" | jq -er '.user.token') || {
  echo "UNKNOWN - Authentication failed"
  exit 3
}

# ---------------- Fetch segment status ----------------
status_response=$(curl -sk --connect-timeout 5 --max-time 10 \
  -w "\nHTTP_CODE:%{http_code}" \
  -H "Authorization: Bearer $auth_token" \
  -H "Accept: application/json" \
  "$STATUS_URL")

# ---------------- Extract HTTP code ----------------
http_code=$(echo "$status_response" | sed -n 's/^HTTP_CODE://p')
json_response=$(echo "$status_response" | sed '/^HTTP_CODE:/d')

if [[ "$http_code" != "200" ]]; then
  echo "CRITICAL - HTTP status $http_code"
  exit 2
fi
# ---------------- Export CSV ----------------
{
  echo "Domain,TollingPoint,TollingSegment,SourceName"
  echo "$json_response" | jq -r '
    .segmentStatusList.segmentStatus[]?
    | [
        .sourceId.tollingDomain,
        .sourceId.tollingPoint,
        .sourceId.tollingSegment,
        .sourceName
      ]
    | @csv
  '
} > "$OUTPUT_FILE"

# ---------------- Success ----------------
count=$(echo "$json_response" | jq '.segmentStatusList.segmentStatus | length')

echo "OK - Exported $count segments to $OUTPUT_FILE"
exit 0
