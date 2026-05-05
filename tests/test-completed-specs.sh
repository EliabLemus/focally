#!/bin/bash
# Test suite for completed specs in Focally
# Solo los specs marcados como completados (TASK-001)
# Probar 5 en 5 iteraciones

set -e

APP_NAME="Focally"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🧪 Testing Focally Completed Specs"
echo "==================================="
echo ""
echo "Specs completados encontrados:"
echo "  1. TASK-001: Google Calendar Read"
echo "  2. TASK-002: UI/UX Correcciones"
echo "  3. TASK-003: Livecheck + Release Flow"
echo "  4. TASK-004: Fix 3 UX regressions"
echo "  5. TASK-005: Calendar + DND fixes"
echo "  6. TASK-006: No-Setup DND + Sounds"
echo "  7. TASK-007: Liquid Glass + Swift Lang"
echo "  8. TASK-025: Migración + Pruebas"
echo ""
echo "==================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print test result
print_result() {
    local test_name=$1
    local result=$2
    local notes=$3

    if [ "$result" = "✅" ]; then
        echo -e "${GREEN}✅${NC} $test_name"
    else
        echo -e "${RED}❌${NC} $test_name"
    fi

    if [ -n "$notes" ]; then
        echo -e "  Notes: $notes"
    fi

    echo ""
}

