#!/bin/bash
#
# App Store Screenshot Capture Script
# Takes screenshots at the exact resolutions Apple requires.
#
# Usage:
#   ./capture.sh setup          — Boot simulators, install app, set clean status bar
#   ./capture.sh iphone <name>  — Capture iPhone screenshot (e.g. ./capture.sh iphone 01-blackout)
#   ./capture.sh ipad <name>    — Capture iPad screenshot
#   ./capture.sh watch <name>   — Capture Watch screenshot
#   ./capture.sh all <name>     — Capture all three at once
#   ./capture.sh teardown       — Shut down all simulators
#
# Workflow:
#   1. Run: ./capture.sh setup
#   2. The simulators open. Navigate to the screen you want on each.
#   3. Run: ./capture.sh iphone 01-blackout
#   4. Repeat for each screen (02-home, 03-progress, 04-settings, 05-notification)
#   5. Run: ./capture.sh teardown

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Simulator names (must match `xcrun simctl list devices`)
IPHONE="iPhone 17 Pro Max"
IPAD="iPad Pro 13-inch (M5)"
WATCH="Apple Watch Series 11 (46mm)"

# Output directories
IPHONE_DIR="$SCRIPT_DIR/iphone-6.9"
IPAD_DIR="$SCRIPT_DIR/ipad-13"
WATCH_DIR="$SCRIPT_DIR/watch-46mm"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[screenshot]${NC} $1"; }
warn() { echo -e "${YELLOW}[screenshot]${NC} $1"; }

# ─── SETUP ────────────────────────────────────────────────────────────────────

cmd_setup() {
    info "Booting simulators..."
    xcrun simctl boot "$IPHONE" 2>/dev/null || true
    xcrun simctl boot "$IPAD" 2>/dev/null || true
    # Watch requires a paired iPhone — boot it if paired, skip if not
    xcrun simctl boot "$WATCH" 2>/dev/null || warn "Watch simulator not booted (may need pairing)"

    info "Opening Simulator.app..."
    open -a Simulator

    # Wait for devices to finish booting
    sleep 3

    info "Setting clean status bar on iPhone..."
    xcrun simctl status_bar "$IPHONE" override \
        --time "9:41" \
        --batteryState charged \
        --batteryLevel 100 \
        --cellularMode active \
        --cellularBars 4 \
        --wifiBars 3 \
        --operatorName "" 2>/dev/null || warn "Status bar override not supported on this simulator"

    info "Setting clean status bar on iPad..."
    xcrun simctl status_bar "$IPAD" override \
        --time "9:41" \
        --batteryState charged \
        --batteryLevel 100 \
        --wifiBars 3 2>/dev/null || warn "Status bar override not supported on this simulator"

    info "Building and installing app on iPhone..."
    cd "$PROJECT_DIR/ios/Awareness"
    xcodebuild -project Awareness.xcodeproj -scheme Awareness \
        -destination "platform=iOS Simulator,name=$IPHONE" \
        build 2>&1 | tail -3

    # Find and install the built app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Awareness-*/Build/Products/Debug-iphonesimulator/Awareness.app -maxdepth 0 2>/dev/null | head -1)
    if [ -n "$APP_PATH" ]; then
        xcrun simctl install "$IPHONE" "$APP_PATH"
        xcrun simctl install "$IPAD" "$APP_PATH"
        info "App installed on iPhone and iPad simulators"
    else
        warn "Could not find built app — install manually from Xcode"
    fi

    # Install watch app if available
    WATCH_APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Awareness-*/Build/Products/Debug-watchsimulator/AwarenessWatch.app -maxdepth 0 2>/dev/null | head -1)
    if [ -n "$WATCH_APP_PATH" ]; then
        xcrun simctl install "$WATCH" "$WATCH_APP_PATH" 2>/dev/null || warn "Could not install watch app"
        info "Watch app installed"
    else
        warn "Watch app not found — build the AwarenessWatch scheme in Xcode first"
    fi

    echo ""
    info "Setup complete! Simulators are running."
    info "Navigate to the screen you want, then run:"
    echo "  ./capture.sh iphone 01-blackout"
    echo "  ./capture.sh ipad 01-blackout"
    echo "  ./capture.sh watch 01-main"
    echo "  ./capture.sh all 01-blackout"
    echo ""
    info "Recommended screenshot names:"
    echo "  01-blackout    — Blackout screen with 'Breathe.' text"
    echo "  02-home        — Main home / status screen"
    echo "  03-progress    — Progress donut chart + stats"
    echo "  04-settings    — Settings screen"
    echo "  05-notification — Notification on lock screen"
}

# ─── CAPTURE ──────────────────────────────────────────────────────────────────

capture_iphone() {
    local name="${1:?Usage: capture.sh iphone <name>}"
    local out="$IPHONE_DIR/${name}.png"
    xcrun simctl io "$IPHONE" screenshot "$out"
    info "iPhone saved: $out ($(sips -g pixelWidth -g pixelHeight "$out" 2>/dev/null | grep pixel | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//'))"
}

capture_ipad() {
    local name="${1:?Usage: capture.sh ipad <name>}"
    local out="$IPAD_DIR/${name}.png"
    xcrun simctl io "$IPAD" screenshot "$out"
    info "iPad saved: $out ($(sips -g pixelWidth -g pixelHeight "$out" 2>/dev/null | grep pixel | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//'))"
}

capture_watch() {
    local name="${1:?Usage: capture.sh watch <name>}"
    local out="$WATCH_DIR/${name}.png"
    xcrun simctl io "$WATCH" screenshot "$out"
    info "Watch saved: $out ($(sips -g pixelWidth -g pixelHeight "$out" 2>/dev/null | grep pixel | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//'))"
}

capture_all() {
    local name="${1:?Usage: capture.sh all <name>}"
    capture_iphone "$name"
    capture_ipad "$name"
    capture_watch "$name" 2>/dev/null || warn "Watch capture skipped (not booted?)"
}

# ─── TEARDOWN ─────────────────────────────────────────────────────────────────

cmd_teardown() {
    info "Shutting down simulators..."
    xcrun simctl shutdown "$IPHONE" 2>/dev/null || true
    xcrun simctl shutdown "$IPAD" 2>/dev/null || true
    xcrun simctl shutdown "$WATCH" 2>/dev/null || true
    info "All simulators shut down."
}

# ─── MAIN ─────────────────────────────────────────────────────────────────────

case "${1:-help}" in
    setup)    cmd_setup ;;
    iphone)   capture_iphone "${2:-}" ;;
    ipad)     capture_ipad "${2:-}" ;;
    watch)    capture_watch "${2:-}" ;;
    all)      capture_all "${2:-}" ;;
    teardown) cmd_teardown ;;
    *)
        echo "App Store Screenshot Capture"
        echo ""
        echo "Usage:"
        echo "  ./capture.sh setup          — Boot simulators, install app, set status bar"
        echo "  ./capture.sh iphone <name>  — Capture iPhone (6.9\" / 1320x2868)"
        echo "  ./capture.sh ipad <name>    — Capture iPad (13\" / 2064x2752)"
        echo "  ./capture.sh watch <name>   — Capture Watch (46mm / 416x496)"
        echo "  ./capture.sh all <name>     — Capture all three at once"
        echo "  ./capture.sh teardown       — Shut down simulators"
        ;;
esac
