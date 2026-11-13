#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2015  # literal $ in generated fake scripts; test assertions use && / ||
# Integration tests for proton-cli and install.sh.
#
# Runs fully offline: a local HTTP server serves fake GitHub release JSON,
# fake Proton archives and checksums. The fake archives contain real ELF
# headers (x86-64 or aarch64), so the Wine architecture check is exercised.
# An arm64 host is simulated with a `uname` shim, so both the x86_64 and
# aarch64 code paths run on any machine.
#
# Usage: tests/run-tests.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PC="$ROOT/proton-cli"
INSTALLER="$ROOT/install.sh"

WORK="$(mktemp -d)"
SRV="$WORK/srv"
SHIM="$WORK/shim"
SRV_PID=""
PASS=0
FAIL=0

cleanup()
{
    if [ -n "$SRV_PID" ]; then
        kill "$SRV_PID" 2>/dev/null || true
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT

pass() { PASS=$((PASS + 1)); echo "  ok    $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }

# expect NAME EXPECTED_STATUS ACTUAL_STATUS
expect_status()
{
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (status $3, expected $2)"; fi
}

# expect_text NAME PATTERN TEXT
expect_text()
{
    if printf '%s' "$3" | grep -q -- "$2"; then pass "$1"; else fail "$1 (missing: $2)"; fi
}

# expect_no_text NAME PATTERN TEXT
expect_no_text()
{
    if printf '%s' "$3" | grep -q -- "$2"; then fail "$1 (unexpected: $2)"; else pass "$1"; fi
}

# Minimal ELF64 header with the given e_machine (0x3e x86-64, 0xb7 aarch64).
make_elf()
{
    python3 - "$1" "$2" <<'PY'
import struct, sys
path, machine = sys.argv[1], int(sys.argv[2], 16)
h = bytearray(64)
h[0:4] = b'\x7fELF'
h[4], h[5], h[6] = 2, 1, 1
struct.pack_into('<HHI', h, 16, 2, machine, 1)
struct.pack_into('<H', h, 52, 64)
open(path, 'wb').write(bytes(h))
PY
}

# make_runtime NAME MACHINE: fake Proton tree plus its .tar.gz and checksum.
make_runtime()
{
    local dir="$WORK/build/$1"
    mkdir -p "$dir/files/bin"
    printf '#!/bin/sh\necho "fake proton $*"\nexit "${FAKE_EXIT:-0}"\n' > "$dir/proton"
    chmod +x "$dir/proton"
    make_elf "$dir/files/bin/wine" "$2"
    tar -czf "$SRV/$1.tar.gz" -C "$dir" .
    (cd "$SRV" && sha512sum "$1.tar.gz" > "$1.sha512sum")
    (cd "$SRV" && sha512sum "$1.tar.gz" > "$1.tar.gz.sha512sum")
}

release_json()
{
    # release_json TAG URL...
    local tag="$1"; shift
    local out="{\"tag_name\": \"$tag\", \"assets\": ["
    local first=1 url
    for url in "$@"; do
        [ $first -eq 1 ] || out="$out,"
        out="$out {\"browser_download_url\": \"$url\"}"
        first=0
    done
    printf '%s]}\n' "$out"
}

echo "== Setup"

mkdir -p "$SRV" "$SHIM"
REAL_UNAME="$(command -v uname)"
printf '#!/bin/sh\nif [ "$1" = "-m" ]; then echo aarch64; else exec %s "$@"; fi\n' \
    "$REAL_UNAME" > "$SHIM/uname"
chmod +x "$SHIM/uname"

PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
BASE_URL="http://127.0.0.1:$PORT"

(cd "$SRV" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1) &
SRV_PID=$!

for _ in $(seq 1 50); do
    curl -s -o /dev/null "$BASE_URL/" && break
    sleep 0.1
done

make_runtime "GE-Proton-test-x86_64" 0x3e
make_runtime "DroidDeck-Proton-test-aarch64" 0xb7

release_json "GE-Proton-test" "$BASE_URL/GE-Proton-test-x86_64.tar.gz" \
    "$BASE_URL/GE-Proton-test-x86_64.sha512sum" > "$SRV/ge.json"
release_json "DroidDeck-Proton-test" "$BASE_URL/DroidDeck-Proton-test-aarch64.tar.gz" \
    "$BASE_URL/DroidDeck-Proton-test-aarch64.sha512sum" > "$SRV/dd.json"

export PROTON_GE_API="$BASE_URL/ge.json"
export PROTON_DROIDDECK_API="$BASE_URL/dd.json"
unset PROTON_RUNTIME_URL PROTON_WRAPPER GITHUB_TOKEN

new_home()
{
    H="$(mktemp -d -p "$WORK")"
}

# pc ARGS...: run proton-cli in the current HOME.
pc()
{
    HOME="$H" sh "$PC" "$@" 2>&1
}

# pc_arm ARGS...: same, with the host simulated as aarch64.
pc_arm()
{
    PATH="$SHIM:$PATH" HOME="$H" sh "$PC" "$@" 2>&1
}

echo "== Static checks"

sh -n "$PC" && pass "proton-cli: sh -n"
sh -n "$INSTALLER" && pass "install.sh: sh -n"

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -s sh "$PC" "$INSTALLER" >/dev/null 2>&1 \
        && pass "shellcheck clean (proton-cli, install.sh)" \
        || fail "shellcheck reports issues"
    shellcheck -s bash "$0" >/dev/null 2>&1 \
        && pass "shellcheck clean (tests)" || fail "shellcheck reports issues in tests"
else
    echo "  skip  shellcheck not installed"
fi

pc_version="$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$PC")"
inst_version="$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$INSTALLER")"
if [ "$pc_version" = "$inst_version" ] && [ -n "$pc_version" ]; then
    pass "versions match ($pc_version)"
