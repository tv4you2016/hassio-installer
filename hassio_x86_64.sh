#!/usr/bin/env bash
##############################################################
##############################################################
##                                                          ##
## THIS SCRIPT SHOULD ONLY BE RUN ON A X86_64 LINUX MACHINE ##
##                                                          ##
##############################################################
##############################################################
set -o errexit  # Exit script when a command exits with non-zero status
set -o errtrace # Exit on error inside any functions or sub-shells
set -o nounset  # Exit script on use of an undefined variable
set -o pipefail # Return exit status of the last command in the pipe that failed

# ==============================================================================
# GLOBALS
# ==============================================================================
readonly HOSTNAME="hassio"
readonly HASSIO_INSTALLER="https://raw.githubusercontent.com/home-assistant/hassio-installer/master/hassio_install.sh"
readonly REQUIREMENTS=(
  apparmor-utils
  apt-transport-https
  avahi-daemon
  ca-certificates
  curl
  dbus
  jq
  network-manager
  socat
  software-properties-common
)

# ==============================================================================
# SCRIPT LOGIC
# ==============================================================================

# ------------------------------------------------------------------------------
# Ensures the hostname is correct.
# ------------------------------------------------------------------------------
update_hostname() {
  old_hostname=$(< /etc/hostname)
  if [[ "${old_hostname}" != "${HOSTNAME}" ]]; then
    sed -i "s/${old_hostname}/${HOSTNAME}/g" /etc/hostname
    sed -i "s/${old_hostname}/${HOSTNAME}/g" /etc/hosts
    hostname "${HOSTNAME}"
    echo "Hostname will be changed on next reboot: ${HOSTNAME}"
  fi
}

# ------------------------------------------------------------------------------
# Installs all required software packages and tools
# ------------------------------------------------------------------------------
install_requirements() {
  echo "Updating APT packages list..."
  apt-get update

  echo "Ensure all requirements are installed..."
  apt-get install -y "${REQUIREMENTS[@]}"
}

# ------------------------------------------------------------------------------
# Installs the Docker engine
# ------------------------------------------------------------------------------
install_docker() {
  echo "Installing Docker..."
  curl -sSL https://get.docker.com | sh
}

# ------------------------------------------------------------------------------
# Installs and starts Hass.io
# ------------------------------------------------------------------------------
install_hassio() {
  echo "Installing Hass.io..."
  curl -sL "${HASSIO_INSTALLER}" | bash -s -- -m qemux86-64
}

# ------------------------------------------------------------------------------
# Configure network-manager to disable random MAC-address on Wi-Fi
# ------------------------------------------------------------------------------
config_network_manager() {
  {
    echo -e "\n[device]";
    echo "wifi.scan-rand-mac-address=no";
    echo -e "\n[connection]";
    echo "wifi.clone-mac-address=preserve";
  } >> "/etc/NetworkManager/NetworkManager.conf"
}

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
main() {
  # Are we root?
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    echo "Please try again after running:"
    echo "  sudo su"
    exit 1
  fi

  # Install ALL THE THINGS!
  update_hostname
  install_requirements
  config_network_manager
  install_docker
  install_hassio

  # Friendly closing message
  ip_addr=$(hostname -I | cut -d ' ' -f1)
  echo "======================================================================="
  echo "Hass.io is now installing Home Assistant."
  echo "This process may take up to 20 minutes. Please visit:"
  echo "http://${HOSTNAME}.local:8123/ in your browser and wait"
  echo "for Home Assistant to load."
  echo "If the previous URL does not work, please try http://${ip_addr}:8123/"

  exit 0
}
main
