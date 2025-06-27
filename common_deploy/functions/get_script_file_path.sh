#!/bin/bash -e
get_script_file_path(){
    local RESOURCE_NAME="$1" 
    local SERVICE_NAME="$2"
  
    echo "scripts/$SERVICE_NAME/$RESOURCE_NAME.sh"
}
