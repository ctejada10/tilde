#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# CONFIGURATION — EDIT THESE FIRST
###############################################################################

NEW_SSH_PORT=6969        # New SSH port
USER_NAME="YOURUSERNAME" # The user you log in as (non-root)

###############################################################################
# HELPER
###############################################################################

log() { echo "[*] $*"; }

###############################################################################
# PRECHECKS
###############################################################################

if ! id "$USER_NAME" >/dev/null 2>&1; then
    echo "User $USER_NAME does not exist. Exiting."
    exit 1
fi

log "Starting secure hardening for fresh Ubuntu 24.04 installation."

###############################################################################
# SYSTEM UPDATE & TOOLS
###############################################################################

apt update && apt upgrade -y
apt install -y ufw fail2ban auditd nc

###############################################################################
# SSH CONFIGURATION — SAFE MODE FIRST (password allowed)
###############################################################################

log "Configuring SSH in safe mode..."

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

mkdir -p /etc/ssh/sshd_config.d/

cat <<EOF > /etc/ssh/sshd_config.d/10-safe-initial.conf
# SAFE MODE SSH CONFIG FOR FRESH INSTALL

Port ${NEW_SSH_PORT}

# Allow both password & key auth *initially*
PasswordAuthentication yes
PubkeyAuthentication yes

# Hardening settings
PermitRootLogin no
Protocol 2
MaxAuthTries 5
LoginGraceTime 30
X11Forwarding no
UsePAM yes
EOF

# Update systemd SSH socket (Ubuntu 24.04)
mkdir -p /etc/systemd/system/ssh.socket.d
cat <<EOF > /etc/systemd/system/ssh.socket.d/override.conf
[Socket]
ListenStream=${NEW_SSH_PORT}
EOF

systemctl daemon-reload
systemctl restart ssh.socket ssh.service

###############################################################################
# FIREWALL — SSH OPEN GLOBALLY, PROTECTED BY FAIL2BAN
###############################################################################

log "Configuring UFW firewall..."

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow web server ports
ufw allow 80/tcp
ufw allow 443/tcp

# Allow SSH globally
ufw allow ${NEW_SSH_PORT}/tcp comment "SSH access"

# Enable firewall
ufw --force enable

###############################################################################
# FAIL2BAN CONFIGURATION
###############################################################################

log "Configuring Fail2Ban..."

cat <<EOF > /etc/fail2ban/jail.d/ssh.local
[sshd]
enabled = true
port = ${NEW_SSH_PORT}
backend = systemd
maxretry = 5
findtime = 600
bantime = 1800
ignoreip = 127.0.0.1/8 ::1
banaction = ufw
EOF

systemctl restart fail2ban

###############################################################################
# KERNEL / SYSCTL HARDENING
###############################################################################

log "Applying kernel/network sysctl hardening..."

cp /etc/sysctl.conf /etc/sysctl.conf.backup

cat <<EOF >> /etc/sysctl.conf

# Security hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.rp_filter = 1
kernel.kptr_restrict = 2
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
EOF

sysctl --system

###############################################################################
# AUTO-SECURE MODE — DISABLE PASSWORDS AFTER KEY IS INSTALLED
###############################################################################

log "Installing secure-mode auto-upgrade mechanism..."

cat <<'EOS' > /usr/local/sbin/upgrade_ssh_to_secure_mode.sh
#!/usr/bin/env bash
set -euo pipefail

USER_NAME="YOURUSERNAME"
KEYFILE="/home/${USER_NAME}/.ssh/authorized_keys"

# Only upgrade to secure mode if key exists and file is nonempty
if [ ! -f "$KEYFILE" ]; then
    exit 0
fi

if [ ! -s "$KEYFILE" ]; then
    exit 0
fi

echo "[*] SSH key detected — enabling secure mode (password login OFF)."

cat <<CONF > /etc/ssh/sshd_config.d/20-secure-mode.conf
# SECURE MODE: Password login disabled
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
CONF

systemctl restart ssh.service ssh.socket
EOS

# Insert username into script
sed -i "s/YOURUSERNAME/${USER_NAME}/g" /usr/local/sbin/upgrade_ssh_to_secure_mode.sh
chmod +x /usr/local/sbin/upgrade_ssh_to_secure_mode.sh

# systemd service
cat <<EOF > /etc/systemd/system/securemode.service
[Unit]
Description=Upgrade SSH to secure mode once key exists

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/upgrade_ssh_to_secure_mode.sh
EOF

# systemd timer
cat <<EOF > /etc/systemd/system/securemode.timer
[Unit]
Description=Periodically check for SSH key and disable password login

[Timer]
OnBootSec=30s
OnUnitActiveSec=60s
Unit=securemode.service

[Install]
WantedBy=timers.target
EOF

systemctl enable --now securemode.timer

###############################################################################
# DONE
###############################################################################

cat <<EOF

=======================================================================
INITIAL HARDENING COMPLETE
=======================================================================

SSH is now on port ${NEW_SSH_PORT}.
Password login is ENABLED temporarily.

⚠ NEXT STEPS (IMPORTANT):

1. SSH into the server using:
   ssh -p ${NEW_SSH_PORT} ${USER_NAME}@SERVER_IP

2. Install your SSH key:
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   nano ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys

3. Within 60 seconds, the system will automatically:
   ✓ Detect the SSH key
   ✓ Disable password authentication
   ✓ Reload SSH securely

After that, only key-based SSH will work.

Keep your current session open while testing new SSH login.

=======================================================================
EOF
