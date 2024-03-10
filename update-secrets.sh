#!/bin/bash

echo "Update secrets"
# Define the file path
FILE_PATH_SECRETS="/etc/ipsec.secrets"

# Convert strings to arrays
IFS=' ' read -r -a users_array <<< "$VPN_USERS"
IFS=' ' read -r -a passwords_array <<< "$VPN_PASSWORDS"

# Check if the file exists, if not, create it
if [ ! -f "$FILE_PATH_SECRETS" ]; then
    echo "File $FILE_PATH_SECRETS does not exist. Creating..."
    touch "$FILE_PATH_SECRETS"
fi

rsa_line_exists_in_file() {
    grep -qE "^\s*: RSA \"server-key.pem\"" "$FILE_PATH_SECRETS"
}

# Function to add the RSA line to the file
add_rsa_line_to_file() {
    echo ': RSA server-key.pem'  >> "$FILE_PATH_SECRETS"
}

# Check if the RSA line exists, if not, add it
if ! rsa_line_exists_in_file; then
    echo "RSA line not found in $FILE_PATH. Adding..."
    add_rsa_line_to_file
fi

# Function to check if a user is already in the file
user_exists_in_file() {
    local user=$1
    grep -qE "^$user\s*:\s*EAP" "$FILE_PATH_SECRETS"
}

# Function to add a user to the file
add_user_to_file() {
    local user=$1
    local password=$2
    echo "$user : EAP \"$password\"" >> "$FILE_PATH_SECRETS"
}

status_update=0

# Loop through all users
for i in "${!users_array[@]}"; do
    user="${users_array[$i]}"
    password="${passwords_array[$i]}"
    
    # Check if the user is already added
    if user_exists_in_file "$user"; then
        echo "User $user already exists in $FILE_PATH_SECRETS."
    else
        # Add user to the file
        status_update=1
        add_user_to_file "$user" "$password"
        echo "Added $user to $FILE_PATH_SECRETS."
    fi
done

ipsec restart

if [ $status_update -eq 1 ]; then
    echo "Secrets updated"
else
    echo "No changes were made to $FILE_PATH_SECRETS."
fi