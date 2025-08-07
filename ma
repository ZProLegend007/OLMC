#!/bin/bash

# ma - Make Admin Script
# Creates a new admin user account with prompts for username and password
# Designed for recovery mode root access

# Function to validate username
validate_username() {
    local username="$1"
    
    # Check if username is empty
    if [[ -z "$username" ]]; then
        echo "Username cannot be empty."
        return 1
    fi
    
    # Check if username contains only valid characters (alphanumeric, underscore, hyphen)
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Username can only contain letters, numbers, underscores, and hyphens."
        return 1
    fi
    
    # Check if username already exists
    if dscl . -read "/Users/$username" 2>/dev/null >/dev/null; then
        echo "Username '$username' already exists."
        return 1
    fi
    
    # Check if username is too long
    if [[ ${#username} -gt 31 ]]; then
        echo "Username must be 31 characters or less."
        return 1
    fi
    
    return 0
}

# Function to validate password
validate_password() {
    local password="$1"
    
    # Check if password is empty
    if [[ -z "$password" ]]; then
        echo "Password cannot be empty."
        return 1
    fi
    
    # Check minimum length
    if [[ ${#password} -lt 4 ]]; then
        echo "Password must be at least 4 characters long."
        return 1
    fi
    
    return 0
}

# Function to create admin user
create_admin_user() {
    local username="$1"
    local password="$2"
    
    echo "Creating admin user '$username'..."
    
    # Find next available UID (starting from 501)
    local next_uid=$(dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -n 1)
    next_uid=$((next_uid + 1))
    
    # Ensure UID is at least 501
    if [[ $next_uid -lt 501 ]]; then
        next_uid=501
    fi
    
    # Create user account
    if ! dscl . -create "/Users/$username"; then
        echo "Error: Failed to create user account."
        return 1
    fi
    
    # Set user properties
    dscl . -create "/Users/$username" UserShell /bin/bash
    dscl . -create "/Users/$username" RealName "$username"
    dscl . -create "/Users/$username" UniqueID "$next_uid"
    dscl . -create "/Users/$username" PrimaryGroupID 20
    dscl . -create "/Users/$username" NFSHomeDirectory "/Users/$username"
    
    # Set password
    if ! dscl . -passwd "/Users/$username" "$password"; then
        echo "Error: Failed to set password."
        # Clean up partially created user
        dscl . -delete "/Users/$username" 2>/dev/null
        return 1
    fi
    
    # Add user to admin group
    if ! dseditgroup -o edit -a "$username" -t user admin; then
        echo "Error: Failed to add user to admin group."
        # Clean up created user
        dscl . -delete "/Users/$username" 2>/dev/null
        return 1
    fi
    
    # Create home directory
    if ! createhomedir -c -u "$username"; then
        echo "Warning: Failed to create home directory. User created but may need manual home directory setup."
    fi
    
    echo "Successfully created admin user '$username'."
    return 0
}

# Main execution
echo "=== macOS Admin User Creation ==="
echo "This script will create a new administrator user account."
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (recovery mode)."
    exit 1
fi

# Prompt for username
while true; do
    echo -n "Enter desired username: "
    read -r username
    
    if validate_username "$username"; then
        break
    fi
    echo "Please try again."
    echo ""
done

echo ""

# Prompt for password
while true; do
    echo -n "Enter password for '$username': "
    read -r -s password
    echo ""
    
    if validate_password "$password"; then
        echo -n "Confirm password: "
        read -r -s password_confirm
        echo ""
        
        if [[ "$password" == "$password_confirm" ]]; then
            break
        else
            echo "Passwords do not match. Please try again."
            echo ""
        fi
    else
        echo "Please try again."
        echo ""
    fi
done

echo ""

# Create the admin user
if create_admin_user "$username" "$password"; then
    echo ""
    echo "Admin user creation completed successfully!"
    echo "You can now log in with username: $username"
else
    echo ""
    echo "Failed to create admin user. Please try again."
    exit 1
fi