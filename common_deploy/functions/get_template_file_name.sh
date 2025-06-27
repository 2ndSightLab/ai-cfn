#!/bin/bash -e
get_template_file_path(){
    local RESOURCE_NAME="$1" 
    local SERVICE_NAME="$2"
  
    echo "resources/$SERVICE_NAME/$RESOURCE_NAME.sh"
    
}
