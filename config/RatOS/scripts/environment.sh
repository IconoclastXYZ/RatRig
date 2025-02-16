#!/bin/bash

# performed outside of a function so that other scripts sourcing this in will run this by default

# Get the real user (not root) when script is run with sudo

if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER=$SUDO_USER
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
elif [ "$EUID" -ne 0 ]; then
    REAL_USER=$USER
    REAL_HOME=$HOME
else
    REAL_USER="pi"
    REAL_HOME="/home/pi"
fi

if [ "$REAL_USER" = "root" ]; then
    echo "Fatal Error: Unable to determine non-root user, please run as a normal user or use sudo, exiting..." >&2
    exit 1
fi

envFile="/usr/local/etc/.ratos.env"
userEnvFile="${REAL_HOME}/.ratos.env"

# create $envFile if file does not exist using sane defaults on a ratos pi image.
if [ ! -f "$envFile" ]; then
	echo "$envFile not found, determining default values..."
	CMD="tee"
	[ "$EUID" -ne 0 ] && CMD="sudo tee"
	RATOS_USER=$REAL_USER

	$CMD "$envFile" > /dev/null <<EOF
RATOS_USERNAME=${RATOS_USER}
RATOS_USERGROUP=${RATOS_USER}
RATOS_PRINTER_DATA_DIR=${REAL_HOME}/printer_data
MOONRAKER_DIR=${REAL_HOME}/moonraker
KLIPPER_DIR=${REAL_HOME}/klipper
KLIPPER_ENV=${REAL_HOME}/klippy-env
BEACON_DIR=${REAL_HOME}/beacon
EOF
	chmod a+r "$envFile"
	echo "Created $envFile with default values:"
	cat "$envFile"
	echo "You can create $userEnvFile to override these values for $RATOS_USER or modify $envFile to change them for all users."
fi

profileLink="/etc/profile.d/ratos.sh"
localProfileLink="$REAL_HOME/.profile.d/ratos.sh"
# Create symlink in profile.d if directory exists
if [ -d "$REAL_HOME/.profile.d" ]; then
	if [ ! -e "$localProfileLink" ]; then
		echo "Creating shell profile symlink $localProfileLink to $envFile"
		rm -f "$localProfileLink"
		ln -s "$envFile" "$localProfileLink" || echo "Warning: Failed to create profile.d symlink"
	fi
fi
# Create symlink in system profile.d if directory exists
if [ -d "/etc/profile.d" ]; then
    if [ ! -e "$profileLink" ]; then
		echo "Creating shell profile symlink $profileLink to $envFile"
        sudo rm -f "$profileLink"
        sudo ln -s "$envFile" "$profileLink" || echo "Warning: Failed to create profile.d symlink"
    fi
fi

# Function to load env files
load_env() {
    local file="$1"
    if [ -f "$file" ]; then
        while IFS='=' read -r key value || [ -n "$key" ]; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            # Only set if not already defined
            if [ -z "${!key}" ]; then
                export "$key=$value"
            fi
        done < "$file"
    fi
}

if [ ! -f "$envFile" ] && [ ! -f "$userEnvFile" ] ; then
	echo "Fatal Error: Unable to load RatOS environment, neither $envFile nor $userEnvFile found, exiting..." >&2
	exit 1
fi
[ -f "$envFile" ] && load_env "$envFile"
[ "$EUID" -ne 0 ] && [ -f "$userEnvFile" ] && load_env "$userEnvFile"
