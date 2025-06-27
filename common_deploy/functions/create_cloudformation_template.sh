#/bin/bash -e
create_cloudformation_template() {
    local SERVICE_NAME="$1"
    local RESOURCE_NAME="$2"
    local TEMPLATE_FILE_PATH=$(get_template_file_path $SERVICE_NAME $RESOURCE_NAME)

    echo "Writing CloudFormation template file $TEMPLATE_FILE_PATH"
    
    # Get resource type that matches the SERVICE_NAME and RESOURCE_NAME
    resource_type=$(aws cloudformation list-types --visibility PUBLIC --type RESOURCE --query "TypeSummaries[?contains(TypeName, '${SERVICE_NAME}') && contains(TypeName, '${RESOURCE_NAME}')].TypeName" --output text)

    # Get properties and their types for the resource type, along with whether they are required
    properties_info=$(aws cloudformation describe-type --type RESOURCE --type-name "$resource_type" | jq -r '.Schema | .properties | to_entries[] | "\(.key):\(.value.type):\(.value.required // false)"')

    # Start the template
    echo "AWSTemplateFormatVersion: '2010-09-09'" > "$TEMPLATE_FILE_PATH"
    echo "Description: CloudFormation template for $SERVICE_NAME $RESOURCE_NAME" >> "$TEMPLATE_FILE_PATH"
    echo "" >> "$TEMPLATE_FILE_PATH"

    # Add Parameters
    echo "Parameters:" >> "$TEMPLATE_FILE_PATH"
    for prop_info in $properties_info; do
        IFS=':' read -r prop type required <<< "$prop_info"
        
        # Map JSON Schema types to CloudFormation parameter types
        case "$type" in
            "integer"|"number") cf_type="Number" ;;
            "boolean") cf_type="String"; echo "    AllowedValues: [true, false]" >> "$TEMPLATE_FILE_PATH" ;;
            "array") cf_type="CommaDelimitedList" ;;
            *) cf_type="String" ;;
        esac
        
        echo "  ${prop}:" >> "$TEMPLATE_FILE_PATH"
        echo "    Type: ${cf_type}" >> "$TEMPLATE_FILE_PATH"
        if [ "$required" = "true" ]; then
            echo "    Description: Required - Enter value for ${prop}" >> "$TEMPLATE_FILE_PATH"
        else
            echo "    Description: Optional - Enter value for ${prop}" >> "$TEMPLATE_FILE_PATH"
            echo "    Default: ''" >> "$TEMPLATE_FILE_PATH"
        fi
    done
    echo "" >> "$TEMPLATE_FILE_PATH"

    # Add Conditions
    echo "Conditions:" >> "$TEMPLATE_FILE_PATH"
    for prop_info in $properties_info; do
        IFS=':' read -r prop type required <<< "$prop_info"
        echo "  Has${prop}: !Not [!Equals [!Ref ${prop}, '']]" >> "$TEMPLATE_FILE_PATH"
    done
    echo "" >> "$TEMPLATE_FILE_PATH"

    # Add Resources
    echo "Resources:" >> "$TEMPLATE_FILE_PATH"
    echo "  ${RESOURCE_NAME}:" >> "$TEMPLATE_FILE_PATH"
    echo "    Type: ${resource_type}" >> "$TEMPLATE_FILE_PATH"
    echo "    Properties:" >> "$TEMPLATE_FILE_PATH"
    for prop_info in $properties_info; do
        IFS=':' read -r prop type required <<< "$prop_info"
        echo "      ${prop}: !If [Has${prop}, !Ref ${prop}, !Ref 'AWS::NoValue']" >> "$TEMPLATE_FILE_PATH"
    done
    echo "" >> "$TEMPLATE_FILE_PATH"

    # Add Outputs
    echo "Outputs:" >> "$TEMPLATE_FILE_PATH"
    echo "  ${RESOURCE_NAME}Id:" >> "$TEMPLATE_FILE_PATH"
    echo "    Description: The ID of the ${SERVICE_NAME} ${RESOURCE_NAME}" >> "$TEMPLATE_FILE_PATH"
    echo "    Value: !Ref ${RESOURCE_NAME}" >> "$TEMPLATE_FILE_PATH"

    echo "CloudFormation template created and saved to $TEMPLATE_FILE_PATH"
}
