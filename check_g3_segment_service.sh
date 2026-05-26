#!/bin/bash
# Usage:
# ./check_g3_segment.sh -do 58 -tp 3 -ts 1
#Author Bogdan Mosneagu Bogdan-Constantin.Mosneagu@kapsch.net September-October 2025

set -euo pipefail

API_KEY=""   # <-- set your API key
BASE_URL="https://IP:8766"
AUTH_URL="$BASE_URL/api/users/authenticate"
STATUS_URL="$BASE_URL/api/status/segments/current"

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case $1 in
    -do|--tollingDomain) tollingDomain="$2"; shift 2 ;;
    -tp|--tollingPoint)  tollingPoint="$2"; shift 2 ;;
    -ts|--tollingSegment) tollingSegment="$2"; shift 2 ;;
    *) echo "UNKNOWN - Unknown argument: $1"; exit 3 ;;
  esac
done

if [[ -z "${tollingDomain:-}" || -z "${tollingPoint:-}" || -z "${tollingSegment:-}" ]]; then
  echo "UNKNOWN - Missing required arguments"
  echo "Usage: $0 -do <domain> -tp <point> -ts <segment>"
  exit 3
fi

# --- Authenticate ---
auth_response=$(curl -sk -X POST \
  -H "Content-Type: text/plain" \
  -H "Accept: application/json" \
  --data "$API_KEY" \
  "$AUTH_URL")

auth_token=$(echo "$auth_response" | jq -r '.user.token' 2>/dev/null || true)

if [[ -z "$auth_token" || "$auth_token" == "null" ]]; then
  echo "UNKNOWN - Authentication failed"
  exit 3
fi

# --- Get status response (with HTTP code) ---
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

# --- Extract numeric severity/status and sourceName for given sourceId ---
read -r status_code source_name <<<$(echo "$http_body" | jq -r \
  --argjson domain "$tollingDomain" \
  --argjson point "$tollingPoint" \
  --argjson segment "$tollingSegment" \
  '.segmentStatusList.segmentStatus[]
   | select((.sourceId.tollingDomain==$domain)
          and (.sourceId.tollingPoint==$point)
          and (.sourceId.tollingSegment==$segment))
   | "\(.status) \(.sourceName)"' | head -n1)

# --- Handle missing or null ---
if [[ -z "${status_code:-}" || "$status_code" == "null" ]]; then
  echo "UNKNOWN - Service does not exist or not found"
  exit 3
fi

# ---------------- Determine worst severity -----
max_severity=$(echo "$matches" | awk -F':' '{print $1}' | sort -nr | head -1)

case "$max_severity" in
  3)
    echo "CRITICAL - $matches"
    exit 2
    ;;
  2)
    echo "CRITICAL - $matches"
    exit 2
    ;;
  1)
    echo "WARNING - $matches"
    exit 1
    ;;
  *)
    echo "OK - $matches"
    exit 0
    ;;
esac