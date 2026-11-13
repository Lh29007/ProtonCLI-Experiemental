#!/bin/sh
# Proton-CLI installer.
#
# Downloads a pinned release of proton-cli, verifies its SHA-256 checksum,
# checks that it is the expected version, then installs it in /usr/local/bin.
#
#   curl -fsSL https://raw.githubusercontent.com/Lh29007/ProtonCLI-Experiemental/v0.7.0-exp/install.sh | sudo sh
#
# Environment overrides (mostly for testing):
#   PROTON_CLI_REF          git ref to install from (default: v$VERSION)
#   PROTON_CLI_URL          URL of proton-cli
#   PROTON_CLI_SHA_URL      URL of its SHA-256 file
#   PROTON_CLI_INSTALL_DIR  destination directory (bypasses the root check)

set -eu

VERSION="0.7.0-exp"

REF="${PROTON_CLI_REF:-v$VERSION}"
REPO_RAW="https://raw.githubusercontent.com/Lh29007/ProtonCLI-Experiemental/$REF"
SCRIPT_URL="${PROTON_CLI_URL:-$REPO_RAW/proton-cli}"
SHA_URL="${PROTON_CLI_SHA_URL:-$REPO_RAW/proton-cli.sha256}"

INSTALL_DIR="${PROTON_CLI_INSTALL_DIR:-/usr/local/bin}"
INSTALL_PATH="$INSTALL_DIR/proton-cli"

error()
{
    echo ""
    echo "[ERROR] $*" >&2
    exit 1
}

info()
{
    echo "[+] $*"
}

ok()
{
    echo "[OK] $*"
}

echo ""
echo "============================================="
echo " Proton-CLI v$VERSION installer"
echo "============================================="
echo ""
echo "Source      : $REF"
echo "Installation: $INSTALL_PATH"
echo ""

if [ -z "${PROTON_CLI_INSTALL_DIR:-}" ] && [ "$(id -u)" -ne 0 ]; then
    error "This installer must be run with sudo: curl ... | sudo sh"
fi

# ------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------

info "Checking dependencies..."

MISSING=0
for command in curl tar gzip file sha256sum
do
    if ! command -v "$command" >/dev/null 2>&1; then
        MISSING=1
    fi
done

if [ "$MISSING" -eq 1 ]; then
    info "Installing missing dependencies..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y curl tar gzip file coreutils
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl tar gzip file coreutils
    elif command -v pacman >/dev/null 2>&1; then
        pacman -S --needed --noconfirm curl tar gzip file coreutils
    else
        error "Missing dependencies and no supported package manager (apt, dnf, pacman)."
    fi

    for command in curl tar gzip file sha256sum
    do
        if ! command -v "$command" >/dev/null 2>&1; then
            error "$command is still missing after installation."
        fi
    done
fi

ok "Dependencies available."

# ------------------------------------------------------------
# Download and verify
# ------------------------------------------------------------

TMP_DIR="$(mktemp -d)"

cleanup()
{
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM

info "Downloading proton-cli..."

if ! curl \
    --fail \
    --location \
    --show-error \
    --silent \
    --retry 3 \
    --connect-timeout 15 \
    --output "$TMP_DIR/proton-cli" \
    "$SCRIPT_URL"
then
    error "Unable to download proton-cli from $SCRIPT_URL"
fi

if ! curl \
    --fail \
    --location \
    --show-error \
    --silent \
    --retry 3 \
    --connect-timeout 15 \
    --output "$TMP_DIR/proton-cli.sha256" \
    "$SHA_URL"
then
    error "Checksum file not available: $SHA_URL"
fi

if [ ! -s "$TMP_DIR/proton-cli" ]; then
    error "The downloaded file is empty."
fi

info "Verifying checksum..."

if ! (cd "$TMP_DIR" && sha256sum -c proton-cli.sha256 >/dev/null 2>&1); then
    error "Checksum mismatch: the download was not installed."
fi

ok "Checksum matches."

info "Validating the script..."

if ! head -n 1 "$TMP_DIR/proton-cli" | grep -q '^#!/bin/sh'; then
    error "proton-cli is not a /bin/sh script."
fi

if ! sh -n "$TMP_DIR/proton-cli"; then
    error "proton-cli contains a syntax error."
fi

if ! grep -q "^VERSION=\"$VERSION\"" "$TMP_DIR/proton-cli"; then
    error "Downloaded proton-cli is not version $VERSION."
fi

ok "Script is valid and at version $VERSION."

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

info "Installing to $INSTALL_PATH..."

mkdir -p "$INSTALL_DIR"
cp "$TMP_DIR/proton-cli" "$INSTALL_PATH"
chmod 755 "$INSTALL_PATH"

ok "Installed."

echo ""
echo "============================================="
echo " Proton-CLI installed"
echo "============================================="
echo ""
echo "Next steps:"
echo "  proton-cli doctor"
echo "  proton-cli install       # downloads a Proton runtime for your architecture"
echo ""
