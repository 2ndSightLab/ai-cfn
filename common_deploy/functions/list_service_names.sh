#!/bin/bash
list_service_names(){
  # Fetch the service list and process it with grep and sed
  echo "Available AWS services:"
  curl https://servicereference.us-east-1.amazonaws.com/v1/service-list.json | grep -v servicereference | grep service | sed 's|"service" : "||g' | sed 's|"||g' | sed 's|,||'
}
