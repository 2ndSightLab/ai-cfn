#!/bin/bash
create_deploy_code_for_resource(){
    local RESOURCE_NAME=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    local SERVICE_NAME=$(echo "$2" | tr '[:lower:]' '[:upper:]')
    
    is_valid_aws_service "$SERVICE_NAME"
    is_valid_service_resource "$SERVICE_NAME" "$RESOURCE_NAME"
    
    local SCRIPT_FILE_PATH="scripts/$SERVICE_NAME/$RESOURCE_NAME.sh"
    local TEMPLATE_FILE_PATH="cfn/$SERVICE_NAME/$RESOURCE_NAME.yaml"
    
    # Create directory structure if it doesn't exist
    mkdir -p "scripts/$SERVICE_NAME"
    
    # Create the script file with shebang
    echo '#!/bin/bash -e' > "$SCRIPT_FILE_PATH"
    
    # Make the script executable
    chmod +x "$SCRIPT_FILE_PATH"
    
    # Get resource types from CloudFormation
    resource_types=$(aws cloudformation list-types --visibility PUBLIC --type RESOURCE --query 'TypeSummaries[].TypeName' --output text)
    
    # Find matching resource type for the given service and resource
    for resource_type in $resource_types; do
        if [[ "$resource_type" == *"$SERVICE_NAME"* && "$resource_type" == *"$RESOURCE_NAME"* ]]; then
            # Get properties for the resource type
            properties=$(aws cloudformation describe-type --type RESOURCE --type-name "$resource_type" | jq -r '.Schema' | jq -r '.properties | keys[]')
            
            # Add echo and read statements for each property
            for property in $properties; do
                echo "echo \"Please enter value for $property:\"" >> "$SCRIPT_FILE_PATH"
                echo "read ${property}_value" >> "$SCRIPT_FILE_PATH"
            done
            
            # Add section to print all property values at the end
            echo "" >> "$SCRIPT_FILE_PATH"
            echo "echo \"\"" >> "$SCRIPT_FILE_PATH"
            echo "echo \"Summary of entered values:\"" >> "$SCRIPT_FILE_PATH"
            echo "echo \"----------------------\"" >> "$SCRIPT_FILE_PATH"
            
            for property in $properties; do
                echo "echo \"$property: \${${property}_value}\"" >> "$SCRIPT_FILE_PATH"
            done
            
            # Add section to create parameter-overrides for CloudFormation deploy
            echo "" >> "$SCRIPT_FILE_PATH"
            echo "# Build parameter-overrides string for CloudFormation deploy" >> "$SCRIPT_FILE_PATH"
            echo "PARAMETER_OVERRIDES=\"\"" >> "$SCRIPT_FILE_PATH"
            
            # Add conditional logic to only include parameters with values
            for property in $properties; do
                echo "if [[ -n \"\${${property}_value}\" ]]; then" >> "$SCRIPT_FILE_PATH"
                echo "  if [[ -z \"\$PARAMETER_OVERRIDES\" ]]; then" >> "$SCRIPT_FILE_PATH"
                echo "    PARAMETER_OVERRIDES=\"$property=\${${property}_value}\"" >> "$SCRIPT_FILE_PATH"
                echo "  else" >> "$SCRIPT_FILE_PATH"
                echo "    PARAMETER_OVERRIDES=\"\$PARAMETER_OVERRIDES $property=\${${property}_value}\"" >> "$SCRIPT_FILE_PATH"
                echo "  fi" >> "$SCRIPT_FILE_PATH"
                echo "fi" >> "$SCRIPT_FILE_PATH"
            done
            
            # Add CloudFormation deploy command example
            echo "" >> "$SCRIPT_FILE_PATH"
         

