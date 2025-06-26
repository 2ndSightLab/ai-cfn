create_file_if_not_exists() {
    local file_path="$1"
    
    # Check if the file exists
    if [ ! -e "$file_path" ]; then
        # File doesn't exist, ask user if they want to create it
        read -p "File $file_path does not exist. Do you want to create it? (y/n): " user_response

        if [ "$user_response" = "y" ] || [ "$user_response" = "Y" ]; then
            # Create the directory structure if it doesn't exist
            mkdir -p "$(dirname "$file_path")"
            
            # Create the file
            touch "$file_path"
            echo "File $file_path has been created."
        else
            echo "File creation cancelled."
        fi
    else
        echo "File $file_path already exists."
    fi
}
