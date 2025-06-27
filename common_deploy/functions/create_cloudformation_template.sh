#/bin/bash -e
create_cloudformation_template() {
    local SERVICE_NAME="$1"
    local RESOURCE_NAME="$2"
    local TEMPLATE_FILE_PATH=$(get_template_file_path $SERVICE_NAME $RESOURCE_NAME)

    # Construct the resource type directly
    resource_type="AWS::$SERVICE_NAME::$RESOURCE_NAME"

    # Extract properties from the Schema - try different approaches to handle the Schema format
    schema=$(aws cloudformation describe-type --type RESOURCE --type-name "$resource_type" | jq -r '.Schema')
    properties_info=$(echo "$schema" | jq -r '.properties | to_entries[] | "\(.key):\(.value.type // "String"):\(.value.required // false)"' || echo "$schema" | jq -r 'fromjson | .properties | to_entries[] | "\(.key):\(.value.type // "String"):\(.value.required // false)"')

    # Start the template
    echo "AWSTemplateFormatVersion: '2010-09-09'" > "$TEMPLATE_FILE_PATH"
    echo "Description: CloudFormation template for $SERVICE_NAME $RESOURCE_NAME" >> "$TEMPLATE_FILE_PATH"
    echo "" >> "$TEMPLATE_FILE_PATH"

    # Add Parameters
    echo "Parameters:" >> "$TEMPLATE_FILE_PATH"
    while IFS=: read -r prop_name prop_type is_required; do
        echo "  ${prop_name}:" >> "$TEMPLATE_FILE_PATH"
        case "$prop_type" in
            "integer"|"number") cf_type="Number" ;;
            "boolean") cf_type="String"; echo "    AllowedValues: [true, false]" >> "$TEMPLATE_FILE_PATH" ;;
            "array") cf_type="CommaDelimitedList" ;;
            *) cf_type="String" ;;
        esac
        echo "    Type: ${cf_type}" >> "$TEMPLATE_FILE_PATH"
        if [ "$is_required" = "true" ]; then
            echo "    Description: Required - Enter value for ${prop_name}" >> "$TEMPLATE_FILE_PATH"
        else
            echo "    Description: Optional - Enter value for ${prop_name}" >> "$TEMPLATE_FILE_PATH"
            echo "    Default: ''" >> "$TEMPLATE_FILE_PATH"
        fi
    done <<< "$properties_info"
    echo "" >> "$TEMPLATE_FILE_PATH"

    # Add Conditions
    echo "Conditions:" >> "$TEMPLATE_FILE_PATH"
    while IFS=: read -r prop_name prop_type is_required; do
        echo "  ${prop_name}Condition: !Not [!Equals [!Ref ${prop_name}, '']]" >> "$TEMPLATE_FILE_PATH"
    done <<< "$properties_info"
    echo "" >> "$TEMPLATE_FILE_PATH"

    # Add Resources
    echo "Resources:" >> "$TEMPLATE_FILE_PATH"
    echo "  ${RESOURCE_NAME}:" >> "$TEMPLATE_FILE_PATH"
    echo "    Type: ${resource_type}" >> "$TEMPLATE_FILE_PATH"
    echo "    Properties:" >> "$TEMPLATE_FILE_PATH"
    while IFS=: read -r prop_name prop_type is_required; do
        echo "      ${prop_name}:" >> "$TEMPLATE_FILE_PATH"
        echo "        Fn::If:" >> "$TEMPLATE_FILE_PATH"
        echo "          - ${prop_name}Condition" >> "$TEMPLATE_FILE_PATH"
        echo "          - !Ref ${prop_name}" >> "$TEMPLATE_FILE_PATH"
        echo "          - !Ref AWS::NoValue" >> "$TEMPLATE_FILE_PATH"
    done <<< "$properties_info"
    echo "" >> "$TEMPLATE_FILE_PATH"

    # Add Outputs
    echo "Outputs:" >> "$TEMPLATE_FILE_PATH"
    echo "  ${RESOURCE_NAME}Id:" >> "$TEMPLATE_FILE_PATH"
    echo "    Description: The ID of the ${SERVICE_NAME} ${RESOURCE_NAME}" >> "$TEMPLATE_FILE_PATH"
    echo "    Value: !Ref ${RESOURCE_NAME}" >> "$TEMPLATE_FILE_PATH"

    echo "CloudFormation template created and saved to $TEMPLATE_FILE_PATH"
}
