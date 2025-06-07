#!/bin/bash -e

echo "check-name_servers.sh"

check_nameservers() {
  # Parameters
  local domain="$1"
  local expected_nameservers="$2"
  
  # Validate parameters
  if [ -z "$domain" ] || [ -z "$expected_nameservers" ]; then
    echo "Usage: check_nameservers <domain> <expected_nameservers>"
    echo "Example: check_nameservers example.com \"ns-1776.awsdns-30.co.uk, ns-143.awsdns-17.com, ns-1423.awsdns-49.org, ns-765.awsdns-31.net\""
    return 1
  fi

  # Convert comma-separated list to array
  IFS=', ' read -r -a expected_array <<< "$expected_nameservers"

  # Get actual nameservers using dig
  echo "Checking nameservers for $domain..."
  actual_nameservers=$(dig NS +short "$domain" | sort)

  # Convert actual nameservers to array
  IFS=$'\n' read -r -a actual_array <<< "$actual_nameservers"

  # Sort the expected nameservers for comparison
  IFS=$'\n' sorted_expected=($(printf "%s\n" "${expected_array[@]}" | sort))

  # Check if arrays have the same length
  if [ ${#actual_array[@]} -ne ${#expected_array[@]} ]; then
    echo "ERROR: Number of nameservers doesn't match."
    echo "Expected ${#expected_array[@]} nameservers, found ${#actual_array[@]}."
    echo "Expected: ${expected_array[*]}"
    echo "Found: ${actual_array[*]}"
    return 1
  fi

  # Check if all expected nameservers are present
  mismatch=0
  for ns in "${sorted_expected[@]}"; do
    if ! echo "$actual_nameservers" | grep -q "$ns"; then
      echo "ERROR: Expected nameserver $ns not found."
      mismatch=1
    fi
  done

  # Final result
  if [ $mismatch -eq 0 ]; then
    echo "SUCCESS: All nameservers match the expected values."
    return 0
  else
    echo "ERROR: Nameserver mismatch detected."
    echo "Expected: ${expected_array[*]}"
    echo "Found: ${actual_array[*]}"
    return 1
  fi
}

