#!/usr/bin/env bash
# setup_rclone_gdrive.sh -- One-time rclone setup for Google Drive on headless servers
#
# This script configures rclone to access Google Drive from Ada HPC or any
# server without a web browser. Uses a two-machine OAuth flow:
#
#   Step 1 (on your laptop with a browser): Run 'rclone authorize "drive"'
#   Step 2 (on Ada): Run this script and paste the token
#
# After setup, the pipeline can read/write Google Drive from Ada.
#
# Usage:
#   bash setup_rclone_gdrive.sh
#
# Author: Vishakha Agrawal, IIIT Hyderabad
# Date:   March 2026

set -e

REMOTE_NAME="antibiotic_gdrive"

echo "============================================================"
echo "  Google Drive Setup for Headless Server (Ada HPC)"
echo "============================================================"
echo ""

# Check if rclone is installed
if ! command -v rclone &>/dev/null; then
    echo "rclone not found. Installing..."
    # Try module load first (Ada HPC)
    if command -v module &>/dev/null; then
        module load rclone 2>/dev/null || true
    fi
    if ! command -v rclone &>/dev/null; then
        # Install to user's home directory
        echo "Installing rclone to ~/.local/bin..."
        curl -s https://rclone.org/install.sh | sudo bash 2>/dev/null || {
            # No sudo: install locally
            mkdir -p ~/.local/bin
            cd /tmp
            curl -sO https://downloads.rclone.org/rclone-current-linux-amd64.zip
            unzip -oq rclone-current-linux-amd64.zip
            cp rclone-*-linux-amd64/rclone ~/.local/bin/
            chmod +x ~/.local/bin/rclone
            export PATH="$HOME/.local/bin:$PATH"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
            cd -
            echo "Installed rclone to ~/.local/bin/rclone"
        }
    fi
fi

echo "rclone version: $(rclone version | head -1)"
echo ""

# Check if already configured
if rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:"; then
    echo "Remote '${REMOTE_NAME}' already configured."
    echo ""
    echo "Testing connection..."
    if rclone lsf "${REMOTE_NAME}:antibiotic_data/" --max-depth 1 2>/dev/null | head -5; then
        echo ""
        echo "Connection working. Setup complete."
        exit 0
    else
        echo "Connection test failed. Reconfiguring..."
        rclone config delete "${REMOTE_NAME}" 2>/dev/null || true
    fi
fi

echo "============================================================"
echo "  TWO-STEP OAUTH FLOW"
echo "============================================================"
echo ""
echo "Since this server has no web browser, you need to authorize"
echo "on a machine that does (your laptop/desktop)."
echo ""
echo "STEP 1: On your laptop (Mac/Windows/Linux), run:"
echo ""
echo "    rclone authorize \"drive\""
echo ""
echo "  If rclone is not installed on your laptop:"
echo "    Mac:     brew install rclone"
echo "    Windows: winget install Rclone.Rclone"
echo "    Linux:   curl https://rclone.org/install.sh | sudo bash"
echo ""
echo "  This will open a browser. Sign in with your Google account."
echo "  After authorizing, rclone will print a token JSON like:"
echo "    {\"access_token\":\"ya29...\",\"token_type\":\"Bearer\",...}"
echo ""
echo "STEP 2: Paste that token here when prompted."
echo ""
echo "============================================================"
echo ""
read -p "Press Enter when ready to paste the token..." _

# Create rclone config manually
echo ""
echo "Paste the ENTIRE token JSON (starts with { ends with }):"
echo "(It may be multi-line; paste it all, then press Enter)"
read -r TOKEN

if [ -z "$TOKEN" ]; then
    echo "ERROR: Empty token. Run 'rclone authorize \"drive\"' on your laptop first."
    exit 1
fi

# Write rclone config
RCLONE_CONF="${HOME}/.config/rclone/rclone.conf"
mkdir -p "$(dirname "$RCLONE_CONF")"

cat >> "$RCLONE_CONF" << EOF

[${REMOTE_NAME}]
type = drive
scope = drive
token = ${TOKEN}
team_drive =

EOF

echo ""
echo "Configuration saved to: $RCLONE_CONF"
echo ""

# Test connection
echo "Testing connection..."
if rclone lsf "${REMOTE_NAME}:antibiotic_data/" --max-depth 1 2>/dev/null; then
    echo ""
    echo "============================================================"
    echo "  SUCCESS: Google Drive connected!"
    echo "============================================================"
    echo ""
    echo "  Remote name: ${REMOTE_NAME}"
    echo "  Data folder: ${REMOTE_NAME}:antibiotic_data/"
    echo "  Output folder: ${REMOTE_NAME}:antibiotic_output/"
    echo ""
    echo "  The pipeline will now automatically:"
    echo "    - Download input data from Drive when not available locally"
    echo "    - Upload results to antibiotic_output/ after each run"
    echo ""
    echo "  Test commands:"
    echo "    rclone ls ${REMOTE_NAME}:antibiotic_data/"
    echo "    rclone ls ${REMOTE_NAME}:antibiotic_output/"
else
    echo ""
    echo "WARNING: Connection test failed."
    echo "The token may be invalid. Try again:"
    echo "  1. Run 'rclone authorize \"drive\"' on your laptop"
    echo "  2. Re-run this script"
    echo ""
    echo "To manually edit: nano $RCLONE_CONF"
fi
