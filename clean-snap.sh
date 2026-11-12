#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or with sudo: sudo $0"
  exit 1
fi

echo "=== 1. Uninstalling installed snap packages ==="
# Remove applications and extensions first, then base systems and runtimes
snaps=(
  desktop-security-center
  firmware-updater
  hwctl
  prompting-client
  snap-store
  snapd-desktop-integration
  gtk-common-themes
  gnome-46-2404
  mesa-2404
  bare
  core24
  snapd
)

for pkg in "${snaps[@]}"; do
  if snap list 2>/dev/null | grep -q "^$pkg "; then
    echo "Removing snap: $pkg..."
    snap remove --purge "$pkg" || true
  fi
done

# In case any residual snap packages remain
while [ "$(snap list 2>/dev/null | wc -l)" -gt 0 ]; do
  remaining=$(snap list 2>/dev/null | awk 'NR>1 {print $1}' | tr '\n' ' ')
  if [ -z "$remaining" ]; then
    break
  fi
  for pkg in $remaining; do
    echo "Removing residual package: $pkg..."
    snap remove --purge "$pkg" || true
  done
done

echo "=== 2. Stopping snapd services ==="
systemctl stop snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
systemctl disable snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true

echo "=== 3. Purging snapd packages from APT ==="
apt-get purge -y snapd gnome-software-plugin-snap ubuntu-core-launcher || true
apt-get autoremove --purge -y

echo "=== 4. Blocking snapd reinstallation ==="
cat << 'EOF' > /etc/apt/preferences.d/nosnap.pref
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

echo "=== 5. Removing residual files and directories ==="
rm -rf /snap \
       /var/snap \
       /var/lib/snapd \
       /var/cache/snapd \
       /usr/lib/snapd

# Clean user snap directories
rm -rf /root/snap
for user_home in /home/*; do
  if [ -d "$user_home" ]; then
    rm -rf "$user_home/snap" "$user_home/.snap"
  fi
done

echo "=== Done! Snap has been completely removed from the system. ==="
