#!/bin/bash
# install.sh - Manage Port 53 Fix Automation (Install / Uninstall)

set -e

SERVICE_FILE="/etc/systemd/system/fix53.service"
SCRIPT_FILE="/usr/local/bin/fix53.sh"

install_fix() {
    echo "[*] Installing fix53 script and service..."

    # Create the script
    cat << 'EOF' | sudo tee $SCRIPT_FILE > /dev/null
#!/bin/bash
# fix53.sh - Free up port 53 and set custom DNS

set -e

echo "[*] Stopping and disabling systemd-resolved..."
systemctl stop systemd-resolved || true
systemctl disable systemd-resolved || true

echo "[*] Updating resolv.conf..."
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
# Lock resolv.conf if chattr is available
if command -v chattr >/dev/null 2>&1; then
    chattr +i /etc/resolv.conf || true
fi

echo "[*] Restarting networking (if available)..."
systemctl restart networking || true
systemctl restart NetworkManager || true

echo "[*] Checking port 53..."
if ss -tuln | grep -E '(:53[[:space:]]|:53$)'; then
  echo "⚠ Port 53 is still in use!"
else
  echo "✔ Port 53 is free and ready."
fi
EOF

    sudo chmod +x $SCRIPT_FILE

    # Create the systemd service
    cat << 'EOF' | sudo tee $SERVICE_FILE > /dev/null
[Unit]
Description=Fix DNS and free up port 53 on boot
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fix53.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Enable service
    echo "[*] Enabling service..."
    sudo systemctl daemon-reload
    sudo systemctl enable fix53.service

    echo "[✔] Installation complete. Changes applied now. Reboot recommended for persistence."
}

uninstall_fix() {
    echo "[*] Uninstalling fix53 and restoring defaults..."

    # Remove service and script
    sudo systemctl disable fix53.service || true
    sudo rm -f $SERVICE_FILE
    sudo rm -f $SCRIPT_FILE
    sudo systemctl daemon-reload

    # Unlock resolv.conf if locked
    if command -v chattr >/dev/null 2>&1; then
        chattr -i /etc/resolv.conf || true
    fi
    rm -f /etc/resolv.conf

    echo "[*] Re-enabling systemd-resolved..."
    systemctl enable systemd-resolved || true
    systemctl start systemd-resolved || true

    echo "[✔] Uninstallation complete. System restored to defaults."
}

echo "============================"
echo " Port 53 Fix Manager "
echo "============================"
echo "1) Install Fix (free port 53, custom DNS)"
echo "2) Uninstall & Restore Defaults"
echo "============================"
read -rp "Choose an option [1-2]: " choice

case "$choice" in
    1) install_fix ;;
    2) uninstall_fix ;;
    *) echo "Invalid choice. Exiting." ;;
esac
