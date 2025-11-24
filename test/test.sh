#!/bin/bash
set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# helper: POST JSON and return "HTTP_CODE\nBODY..."
do_request() {
  local url="$1"
  local data="$2"
  local raw
  raw=$(curl -s -H "Content-Type: application/json" -X POST "$url" -d "$data" -w $'\n%{http_code}')
  local http_code body
  http_code="$(printf '%s' "$raw" | tail -n1)"
  body="$(printf '%s' "$raw" | sed '$d')"
  # print code on first line, then body (body can be multi-line)
  printf '%s\n%s' "$http_code" "$body"
}

URL="http://localhost:8080/scitokens-server/oidc-cm"

run_test() {
  local name="$1"
  local data="$2"
  local expected_code="$3"
  local expect_pass="$4"
  echo "Test: $name"
  response="$(do_request "$URL" "$data")"
  http_code="$(printf '%s\n' "$response" | head -n1)"
  body="$(printf '%s\n' "$response" | tail -n +2)"
  if [ "$http_code" -eq "$expected_code" ] && [ "$expect_pass" = "pass" ]; then
    echo -e "${GREEN}PASS${NC}: $name (HTTP $http_code)"
    echo "Response body:"
    echo "$body"
  elif [ "$http_code" -eq "$expected_code" ] && [ "$expect_pass" = "fail" ]; then
    echo -e "${GREEN}PASS${NC}: $name correctly rejected (HTTP $http_code)"
    echo "Response body:"
    echo "$body"
  else
    echo -e "${RED}FAIL${NC}: $name (HTTP $http_code, expected $expected_code)"
    echo "Response body:"
    echo "$body"
    exit 1
  fi
}

# 1. Valid authorization_code flow with allowed redirect_uris
run_test "Valid auth_code, allowed redirect_uris" '{"grant_types":["authorization_code"],"redirect_uris":["https://client.example.com/callback"]}' 200 pass

# 2. authorization_code flow with unallowed redirect_uris
run_test "auth_code, unallowed redirect_uris" '{"grant_types":["authorization_code"],"redirect_uris":["https://evil.com/callback"]}' 400 fail

# 3. authorization_code flow with missing redirect_uris
run_test "auth_code, missing redirect_uris" '{"grant_types":["authorization_code"]}' 400 fail

# 4. device_code flow only, any redirect_uris
run_test "device_code only, allowed redirect_uris" '{"grant_types":["urn:ietf:params:oauth:grant-type:device_code"],"redirect_uris":["https://client.example.com/callback"]}' 200 pass
run_test "device_code only, unallowed redirect_uris" '{"grant_types":["urn:ietf:params:oauth:grant-type:device_code"],"redirect_uris":["https://evil.com/callback"]}' 200 pass
run_test "device_code only, missing redirect_uris" '{"grant_types":["urn:ietf:params:oauth:grant-type:device_code"]}' 200 pass

# 5. both device_code and authorization_code, allowed redirect_uris
run_test "both grant_types, allowed redirect_uris" '{"grant_types":["authorization_code","urn:ietf:params:oauth:grant-type:device_code"],"redirect_uris":["https://client.example.com/callback"]}' 200 pass

# 6. both device_code and authorization_code, unallowed redirect_uris
run_test "both grant_types, unallowed redirect_uris" '{"grant_types":["authorization_code","urn:ietf:params:oauth:grant-type:device_code"],"redirect_uris":["https://evil.com/callback"]}' 400 fail

# 7. unsupported grant_types
run_test "unsupported grant_types" '{"grant_types":["implicit"],"redirect_uris":["https://client.example.com/callback"]}' 400 fail

# 8. malformed JSON
run_test "malformed JSON" '{"grant_types": ["authorization_code", "urn:ietf:params:oauth:grant-type:device_code", "redirect_uris": ["https://client.example.com/callback"]}' 400 fail

# 9. missing grant_types
run_test "missing grant_types" '{"redirect_uris":["https://client.example.com/callback"]}' 400 fail

echo -e "${GREEN}All tests passed.${NC}"