else
    fail "version mismatch: proton-cli=$pc_version install.sh=$inst_version"
fi

if [ -f "$ROOT/proton-cli.sha256" ]; then
    (cd "$ROOT" && sha256sum -c proton-cli.sha256 >/dev/null 2>&1) \
        && pass "proton-cli.sha256 matches proton-cli" \
        || fail "proton-cli.sha256 is stale: regenerate it (see README, Release)"
fi

echo "== Install and runtime selection (x86_64 host)"

new_home
out="$(pc install)"; rc=$?
expect_status "install auto on x86_64 succeeds" 0 "$rc"
expect_text "auto selects GE-Proton on x86_64" "Source       : ge" "$out"
expect_text "checksum verified" "Checksum matches" "$out"
[ -f "$H/.local/share/proton-cli/runtimes/GE-Proton-test-x86_64/.proton-cli-tag" ] \
    && pass "release tag recorded" || fail "release tag recorded"
out="$(pc install)"
expect_text "second install is a no-op" "already installed" "$out"
out="$(pc update)"
expect_text "update is a no-op when up to date" "already installed" "$out"

echo "== Install and runtime selection (simulated aarch64 host)"

out="$(pc_arm install)"; rc=$?
expect_status "install auto on aarch64 succeeds" 0 "$rc"
expect_text "auto selects DroidDeck-Proton on aarch64" "Source       : droiddeck" "$out"
expect_text "aarch64 wine binary accepted" "Wine architecture matches aarch64" "$out"

out="$(pc_arm install ge)"; rc=$?
expect_status "install ge refused on aarch64" 1 "$rc"
expect_text "message points to droiddeck" "Use: proton-cli install droiddeck" "$out"

out="$(pc install droiddeck)"; rc=$?
expect_status "install droiddeck refused on x86_64" 1 "$rc"
expect_text "message points to ge" "DroidDeck-Proton is aarch64 only" "$out"

out="$(pc install foo)"; rc=$?
expect_status "unknown source refused" 1 "$rc"

out="$(pc list)"
expect_text "list marks the default runtime" "DroidDeck-Proton-test-aarch64 (default)" "$out"
expect_text "list shows both runtimes" "GE-Proton-test-x86_64" "$out"

