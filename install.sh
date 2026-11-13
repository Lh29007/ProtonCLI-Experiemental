#!/bin/sh

set -eu

# ============================================================

# PROTON-CLI INSTALLER

# Version 0.6.0-exp

# ============================================================

VERSION="0.6.0-exp"

REPO="Lh29007/ProtonCLI-Experiemental"
RAW_URL="https://raw.githubusercontent.com/Lh29007/ProtonCLI-Experiemental/main/proton-cli"

INSTALL_DIR="/usr/local/bin"
INSTALL_PATH="$INSTALL_DIR/proton-cli"

# ============================================================

# Root check

# ============================================================

if [ "$(id -u)" -ne 0 ]; then
echo ""
echo "[ERROR] This installer must be run with sudo."
echo ""
echo "Usage:"
echo "  sudo ./install.sh"
echo ""
exit 1
fi

# ============================================================

# Detect real user

# ============================================================

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
REAL_USER="$SUDO_USER"
else
REAL_USER="root"
fi

REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

if [ -z "$REAL_HOME" ]; then
echo "[ERROR] Unable to determine the HOME directory of $REAL_USER."
exit 1
fi

# ============================================================

# Proton-CLI directories

# ============================================================

DATA_DIR="$REAL_HOME/.local/share/proton-cli"
CONFIG_DIR="$REAL_HOME/.config/proton-cli"

RUNTIMES_DIR="$DATA_DIR/runtimes"
PREFIXES_DIR="$DATA_DIR/prefixes"
GAMES_DIR="$DATA_DIR/games"
CACHE_DIR="$DATA_DIR/cache"
LOGS_DIR="$DATA_DIR/logs"

# ============================================================

# Functions

# ============================================================

error() {
echo ""
echo "[ERROR] $*"
echo ""
exit 1
}

ok() {
echo "[OK] $*"
}

info() {
echo "[+] $*"
}

# ============================================================

# Header

# ============================================================

echo ""
echo "============================================="
echo " Proton-CLI v$VERSION"
echo " Ultimate Installer"
echo "============================================="
echo ""
echo "User        : $REAL_USER"
echo "Source      : $RAW_URL"
echo "Installation: $INSTALL_PATH"
echo ""

# ============================================================

# Dependency check

# ============================================================

info "Checking dependencies..."

APT_PACKAGES=""

if ! command -v curl >/dev/null 2>&1; then
APT_PACKAGES="$APT_PACKAGES curl"
fi

if ! command -v tar >/dev/null 2>&1; then
APT_PACKAGES="$APT_PACKAGES tar"
fi

if ! command -v gzip >/dev/null 2>&1; then
APT_PACKAGES="$APT_PACKAGES gzip"
fi

if [ -n "$APT_PACKAGES" ]; then
if ! command -v apt-get >/dev/null 2>&1; then
error "Required dependencies are missing and apt-get is not available."
fi

info "Installing missing dependencies..."

apt-get update

# shellcheck disable=SC2086

apt-get install -y $APT_PACKAGES
fi

if ! command -v curl >/dev/null 2>&1; then
error "curl is still missing after installation."
fi

if ! command -v tar >/dev/null 2>&1; then
error "tar is still missing after installation."
fi

ok "Dependencies available."

# ============================================================

# Create directories

# ============================================================

info "Creating Proton-CLI directory structure..."

mkdir -p "$RUNTIMES_DIR"
mkdir -p "$PREFIXES_DIR"
mkdir -p "$GAMES_DIR"
mkdir -p "$CACHE_DIR"
mkdir -p "$LOGS_DIR"
mkdir -p "$CONFIG_DIR"

# ============================================================

# Permissions

# ============================================================

chown -R "$REAL_USER":"$(id -gn "$REAL_USER")" "$DATA_DIR"
chown -R "$REAL_USER":"$(id -gn "$REAL_USER")" "$CONFIG_DIR"

chmod 755 "$DATA_DIR"
chmod 755 "$CONFIG_DIR"

ok "Directory structure created."

# ============================================================

# Download

# ============================================================

TMP_FILE="$(mktemp)"

cleanup() {
rm -f "$TMP_FILE"
}

trap cleanup EXIT INT TERM

echo ""
info "Downloading from GitHub..."
echo ""
echo "$RAW_URL"
echo ""

if ! curl \
--fail \
--location \
--show-error \
--silent \
--retry 3 \
--connect-timeout 15 \
--output "$TMP_FILE" \
"$RAW_URL"
then
error "Unable to download proton-cli from GitHub."
fi

if [ ! -s "$TMP_FILE" ]; then
error "The downloaded file is empty."
fi

ok "Download completed."

# ============================================================

# Validate downloaded file

# ============================================================

echo ""
info "Validating downloaded file..."

if ! head -n 1 "$TMP_FILE" | grep -q '^#!/bin/sh'; then
error "proton-cli does not appear to be a valid /bin/sh script."
fi

if ! grep -q 'usage()' "$TMP_FILE" || ! grep -q 'install_ge()' "$TMP_FILE"; then
error "The downloaded proton-cli is invalid or incomplete."
fi

if ! sh -n "$TMP_FILE"; then
error "proton-cli contains a syntax error."
fi

ok "Syntax is valid."

# ============================================================

# Installation

# ============================================================

echo ""
info "Installing proton-cli..."

mkdir -p "$INSTALL_DIR"

cp "$TMP_FILE" "$INSTALL_PATH"

chmod 755 "$INSTALL_PATH"

ok "proton-cli installed to $INSTALL_PATH."

# ============================================================

# Final verification

# ============================================================

echo ""
info "Verifying installation..."

if [ ! -x "$INSTALL_PATH" ]; then
error "The installed file is not executable."
fi

if ! sh -n "$INSTALL_PATH"; then
rm -f "$INSTALL_PATH"
error "The installed file contains a syntax error."
fi

ok "Installation verified."

# ============================================================

# User permissions

# ============================================================

chown "$REAL_USER":"$(id -gn "$REAL_USER")" "$DATA_DIR"
chown "$REAL_USER":"$(id -gn "$REAL_USER")" "$CONFIG_DIR"

# ============================================================

# Finish

# ============================================================

echo ""
echo "============================================="
echo " Proton-CLI installed successfully"
echo "============================================="
echo ""
echo "Command:"
echo "  proton-cli"
echo ""
echo "Version:"
echo "  proton-cli version"
echo ""
echo "Diagnostics:"
echo "  proton-cli doctor"
echo ""
echo "Install GE-Proton:"
echo "  proton-cli install"
echo ""
echo "Data:"
echo "  $DATA_DIR"
echo ""
echo "Configuration:"
echo "  $CONFIG_DIR"
echo ""
echo "Uninstall:"
echo "  sudo proton-cli uninstall"
echo ""
echo "Installation complete."
echo ""
