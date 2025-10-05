#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

read -p "Enter the new username: " USERNAME

# Check if the user already exists
if id "$USERNAME" &>/dev/null; then
    echo "User '$USERNAME' already exists. Exiting."
    exit 1
fi

# Add the user
adduser --gecos "" "$USERNAME"

# Set the password for the new user
echo "Setting password for $USERNAME"
passwd "$USERNAME"

read -p "Add '$USERNAME' to the sudo group? (y/N): " ADD_SUDO

if [[ "$ADD_SUDO" =~ ^[Yy]$ ]]; then
    usermod -aG sudo "$USERNAME"
    echo "User '$USERNAME' added to the sudo group."
fi

echo "User '$USERNAME' created successfully."
