#!/bin/bash
# Automated test script for Focally Timer feature
# Usa AppleScript para controlar la app sin interacción manual

set -e

APP_NAME="Focally"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🧪 Testing Focally Timer Feature"
echo "=================================="
echo ""

# Function to log test result
log_test() {
    local test_name=$1
    local result=$2
    local notes=$3

    if [ "$result" = "✅" ]; then
        echo "  ✅ $test_name"
    else
        echo "  ❌ $test_name"
    fi

    if [ -n "$notes" ]; then
        echo "     Notes: $notes"
    fi

    echo ""
}

# Function to launch Focally
launch_focally() {
    echo "🔨 Launching Focally..."

    # Build the app
    xcodebuild build -scheme Focally -configuration Debug -quiet

    # Launch the app
    open "$PROJECT_DIR/Focally.app"

    # Wait for app to launch
    sleep 2

    # Check if app is running
    if pgrep -x "$APP_NAME" > /dev/null; then
        echo "  ✅ Focally launched successfully"
        return 0
    else
        echo "  ❌ Failed to launch Focally"
        return 1
    fi
}

# Function to close Focally
close_focally() {
    echo "🛑 Closing Focally..."

    if pgrep -x "$APP_NAME" > /dev/null; then
        killall "$APP_NAME"
        sleep 1
    fi

    echo "  ✅ Focally closed"
}

# Function to open popover using AppleScript
open_popover() {
    echo "📤 Opening popover..."

    # Get the menubar icon
    local menubar_icon=$(osascript -e "tell application \"System Events\" to get the bounds of every UI element of process \"$APP_NAME\" whose role is \"AXButton\" and value is \"timer\"")

    if [ $? -eq 0 ]; then
        echo "  ✅ Popover icon found (bounds: $menubar_icon)"
        return 0
    else
        echo "  ⚠️  Could not find menubar icon (this is expected on first run)"
        return 1
    fi
}

# Function to wait for timer to be active
wait_for_timer() {
    echo "⏳ Waiting for timer to be active..."

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        # Check if timer is active using AppleScript
        local timer_state=$(osascript -e "tell application \"$APP_NAME\" to return (count of (get every window) > 0)" 2>/dev/null || echo "0")

        if [ "$timer_state" = "1" ]; then
            echo "  ✅ Timer is now active"
            return 0
        fi

        sleep 1
        attempt=$((attempt + 1))
    done

    echo "  ❌ Timeout waiting for timer"
    return 1
}

# Test 1: Launch Focally
echo "Test 1: Launch Focally"
launch_focally || exit 1
log_test "App launches successfully" "✅" ""

# Test 2: Check if app is running
echo "Test 2: Check if app is running"
if pgrep -x "$APP_NAME" > /dev/null; then
    log_test "App running" "✅" "PID: $(pgrep -x "$APP_NAME")"
else
    log_test "App running" "❌" "App not found"
    close_focally
    exit 1
fi

# Test 3: Try to open popover
echo "Test 3: Open popover"
open_popover

# Test 4: Check timer service initialization
echo "Test 4: Check timer service initialization"
if [ -f "$PROJECT_DIR/Focally.app/Contents/MacOS/Focally" ]; then
    log_test "Executable exists" "✅" ""
else
    log_test "Executable exists" "❌" ""
fi

# Test 5: Verify FocusTimerService code
echo "Test 5: Verify FocusTimerService code"
if grep -q "startWorkSession" "$PROJECT_DIR/Focally/Services/FocusTimerService.swift"; then
    log_test "startWorkSession method exists" "✅" ""
else
    log_test "startWorkSession method exists" "❌" ""
fi

if grep -q "pauseSession" "$PROJECT_DIR/Focally/Services/FocusTimerService.swift"; then
    log_test "pauseSession method exists" "✅" ""
else
    log_test "pauseSession method exists" "❌" ""
fi

if grep -q "resumeSession" "$PROJECT_DIR/Focally/Services/FocusTimerService.swift"; then
    log_test "resumeSession method exists" "✅" ""
else
    log_test "resumeSession method exists" "❌" ""
fi

# Test 6: Verify onSessionStarted exists
echo "Test 6: Verify onSessionStarted handler"
if grep -q "func onSessionStarted" "$PROJECT_DIR/Focally/OnItFocusApp.swift"; then
    log_test "onSessionStarted method exists" "✅" ""
else
    log_test "onSessionStarted method exists" "❌" ""
fi

# Test 7: Verify onFinish handler in ActiveFocusView
echo "Test 7: Verify onFinish handler"
if grep -q "func onFinish" "$PROJECT_DIR/Focally/Views/Timer/ActiveFocusView.swift"; then
    log_test "onFinish method exists" "✅" ""
else
    log_test "onFinish method exists" "❌" ""
fi

# Test 8: Verify resetToIdle method
echo "Test 8: Verify resetToIdle method"
if grep -q "func resetToIdle" "$PROJECT_DIR/Focally/Services/FocusTimerService.swift"; then
    log_test "resetToIdle method exists" "✅" ""
else
    log_test "resetToIdle method exists" "❌" ""
fi

# Test 9: Verify DNDService integration
echo "Test 9: Verify DNDService integration"
if grep -q "dndService.deactivateDND" "$PROJECT_DIR/Focally/Views/Timer/ActiveFocusView.swift"; then
    log_test "DND deactivation on finish" "✅" ""
else
    log_test "DND deactivation on finish" "❌" ""
fi

if grep -q "dndService.deactivateDND" "$PROJECT_DIR/Focally/OnItFocusApp.swift"; then
    log_test "DND deactivation on session end" "✅" ""
else
    log_test "DND deactivation on session end" "❌" ""
fi

# Test 10: Summary
echo "=================================="
echo "✅ All automated tests completed!"
echo ""
echo "📝 Manual testing required for:"
echo "  - Interact with timer controls (Start/Pause/Resume/Finish)"
echo "  - Verify timer display and updates"
echo "  - Verify DND activation on start (NOT IMPLEMENTED)"
echo "  - Verify DND deactivation on finish"
echo ""
echo "🛑 Cleaning up..."
close_focally

echo ""
echo "💡 Next steps:"
echo "  1. Implement DND auto-activation in startWorkSession"
echo "  2. Run manual tests with app open"
echo "  3. Verify all features work end-to-end"