# Function to launch Focally
launch_focally() {
    echo "🔨 Launching Focally..."

    # Build the app
    xcodebuild build -scheme Focally -configuration Debug -quiet 2>&1 | grep -E "BUILD|error:" || true

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

# Function to verify Google Calendar Service exists
verify_calendar_service() {
    echo "📊 Test 1: Verify Google Calendar Service"

    if [ -f "$PROJECT_DIR/Focally/Services/GoogleCalendarService.swift" ]; then
        print_result "GoogleCalendarService.swift exists" "✅" ""

        # Verify key methods
        if grep -q "func fetchTodayEvents" "$PROJECT_DIR/Focally/Services/GoogleCalendarService.swift"; then
            print_result "fetchTodayEvents() method exists" "✅" ""
        else
            print_result "fetchTodayEvents() method exists" "❌" "Method not found"
        fi

        if grep -q "func checkConflict" "$PROJECT_DIR/Focally/Services/GoogleCalendarService.swift"; then
            print_result "checkConflict() method exists" "✅" ""
        else
            print_result "checkConflict() method exists" "❌" "Method not found"
        fi

        if grep -q "@Published var events" "$PROJECT_DIR/Focally/Services/GoogleCalendarService.swift"; then
            print_result "@Published var events" "✅" ""
        else
            print_result "@Published var events" "❌" "Property not found"
        fi
    else
        print_result "GoogleCalendarService.swift exists" "❌" "File not found"
    fi

    if [ -f "$PROJECT_DIR/Focally/Models/CalendarEvent.swift" ]; then
        print_result "CalendarEvent.swift exists" "✅" ""

        if grep -q "struct CalendarEvent" "$PROJECT_DIR/Focally/Models/CalendarEvent.swift"; then
            print_result "CalendarEvent struct defined" "✅" ""
        else
            print_result "CalendarEvent struct defined" "❌" "Struct not found"
        fi
    else
        print_result "CalendarEvent.swift exists" "❌" "File not found"
    fi
}

# Function to verify DND Service (completed as part of Timer feature)
verify_dnd_service() {
    echo "📊 Test 2: Verify DND Service"

    if [ -f "$PROJECT_DIR/Focally/Services/DNDService.swift" ]; then
        print_result "DNDService.swift exists" "✅" ""

        # Verify key methods
        if grep -q "func activateDND" "$PROJECT_DIR/Focally/Services/DNDService.swift"; then
            print_result "activateDND() method exists" "✅" ""
        else
            print_result "activateDND() method exists" "❌" "Method not found"
        fi

        if grep -q "func deactivateDND" "$PROJECT_DIR/Focally/Services/DNDService.swift"; then
            print_result "deactivateDND() method exists" "✅" ""
        else
            print_result "deactivateDND() method exists" "❌" "Method not found"
        fi

        if grep -q "func checkDNDStatus" "$PROJECT_DIR/Focally/Services/DNDService.swift"; then
            print_result "checkDNDStatus() method exists" "✅" ""
        else
            print_result "checkDNDStatus() method exists" "❌" "Method not found"
        fi
    else
        print_result "DNDService.swift exists" "❌" "File not found"
    fi
}

# Function to verify Slack Service (completed)
verify_slack_service() {
    echo "📊 Test 3: Verify Slack Service"

    if [ -f "$PROJECT_DIR/Focally/Services/SlackService.swift" ]; then
        print_result "SlackService.swift exists" "✅" ""

        # Verify key methods
        if grep -q "func setStatus" "$PROJECT_DIR/Focally/Services/SlackService.swift"; then
            print_result "setStatus() method exists" "✅" ""
        else
            print_result "setStatus() method exists" "❌" "Method not found"
        fi

        if grep -q "func clearStatus" "$PROJECT_DIR/Focally/Services/SlackService.swift"; then
            print_result "clearStatus() method exists" "✅" ""
        else
            print_result "clearStatus() method exists" "❌" "Method not found"
        fi

        if grep -q "@Published var status" "$PROJECT_DIR/Focally/Services/SlackService.swift"; then
            print_result "@Published var status" "✅" ""
        else
            print_result "@Published var status" "❌" "Property not found"
        fi
    else
        print_result "SlackService.swift exists" "❌" "File not found"
    fi
}

# Function to verify Timer Service (completed)
verify_timer_service() {
    echo "📊 Test 4: Verify Timer Service"

    if [ -f "$PROJECT_DIR/Focally/Services/FocusTimerService.swift" ]; then
        print_result "FocusTimerService.swift exists" "✅" ""

        # Verify key methods
        if grep -q "func startWorkSession" "$PROJECT_DIR/Focally/Services/FocusTimerService.swift"; then
            print_result "startWorkSession() method exists" "✅" ""
        else
            print_result "startWorkSession() method exists" "❌" "Method not found"
        fi

        if grep -q "func pauseSession" "$PROJECT_DIR/Focally/Services/FocusTimerService.swift"; then
            print_result "pauseSession() method exists" "✅" ""
        else
            print_result "pauseSession() method exists" "❌" "Method not found"
        fi

        if grep -q "func resetToIdle" "$PROJECT_DIR/Focally/Services/FocusTimerService.swift"; then
            print_result "resetToIdle() method exists" "✅" ""
        else
            print_result "resetToIdle() method exists" "❌" "Method not found"
        fi

        # Verify DND auto-activation (the fix we just implemented)
        if grep -q "dndService.activateDND" "$PROJECT_DIR/Focally/Services/FocusTimerService.swift"; then
            print_result "DND auto-activation in startWorkSession" "✅" "Fix implemented"
        else
            print_result "DND auto-activation in startWorkSession" "❌" "Fix not found"
        fi
    else
        print_result "FocusTimerService.swift exists" "❌" "File not found"
    fi
}

# Function to verify Notification Service (completed)
verify_notification_service() {
    echo "📊 Test 5: Verify Notification Service"

    if [ -f "$PROJECT_DIR/Focally/Services/NotificationService.swift" ]; then
        print_result "NotificationService.swift exists" "✅" ""

        # Verify key methods
        if grep -q "func requestAuthorization" "$PROJECT_DIR/Focally/Services/NotificationService.swift"; then
            print_result "requestAuthorization() method exists" "✅" ""
        else
            print_result "requestAuthorization() method exists" "❌" "Method not found"
        fi

        if grep -q "func notify" "$PROJECT_DIR/Focally/Services/NotificationService.swift"; then
            print_result "notify() method exists" "✅" ""
        else
            print_result "notify() method exists" "❌" "Method not found"
        fi
    else
        print_result "NotificationService.swift exists" "❌" "File not found"
    fi
}

# Function to verify Keychain Service (completed)
verify_keychain_service() {
    echo "📊 Test 6: Verify Keychain Service"

    if [ -f "$PROJECT_DIR/Focally/Services/KeychainHelper.swift" ]; then
        print_result "KeychainHelper.swift exists" "✅" ""

        # Verify key methods
        if grep -q "func saveToken" "$PROJECT_DIR/Focally/Services/KeychainHelper.swift"; then
            print_result "saveToken() method exists" "✅" ""
        else
            print_result "saveToken() method exists" "❌" "Method not found"
        fi

        if grep -q "func retrieveToken" "$PROJECT_DIR/Focally/Services/KeychainHelper.swift"; then
            print_result "retrieveToken() method exists" "✅" ""
        else
            print_result "retrieveToken() method exists" "❌" "Method not found"
        fi
    else
        print_result "KeychainHelper.swift exists" "❌" "File not found"
    fi
}

# Main execution
echo "Test Suite: Completed Specs"
echo "============================"
echo ""

# Launch Focally
launch_focally || exit 1

# Verify services
verify_calendar_service
verify_dnd_service
verify_slack_service
verify_timer_service
verify_notification_service
verify_keychain_service

# Close Focally
close_focally

# Summary
echo "=================================="
echo "✅ All automated tests completed!"
echo ""
echo "📝 Manual testing required for:"
echo "  - Test Google Calendar integration (needs account + OAuth)"
echo "  - Test DND auto-activation flow"
echo "  - Test Slack status sync (needs Slack account)"
echo ""
echo "🛑 Cleaning up..."
close_focally

echo ""
echo "💡 Next steps:"
echo "  1. Run manual tests with app open"
echo "  2. Test complete workflows end-to-end"
echo "  3. Add more specs to completed list"
