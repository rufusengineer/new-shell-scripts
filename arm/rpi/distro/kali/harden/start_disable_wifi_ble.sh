#!/bin/bash
# Kali Pi Wireless Disabler - Permanently disable all wireless interfaces
# Run with: sudo ./disable_wireless.sh
# Recommended: chmod +x disable_wireless.sh

set -e

echo -e "\n\033[1;31m[+] Kali Pi Wireless Disabler\033[0m"
echo -e "\033[1;33m[i] This will permanently disable all wireless services\033[0m"

# Check if running on Kali ARM
if ! grep -q "Kali GNU/Linux Rolling" /etc/os-release; then
    echo -e "\033[1;31m[!] Error: This script is designed for Kali Linux on ARM\033[0m"
    exit 1
fi

# Check root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[1;31m[!] Error: Run this script as root\033[0m"
    exit 1
fi

# =============================================
# 1. Disable WiFi
# =============================================
echo -e "\n\033[1;34m[+] Disabling WiFi...\033[0m"
rfkill block wifi
nmcli radio wifi off 2>/dev/null || true

# Disable WiFi at kernel module level
echo -e "\033[1;33m[i] Blacklisting WiFi modules...\033[0m"
cat > /etc/modprobe.d/disable-wifi.conf <<EOF
# Disable WiFi
blacklist brcmfmac
blacklist brcmutil
blacklist cfg80211
blacklist mac80211
blacklist rfkill
EOF

# =============================================
# 2. Disable Bluetooth
# =============================================
echo -e "\n\033[1;34m[+] Disabling Bluetooth...\033[0m"
systemctl stop bluetooth 2>/dev/null || true
systemctl disable bluetooth 2>/dev/null || true
rfkill block bluetooth

# Kernel level disable
echo -e "\033[1;33m[i] Blacklisting Bluetooth modules...\033[0m"
cat > /etc/modprobe.d/disable-bluetooth.conf <<EOF
# Disable Bluetooth
blacklist btbcm
blacklist btintel
blacklist btrtl
blacklist btsdio
blacklist btusb
blacklist bluetooth
EOF

# =============================================
# 3. Disable NFC/RFID (if hardware exists)
# =============================================
echo -e "\n\033[1;34m[+] Disabling NFC/RFID...\033[0m"
modprobe -r pn533 nfc 2>/dev/null || true
cat > /etc/modprobe.d/disable-nfc.conf <<EOF
# Disable NFC/RFID
blacklist pn533
blacklist nfc
EOF

# =============================================
# 4. Disable Other Wireless
# =============================================
echo -e "\n\033[1;34m[+] Disabling other wireless services...\033[0m"

# Disable 60GHz wireless (like wigig)
rfkill block wwan 2>/dev/null || true
rfkill block uwb 2>/dev/null || true
rfkill block all 2>/dev/null || true

# Disable IR (infrared)
modprobe -r ir_lirc_codec lirc_dev 2>/dev/null || true
cat > /etc/modprobe.d/disable-ir.conf <<EOF
# Disable Infrared
blacklist ir_lirc_codec
blacklist lirc_dev
EOF

# =============================================
# 5. Make Changes Persistent
# =============================================
echo -e "\n\033[1;34m[+] Making changes persistent...\033[0m"

# Update initramfs
update-initramfs -u

# Disable wireless services
systemctl mask wpa_supplicant.service 2>/dev/null || true

# Disable NetworkManager's wireless (if installed)
systemctl stop NetworkManager 2>/dev/null || true
systemctl disable NetworkManager 2>/dev/null || true

# =============================================
# 6. Verify Changes
# =============================================
echo -e "\n\033[1;32m[✓] Verification:\033[0m"
echo -e "\033[1;33m[i] Current RFKill status:\033[0m"
rfkill list

echo -e "\n\033[1;33m[i] Active wireless interfaces:\033[0m"
iwconfig 2>/dev/null || echo "No wireless interfaces found"

echo -e "\n\033[1;33m[i] Bluetooth status:\033[0m"
systemctl status bluetooth 2>/dev/null | grep -E "Loaded|Active" || echo "Bluetooth not found"

echo -e "\n\033[1;32m[✓] All wireless services disabled persistently!\033[0m"
echo -e "\033[1;31m[!] Reboot required for changes to take full effect\033[0m\n"

echo -e "\033[1;31m[!] Adding this script to system startup \033[0m\n"
sudo ln -s start_disable_wifi_ble.sh /etc/rc.local
