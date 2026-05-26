#!/bin/bash
# Author: Bogdan Mosneagu <Bogdan-Constantin.Mosneagu@kapsch.net>
# G3 RSS Notifications
# September–October 2025

set -euo pipefail

# ---------------- Configuration ----------------
API_KEY="${API_KEY:-}"   # Prefer env var
BASE_URL="https://IP:8766"
AUTH_URL="$BASE_URL/api/users/authenticate"
STATUS_URL="$BASE_URL/api/notifications/current"

##Initialize variables###
device=""
domain=""
tolling_point=""
segment=""
instance=""

# ---------------- Dependencies -----------------
command -v curl >/dev/null || { echo "UNKNOWN - curl not installed"; exit 3; }
command -v jq   >/dev/null || { echo "UNKNOWN - jq not installed"; exit 3; }

# ---------------- Arguments --------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    -do|--tollingDomain)   tollingDomain="$2"; shift 2 ;;
    -tp|--tollingPoint)    tollingPoint="$2"; shift 2 ;;
    -ts|--tollingSegment)  tollingSegment="$2"; shift 2 ;;
    -in|--tollingInstance) tollingInstance="$2"; shift 2 ;;
    -de|--device)          device="$2"; shift 2 ;;
    *) echo "UNKNOWN - Unknown argument: $1"; exit 3 ;;
  esac
done

# ---------------- Validation -------------------
: "${API_KEY:?UNKNOWN - API_KEY not set}"
: "${tollingDomain:?Missing -do/--tollingDomain}"
: "${tollingPoint:?Missing -tp/--tollingPoint}"
: "${tollingSegment:?Missing -ts/--tollingSegment}"
: "${tollingInstance:?Missing -in/--tollingInstance}"
: "${device:?Missing -de/--device}"

for v in tollingDomain tollingPoint tollingSegment tollingInstance; do
  [[ "${!v}" =~ ^[0-9]+$ ]] || { echo "UNKNOWN - $v must be numeric"; exit 3; }
done

# ---------------- Authentication --------------
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
# ---------------- Fetch notifications ---------
status_response=$(curl -sk --connect-timeout 5 --max-time 10 \
  -w "\nHTTP_CODE:%{http_code}" \
  -H "Authorization: Bearer $auth_token" \
  -H "Accept: application/json" \
  "$STATUS_URL")

http_body=$(echo "$status_response" | sed '/^HTTP_CODE:/d')
http_code=$(echo "$status_response" | grep 'HTTP_CODE' | cut -d':' -f2)


[[ "$http_code" == "200" ]] || {
  echo "UNKNOWN - Failed to fetch status (HTTP $http_code)"
  exit 3
}

echo "$http_body" | jq empty 2>/dev/null || {
  echo "UNKNOWN - Invalid JSON payload"
  exit 3
}

# ---------------- Matching notifications ------
matches=$(echo "$http_body" | jq -r \
  --argjson domain "$tollingDomain" \
  --argjson point "$tollingPoint" \
  --argjson segment "$tollingSegment" \
  --argjson instance "$tollingInstance" \
  --arg device "$device" '
  .notificationList.notifications[]
  | select(
      .sourceId.tollingDomain   == $domain and
      .sourceId.tollingPoint    == $point  and
      .sourceId.tollingSegment  == $segment and
      .sourceId.tollingInstance == $instance and
      (.node | ascii_downcase) == ($device | ascii_downcase) and
      .state == 1
    )
  | "\(.severity): \(.name)/\(.notificationType)"'
)

# ---------------- No alarms -------------------
if [[ -z "$matches" ]]; then
  echo "OK - No active alarms detected"
  exit 0
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