#!/usr/bin/env bash
# Ubuntu LTS Hardening Script
# Applies basic security hardening for Ubuntu LTS systems
set -euo pipefail

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# 1. Update and upgrade
apt-get update && apt-get -y upgrade

# 2. Install security tools
apt-get install -y ufw fail2ban apt-listchanges unattended-upgrades



# --- UFW (firewall) configuration moved to end of script ---

# 4. Enable automatic security updates
cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# 5. Harden SSH configuration
SSHD_CONFIG="/etc/ssh/sshd_config"
sed -i 's/^#*Port .*/Port 6969/' "$SSHD_CONFIG" || echo 'Port 6969' >> "$SSHD_CONFIG"
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' "$SSHD_CONFIG"
systemctl reload ssh.service

# 6. Set up fail2ban
systemctl enable --now fail2ban

# 7. Remove unnecessary packages
apt-get -y autoremove
apt-get -y autoclean


# 8. Disable guest login (for desktop systems)
if [ -f /etc/lightdm/lightdm.conf ]; then
  sed -i '/^\[Seat:\*\]/a allow-guest=false' /etc/lightdm/lightdm.conf
fi

# 9. Enable and configure UFW (firewall) at the end, after SSH port change
echo "Checking SSH accessibility on port 6969 before enabling firewall..."
if nc -z localhost 6969; then
  echo "SSH is accessible on port 6969. Enabling firewall."
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 6969/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw --force enable
else
  echo "WARNING: SSH is NOT accessible on port 6969. Skipping firewall enable to prevent lockout."
  echo "Please verify SSH access and run 'sudo ufw --force enable' manually when ready."
fi

echo "Basic Ubuntu LTS hardening complete."