out="$(pc use GE-Proton-test-x86_64)"; rc=$?
expect_status "use switches the default" 0 "$rc"
out="$(pc list)"
expect_text "list marks GE as default after use" "GE-Proton-test-x86_64 (default)" "$out"

out="$(pc use does-not-exist)"; rc=$?
expect_status "use rejects unknown runtime" 1 "$rc"

echo "== Running programs"

GAME_DIR="$WORK/games/alpha"
mkdir -p "$GAME_DIR"
echo "exe" > "$GAME_DIR/game.exe"

out="$(pc run "$GAME_DIR/game.exe" --flag)"; rc=$?
expect_status "run succeeds" 0 "$rc"
expect_text "run uses the default runtime" "Runtime : GE-Proton-test-x86_64" "$out"
expect_text "run shows the program's output" "fake proton run" "$out"
expect_text "run passes arguments" "--flag" "$out"
LOG="$H/.local/share/proton-cli/logs"
[ -n "$(ls "$LOG"/*.log 2>/dev/null)" ] && pass "run writes a log" || fail "run writes a log"

out="$(FAKE_EXIT=3 pc run "$GAME_DIR/game.exe")"; rc=$?
expect_status "run propagates the program exit status" 3 "$rc"
expect_text "failure is reported" "exited with status 3" "$out"

out="$(pc config "$GAME_DIR/game.exe" runtime DroidDeck-Proton-test-aarch64)"; rc=$?
expect_status "config sets a per-game runtime" 0 "$rc"
out="$(pc run "$GAME_DIR/game.exe")"
expect_text "per-game runtime is used" "Runtime : DroidDeck-Proton-test-aarch64" "$out"

out="$(pc config "$GAME_DIR/game.exe" wrapper "echo WRAPPED")"
out="$(pc run "$GAME_DIR/game.exe")"
expect_text "per-game wrapper is applied" "WRAPPED" "$out"
out="$(pc config "$GAME_DIR/game.exe" wrapper none)"
out="$(pc config "$GAME_DIR/game.exe" runtime default)"
out="$(pc config "$GAME_DIR/game.exe" show)"
expect_text "config show lists the settings file" "Settings :" "$out"
expect_no_text "reset to default clears runtime" "Runtime  : DroidDeck" "$out"

out="$(pc config "$GAME_DIR/game.exe" runtime missing-runtime)"; rc=$?
expect_status "config rejects unknown runtime" 1 "$rc"

echo "== Prefixes"

mkdir -p "$WORK/games/beta"
echo "exe" > "$WORK/games/beta/game.exe"
pc run "$WORK/games/beta/game.exe" >/dev/null
pc run "$GAME_DIR/game.exe" >/dev/null
count="$(find "$H/.local/share/proton-cli/prefixes" -mindepth 1 -maxdepth 1 | wc -l)"
if [ "$count" -eq 2 ]; then
    pass "two game.exe files get separate prefixes"
else
    fail "two game.exe files get separate prefixes (got $count)"
fi

out="$(pc reset "$GAME_DIR/game.exe" </dev/null)"; rc=$?
expect_text "reset asks for confirmation" "Aborted" "$out"
count="$(find "$H/.local/share/proton-cli/prefixes" -mindepth 1 -maxdepth 1 | wc -l)"
[ "$count" -eq 2 ] && pass "reset without confirmation keeps the prefix" \
    || fail "reset without confirmation keeps the prefix"

out="$(pc reset "$GAME_DIR/game.exe" --yes)"; rc=$?
expect_status "reset --yes succeeds" 0 "$rc"
count="$(find "$H/.local/share/proton-cli/prefixes" -mindepth 1 -maxdepth 1 | wc -l)"
[ "$count" -eq 1 ] && pass "reset removes only that game's prefix" \
    || fail "reset removes only that game's prefix"

out="$(pc prefix shared)"; rc=$?
expect_status "standalone prefix created" 0 "$rc"

echo "== Winetricks"

