#!/bin/bash -e
get_script_file_path(){
    local SERVICE_NAME="$1"
    local RESOURCE_NAME="$2" 
  
    local DIR_PATH="resources/$SERVICE_NAME"
    
    # Create the directory structure if it doesn't exist
    if [ ! -d "$DIR_PATH" ]; then
        mkdir -p "$DIR_PATH"
        echo "Created directory: $DIR_PATH"
    fi
  
    echo "resources/$SERVICE_NAME/$RESOURCE_NAME.sh"
}
