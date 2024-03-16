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

# generate_mobileconfig() {
#     local userName="$1"
#     local password="$2"
#     local cert="$3"
#     local ip="$4"
#     local template_path="vpn-config.mobileconfig.template"
#     local output_path="vpn-config.mobileconfig"

#     sed -e "s/VPN_USERNAME/$userName/g" \
#         -e "s/VPN_PASSWORD/$password/g" \
#         -e "s/VPN_CERTIFICATE/$cert/g" \
#         -e "s/VPN_SERVER_ADDRESS/$ip/g" \
#         "$template_path" > "$output_path"
# }
# generate_mobileconfig "$userName" "$password" "$cert" "$ip"

status_update=0

# Loop through all users
# for i in "${!users_array[@]}"; do
#     user="${users_array[$i]}"
#     password="${user}_${passwords_array[0]}"
    
#     # Check if the user is already added
#     if user_exists_in_file "$user"; then
#         echo "User $user already exists in $FILE_PATH_SECRETS."
#     else
#         # Add user to the file
#         status_update=1
#         add_user_to_file "$user" "$password"
#         echo "Added $user to $FILE_PATH_SECRETS."
#     fi
# done

# Define a function to handle user existence check and addition
handle_user_addition() {
    local user="$1"
    local password="$2"

    if user_exists_in_file "$user"; then
        echo "User $user already exists in $FILE_PATH_SECRETS."
    else
        # Add user to the file
        status_update=1
        add_user_to_file "$user" "$password"
        echo "Added $user to $FILE_PATH_SECRETS."
    fi
}

# Check if there are more users than passwords
if [[ ${#users_array[@]} -gt ${#passwords_array[@]} ]]; then
    # If there are more users, use the first password for all users
    for user in "${users_array[@]}"; do
        password="${user}_${passwords_array[0]}"
        handle_user_addition "$user" "$password"
    done
else
    # If the number of users and passwords is equal, assign passwords by index
    for i in "${!users_array[@]}"; do
        user="${users_array[$i]}"
        password="${passwords_array[$i]}"
        
        handle_user_addition "$user" "$password"
    done
fi


ipsec restart

if [ $status_update -eq 1 ]; then
    echo "Secrets updated"
else
    echo "No changes were made to $FILE_PATH_SECRETS."
fi
