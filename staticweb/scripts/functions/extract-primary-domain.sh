#!/bin/bash
extract_primary_domain() {
    local subdomain="$1"
    echo "$subdomain" | awk -F. '{if (NF>2) {print $(NF-1)"."$NF} else {print $0}}'
}
