#!/bin/bash

# Authentication functions for ProCare Photo Scraper

# Load or get credentials
load_credentials() {
    # Load .env file if it exists
    local env_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"
    if [ -f "$env_file" ]; then
        source "$env_file"
    fi
    
    # Check environment variables first
    if [ -n "$PROCARE_EMAIL" ] && [ -n "$PROCARE_PASSWORD" ]; then
        log info "Using credentials from environment variables"
        return 0
    fi
    
    # Fail if no credentials found
    log error "PROCARE_EMAIL and PROCARE_PASSWORD environment variables not set"
    log error "Create a .env file or set environment variables"
    exit 1
}

# Authenticate and get bearer token
authenticate() {
    log info "Authenticating..."
    
    local response=$(curl -s -w "\n%{http_code}" "$AUTH_URL" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/plain, */*" \
        -H "Origin: https://schools.procareconnect.com" \
        -H "Referer: https://schools.procareconnect.com/" \
        -d "{\"email\":\"$PROCARE_EMAIL\",\"password\":\"$PROCARE_PASSWORD\",\"role\":\"carer\",\"platform\":\"web\"}")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" != "201" ]; then
        log error "Authentication failed with HTTP code: $http_code"
        log error "Response: $body"
        exit 1
    fi
    
    # Extract the token (assuming it's returned in the response)
    # The token format from your example: online_auth_FZBvf
    TOKEN=$(echo "$body" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$TOKEN" ]; then
        # Try alternative field names
        TOKEN=$(echo "$body" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    fi
    
    if [ -z "$TOKEN" ]; then
        # Try to extract any token-like string
        TOKEN=$(echo "$body" | grep -oE 'online_auth_[A-Za-z0-9]+' | head -n1)
    fi
    
    if [ -z "$TOKEN" ]; then
        log error "Could not extract token from response"
        log error "Response: $body"
        exit 1
    fi
    
    log info "Authentication successful! Token: ${TOKEN:0:20}..."
}
