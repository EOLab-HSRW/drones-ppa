#!/bin/bash

# TODO (harley): add support for rosdep source list

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "[✗] \"$last_command\" command failed with exit code $? in $0"' ERR

echo "[+] Installing required packages: curl, gpg, dpkg-dev..."
sudo apt-get update -qq
sudo apt-get install -y curl gpg dpkg-dev

ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)
echo "[+] Detected architecture: $ARCH"

LIST_PATH="/etc/apt/sources.list.d/eolab-drones-stable.list"
KEY_URL="https://EOLab-HSRW.github.io/drones-ppa/eolab-drones.gpg"
KEYRING_PATH="/usr/share/keyrings/eolab-drones.gpg"
PREFERENCES_URL="https://EOLab-HSRW.github.io/drones-ppa/eolab-drones-stable.pref"

REPOS=(
  "drones-fw=https://EOLab-HSRW.github.io/drones-fw/"
)

echo "[+] Downloading and installing GPG key..."
curl -fsSL "$KEY_URL" | sudo tee "$KEYRING_PATH" > /dev/null

echo "[+] Writing APT sources to $LIST_PATH..."

sudo truncate -s 0 "$LIST_PATH"

for repo in "${REPOS[@]}"; do
  name="${repo%%=*}"
  url="${repo#*=}"

  echo "[+] Adding APT source: $name"
  echo "deb [arch=$ARCH signed-by=$KEYRING_PATH] $url stable main" \
    | sudo tee -a "$LIST_PATH" > /dev/null
done

if curl -fsSL --head "$PREFERENCES_URL" | grep -qi '200 OK'; then

  echo "[+] Downloading and installing APT preferences..."
  sudo curl -fsSL -o "/etc/apt/preferences.d/eolab-drones-stable.pref" "$PREFERENCES_URL"
else
  echo "[!] APT preferences not found at $PREFERENCES_URL — skipping."
fi

echo "[+] Updating package lists..."
sudo apt-get update -y

echo "[✓] Setup complete."
