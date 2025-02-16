#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "ERROR: Please run as root"
  exit
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "$(realpath -- "${BASH_SOURCE[0]}")" )" &> /dev/null && pwd )
# shellcheck source=configuration/scripts/ratos-common.sh
source "$SCRIPT_DIR"/ratos-common.sh
# shellcheck source=configuration/scripts/moonraker-ensure-policykit-rules.sh
source "$SCRIPT_DIR"/moonraker-ensure-policykit-rules.sh

update_symlinks()
{
  report_status "Updating RatOS device symlinks..."
  
  # Get list of board rule files
  board_rules=("${RATOS_PRINTER_DATA_DIR}"/config/RatOS/boards/*/*.rules)
  
  # Check each board rule file
  for source in "${board_rules[@]}"; do
    if [ ! -f "$source" ]; then
      continue
    fi
    
    filename=$(basename "$source")
    target="/etc/udev/rules.d/98-${filename}"
    
    # Check if symlink exists and points to correct source
    if [ ! -L "$target" ] || [ ! "$(readlink "$target")" = "$source" ]; then
      rm -f "$target"
      ln -s "$source" "$target"
      echo "Updated symlink for ${filename}"
    else
      echo "Symlink for ${filename} already correct"
    fi
  done
  
  echo "RatOS device symlinks are up to date!"
}

ensure_node_18()
{
	report_status "Ensuring Node 18 is installed"
	node -v | grep "^v18" > /dev/null
	isinstalled=$?
	if [ $isinstalled -eq 0 ]
	then
		echo "Node 18 already installed"
	else
		echo "Installing Node 18"
		sed -i 's/node_16\.x/node_18\.x/g' /etc/apt/sources.list.d/nodesource.list
		apt-get update
		apt-get install -y nodejs && echo "Node 18 installed!"
	fi
}

fix_klippy_env_ownership()
{
	report_status "Ensuring klipper environment ownership"
	if [ -n "$(find "${KLIPPER_ENV}" \! -user "${RATOS_USERNAME}" -o \! -group "${RATOS_USERGROUP}" -quit)" ]; then
		chown -R "${RATOS_USERNAME}:${RATOS_USERGROUP}" "${KLIPPER_ENV}"
		echo "Klipper environment ownership has been set to ${RATOS_USERNAME}:${RATOS_USERGROUP}."
	else
		echo "Klipper environment ownership already set correctly."
	fi
}

symlink_extensions()
{
	report_status "Symlinking klippy extensions"
	ratos extensions symlink
	configurator_success=$?
	if [ ! $configurator_success -eq 0 ]
	then
		echo "Failed to symlink klippy extensions. Is the RatOS configurator running?"
		exit 1
	fi
	echo "Klippy extensions symlinked!"
}

# Run update symlinks
update_symlinks
ensure_sudo_command_whitelisting
ensure_service_permission
ensure_node_18
fix_klippy_env_ownership
patch_klipperscreen_service_restarts
install_beacon
install_hooks
remove_old_postprocessor
verify_registered_extensions
symlink_extensions
update_beacon_fw