if command -v winetricks >/dev/null 2>&1; then
    pass "winetricks present: skipped the missing-tool check"
else
    out="$(pc winetricks "$GAME_DIR/game.exe" corefonts)"; rc=$?
    expect_status "winetricks refuses when not installed" 1 "$rc"
    expect_text "winetricks message names the tool" "winetricks" "$out"
fi

echo "== Removing and custom archives"

out="$(pc remove GE-Proton-test-x86_64)"; rc=$?
expect_status "remove succeeds" 0 "$rc"
out="$(pc list)"
expect_no_text "removing the default clears it" "(default)" "$out"

new_home
out="$(PROTON_RUNTIME_URL="$BASE_URL/DroidDeck-Proton-test-aarch64.tar.gz" pc_arm install)"; rc=$?
expect_status "custom archive installs when checksum is published" 0 "$rc"
expect_text "custom archive checksum verified" "Checksum matches" "$out"

new_home
cp "$SRV/GE-Proton-test-x86_64.tar.gz" "$SRV/custom-runtime.tar.gz"
out="$(PROTON_RUNTIME_URL="$BASE_URL/custom-runtime.tar.gz" pc_arm install)"; rc=$?
expect_status "x86_64 wine archive rejected on aarch64" 1 "$rc"
expect_text "wine architecture mismatch reported" "not compatible with aarch64" "$out"

echo "== Checksums"

new_home
cp "$SRV/GE-Proton-test-x86_64.sha512sum" "$WORK/sha.bak"
echo "0000  GE-Proton-test-x86_64.tar.gz" > "$SRV/GE-Proton-test-x86_64.sha512sum"
out="$(pc install)"; rc=$?
expect_status "checksum mismatch refused" 1 "$rc"
expect_text "mismatch message" "Checksum mismatch" "$out"
cp "$WORK/sha.bak" "$SRV/GE-Proton-test-x86_64.sha512sum"

mv "$SRV/GE-Proton-test-x86_64.sha512sum" "$WORK/sha.gone"
new_home
out="$(pc install)"; rc=$?
expect_status "missing checksum refused for published releases" 1 "$rc"
expect_text "missing checksum message" "Checksum unavailable" "$out"
mv "$WORK/sha.gone" "$SRV/GE-Proton-test-x86_64.sha512sum"

echo "== Diagnostics"

out="$(pc doctor)"; rc=$?
expect_status "doctor runs" 0 "$rc"
expect_text "doctor shows the default runtime" "Default" "$out"
expect_text "doctor shows the GitHub token state" "GITHUB_TOKEN" "$out"

out="$(pc help)"
expect_text "help lists reset and winetricks" "proton-cli reset" "$out"

echo "== install.sh"

INST_DIR="$WORK/bin"
mkdir -p "$INST_DIR"
cp "$PC" "$SRV/proton-cli"
(cd "$SRV" && sha256sum proton-cli > proton-cli.sha256)

out="$(PROTON_CLI_URL="$BASE_URL/proton-cli" PROTON_CLI_SHA_URL="$BASE_URL/proton-cli.sha256" \
    PROTON_CLI_INSTALL_DIR="$INST_DIR" sh "$INSTALLER" 2>&1)"; rc=$?
expect_status "installer installs a verified proton-cli" 0 "$rc"
[ -x "$INST_DIR/proton-cli" ] && pass "installed binary is executable" \
    || fail "installed binary is executable"

echo "tampered" >> "$SRV/proton-cli"
out="$(PROTON_CLI_URL="$BASE_URL/proton-cli" PROTON_CLI_SHA_URL="$BASE_URL/proton-cli.sha256" \
    PROTON_CLI_INSTALL_DIR="$WORK/bin2" sh "$INSTALLER" 2>&1)"; rc=$?
expect_status "installer refuses a tampered download" 1 "$rc"
expect_text "installer reports checksum mismatch" "Checksum mismatch" "$out"
cp "$PC" "$SRV/proton-cli"

echo ""
echo "Passed: $PASS   Failed: $FAIL"
[ "$FAIL" -eq 0 ]
