#!/bin/bash

# TODO (harley): add support for rosdep source list

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

current_command=""

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo -e "${RED}[x]${NC} \"$last_command\" command failed with exit code $? in $0"' ERR

CHANNEL="${1:-stable}"  # Default to 'stable' if not provided

if [[ "$CHANNEL" != "stable" && "$CHANNEL" != "dev" ]]; then
  echo -e "${RED}[x]${NC} Invalid channel: \"$CHANNEL\". Choose 'stable' or 'dev'."
  exit 1
fi

echo -e "${GREEN}[+]${NC} Installing required packages: curl, gpg, dpkg-dev..."
sudo apt-get update -qq
sudo apt-get install -y curl gpg dpkg-dev

ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)
echo -e "${GREEN}[+]${NC} Detected architecture: $ARCH"

LIST_PATH="/etc/apt/sources.list.d/eolab-drones-stable.list"
KEY_URL="https://EOLab-HSRW.github.io/drones-ppa/eolab-drones.gpg"
KEYRING_PATH="/usr/share/keyrings/eolab-drones.gpg"
PREFERENCES_URL="https://EOLab-HSRW.github.io/drones-ppa/eolab-drones-stable.pref"

REPOS=(
  "drones-fw=https://EOLab-HSRW.github.io/drones-fw/=${ARCH} ${CHANNEL}"
)

echo -e "${GREEN}[+]${NC} Downloading and installing GPG key..."
curl -fsSL "$KEY_URL" | sudo tee "$KEYRING_PATH" > /dev/null

echo -e "${GREEN}[+]${NC} Writing APT sources to $LIST_PATH..."

sudo truncate -s 0 "$LIST_PATH"

for repo in "${REPOS[@]}"; do
  IFS='=' read -r name url custom <<< "$repo"
  custom=${custom:-"./"} 

  echo -e "${GREEN}[+]${NC} Adding APT source: $name"
  echo "deb [arch=$ARCH signed-by=$KEYRING_PATH] $url $custom" \
    | sudo tee -a "$LIST_PATH" > /dev/null
done

if curl -fsSL --head "$PREFERENCES_URL" | grep -qi '200 OK'; then

  echo -e "${GREEN}[+]${NC} Downloading and installing APT preferences..."
  sudo curl -fsSL "$PREFERENCES_URL" -o "/etc/apt/preferences.d/eolab-drones-stable.pref"
else
  echo -e "${YELLOW}[!]${NC} APT preferences not found at $PREFERENCES_URL — skipping."
fi

# -------------------------------
# 3rd-party GPG and sources list
echo -e "${GREEN}[+]${NC} Adding Gazebo GPG key..."
curl -fsSL "https://packages.osrfoundation.org/gazebo.gpg" | sudo tee "/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg" > /dev/null

echo -e "${GREEN}[+]${NC} Adding Gazebo APT source list..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null

# end 3rd-party
# -------------------------------

echo -e "${GREEN}[+]${NC} Updating package lists..."
sudo apt-get update -y

echo -e "${GREEN}[✓]${NC} Setup complete."
