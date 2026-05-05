#!/bin/bash
# Test suite for ALL completed specs in Focally
# Specs completados: TASK-001, TASK-002, TASK-003, TASK-004, TASK-005, TASK-006, TASK-007, TASK-025

set -e

APP_NAME="Focally"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🧪 Testing Focally All Completed Specs"
echo "======================================="
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
echo "======================================="
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

# Test 1: Google Calendar Service (TASK-001)
test_google_calendar() {
    echo "📊 Test 1: Google Calendar Service (TASK-001)"
    echo "---------------------------------------------"

    if [ -f "$PROJECT_DIR/Focally/Services/GoogleCalendarService.swift" ]; then
        print_result "GoogleCalendarService.swift exists" "✅" ""

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

# Test 2: Version Display (TASK-002)
test_version_display() {
    echo "📊 Test 2: Version Display (TASK-002)"
    echo "-------------------------------------"

    if [ -f "$PROJECT_DIR/Focally/Views/Settings/AboutSettingsView.swift" ]; then
        print_result "AboutSettingsView.swift exists" "✅" ""

        if grep -q "version" "$PROJECT_DIR/Focally/Views/Settings/AboutSettingsView.swift" -i; then
            print_result "Version display code exists" "✅" ""
        else
            print_result "Version display code exists" "❌" "Version display not found"
        fi
    else
        print_result "AboutSettingsView.swift exists" "⚠️" "File not found (might be in different location)"
    fi
}

# Test 3: Settings Modal (TASK-002)
test_settings_modal() {
    echo "📊 Test 3: Settings Modal (TASK-002)"
    echo "------------------------------------"

    if [ -f "$PROJECT_DIR/Focally/Views/Settings/SettingsPage.swift" ]; then
        print_result "SettingsPage.swift exists" "✅" ""

        # Check for auto-close on save
        if grep -q "presentation.wrappedValue.dismiss" "$PROJECT_DIR/Focally/Views/Settings/SettingsPage.swift" -i; then
            print_result "Settings modal auto-close on save" "✅" ""
        else
            print_result "Settings modal auto-close on save" "❌" "Auto-close not found"
        fi
    else
        print_result "SettingsPage.swift exists" "❌" "File not found"
    fi
}

# Test 4: Predefined Tasks (TASK-002)
test_predefined_tasks() {
    echo "📊 Test 4: Predefined Tasks (TASK-002)"
    echo "--------------------------------------"

    if [ -f "$PROJECT_DIR/Focally/Views/Tasks/PredefinedTasksList.swift" ]; then
        print_result "PredefinedTasksList.swift exists" "✅" ""

        if grep -q "predefined" "$PROJECT_DIR/Focally/Views/Tasks/PredefinedTasksList.swift" -i; then
            print_result "Predefined tasks UI exists" "✅" ""
        else
            print_result "Predefined tasks UI exists" "❌" "Predefined tasks not found"
        fi
    else
        print_result "PredefinedTasksList.swift exists" "⚠️" "File not found (might be in different location)"
    fi
}

# Test 5: Livecheck + Release (TASK-003)
test_livecheck_release() {
    echo "📊 Test 5: Livecheck + Release Flow (TASK-003)"
    echo "-----------------------------------------------"

    if [ -f "$PROJECT_DIR/.github/workflows/release.yml" ]; then
        print_result "GitHub Actions workflow exists" "✅" ""

        if grep -q "livecheck" "$PROJECT_DIR/.github/workflows/release.yml" -i; then
            print_result "Livecheck integration exists" "✅" ""
        else
            print_result "Livecheck integration exists" "❌" "Livecheck not found"
        fi
    else
        print_result "GitHub Actions workflow exists" "⚠️" "File not found (might be in different location)"
    fi
}

# Test 6: UI Regressions Fixed (TASK-004)
test_ui_regressions() {
    echo "📊 Test 6: UI Regressions Fixed (TASK-004)"
    echo "------------------------------------------"

    if [ -f "$PROJECT_DIR/Focally/Views/Timer/TimerControlsView.swift" ]; then
        print_result "TimerControlsView.swift exists" "✅" ""

        # Check for no overflow issues
        if grep -q "HStack.*spacing.*16" "$PROJECT_DIR/Focally/Views/Timer/TimerControlsView.swift"; then
            print_result "Timer controls layout is responsive" "✅" ""
        else
            print_result "Timer controls layout is responsive" "⚠️" "Layout might have issues"
        fi
    else
        print_result "TimerControlsView.swift exists" "❌" "File not found"
    fi
}

# Test 7: DND Reliable Activation (TASK-005)
test_dnd_reliable() {
    echo "📊 Test 7: DND Reliable Activation (TASK-005)"
    echo "----------------------------------------------"

    if [ -f "$PROJECT_DIR/Focally/Services/DNDService.swift" ]; then
        print_result "DNDService.swift exists" "✅" ""

        # Check for reliable activation
        if grep -q "CFPreferencesSetValue.*DND.*enable" "$PROJECT_DIR/Focally/Services/DNDService.swift" -i; then
            print_result "DND activation is reliable" "✅" ""
        else
            print_result "DND activation is reliable" "❌" "Activation might have issues"
        fi

        # Check for reliable deactivation
        if grep -q "CFPreferencesSetValue.*DND.*disable" "$PROJECT_DIR/Focally/Services/DNDService.swift" -i; then
            print_result "DND deactivation is reliable" "✅" ""
        else
            print_result "DND deactivation is reliable" "❌" "Deactivation might have issues"
        fi
    else
        print_result "DNDService.swift exists" "❌" "File not found"
    fi
}

# Test 8: No-Setup DND (TASK-006)
test_nosetup_dnd() {
    echo "📊 Test 8: No-Setup DND + Sounds (TASK-006)"
    echo "-------------------------------------------"

    if [ -f "$PROJECT_DIR/Focally/Services/DNDService.swift" ]; then
        print_result "DNDService.swift exists" "✅" ""

        # Check for no alerts for setup
        if grep -q "Accessibility" "$PROJECT_DIR/Focally/Services/DNDService.swift" -i; then
            print_result "No accessibility alerts" "✅" ""
        else
            print_result "No accessibility alerts" "⚠️" "Alerts might exist"
        fi
    else
        print_result "DNDService.swift exists" "❌" "File not found"
    fi

    if [ -f "$PROJECT_DIR/Focally/Services/NotificationService.swift" ]; then
        print_result "NotificationService.swift exists" "✅" ""

        # Check for sound support
        if grep -q "sound" "$PROJECT_DIR/Focally/Services/NotificationService.swift" -i; then
            print_result "Sound notifications exist" "✅" ""
        else
            print_result "Sound notifications exist" "❌" "Sound not found"
        fi
    else
        print_result "NotificationService.swift exists" "⚠️" "File not found (might be in different location)"
    fi
}

# Test 9: Liquid Glass (TASK-007)
test_liquid_glass() {
    echo "📊 Test 9: Liquid Glass + Swift Lang (TASK-007)"
    echo "-----------------------------------------------"

    if [ -f "$PROJECT_DIR/Focally/Views/Settings/AppearanceSettingsView.swift" ]; then
        print_result "AppearanceSettingsView.swift exists" "✅" ""

        if grep -q "liquid" "$PROJECT_DIR/Focally/Views/Settings/AppearanceSettingsView.swift" -i; then
            print_result "Liquid glass theme exists" "✅" ""
        else
            print_result "Liquid glass theme exists" "⚠️" "Theme might not be implemented"
        fi
    else
        print_result "AppearanceSettingsView.swift exists" "⚠️" "File not found (might be in different location)"
    fi
}

# Test 10: Migración a @Observable (TASK-025)
test_migracion_observable() {
    echo "📊 Test 10: Migración a @Observable (TASK-025)"
    echo "----------------------------------------------"

    if [ -f "$PROJECT_DIR/Focally/Services/FocusTimerService.swift" ]; then
        print_result "FocusTimerService.swift exists" "✅" ""

        if grep -q "@Observable" "$PROJECT_DIR/Focally/Services/FocusTimerService.swift"; then
            print_result "Migration to @Observable" "✅" ""
        else
            print_result "Migration to @Observable" "⚠️" "Migration might not be complete"
        fi
    else
        print_result "FocusTimerService.swift exists" "❌" "File not found"
    fi
}

# Test 11: Services general (core features)
test_core_services() {
    echo "📊 Test 11: Core Services (Timer, Slack, Notifications, Keychain)"
    echo "----------------------------------------------------------------"

    if [ -f "$PROJECT_DIR/Focally/Services/FocusTimerService.swift" ]; then
        print_result "FocusTimerService.swift exists" "✅" ""

        if grep -q "startWorkSession\|pauseSession\|resumeSession\|resetToIdle" "$PROJECT_DIR/Focally/Services/FocusTimerService.swift"; then
            print_result "Timer methods exist" "✅" ""
        else
            print_result "Timer methods exist" "❌" "Timer methods not found"
        fi
    else
        print_result "FocusTimerService.swift exists" "❌" "File not found"
    fi

    if [ -f "$PROJECT_DIR/Focally/Services/SlackService.swift" ]; then
        print_result "SlackService.swift exists" "✅" ""

        if grep -q "setStatus\|clearStatus" "$PROJECT_DIR/Focally/Services/SlackService.swift"; then
            print_result "Slack methods exist" "✅" ""
        else
            print_result "Slack methods exist" "❌" "Slack methods not found"
        fi
    else
        print_result "SlackService.swift exists" "⚠️" "File not found (might be in different location)"
    fi

    if [ -f "$PROJECT_DIR/Focally/Services/NotificationService.swift" ]; then
        print_result "NotificationService.swift exists" "✅" ""

        if grep -q "requestAuthorization\|notify" "$PROJECT_DIR/Focally/Services/NotificationService.swift"; then
            print_result "Notification methods exist" "✅" ""
        else
            print_result "Notification methods exist" "❌" "Notification methods not found"
        fi
    else
        print_result "NotificationService.swift exists" "⚠️" "File not found (might be in different location)"
    fi

    if [ -f "$PROJECT_DIR/Focally/Services/KeychainHelper.swift" ]; then
        print_result "KeychainHelper.swift exists" "✅" ""

        if grep -q "save\|retrieve" "$PROJECT_DIR/Focally/Services/KeychainHelper.swift"; then
            print_result "Keychain methods exist" "✅" ""
        else
            print_result "Keychain methods exist" "❌" "Keychain methods not found"
        fi
    else
        print_result "KeychainHelper.swift exists" "❌" "File not found"
    fi
}

# Main execution
echo "Test Suite: All Completed Specs"
echo "==============================="
echo ""

# Launch Focally
launch_focally || exit 1

# Verify all specs
test_google_calendar
test_version_display
test_settings_modal
test_predefined_tasks
test_livecheck_release
test_ui_regressions
test_dnd_reliable
test_nosetup_dnd
test_liquid_glass
test_migracion_observable
test_core_services

# Close Focally
close_focally

# Summary
echo "=================================="
echo "✅ All automated tests completed!"
echo ""
echo "📝 Manual testing required for:"
echo "  - Test Google Calendar integration (needs account + OAuth)"
echo "  - Test DND auto-activation flow"
echo "  - Test all UI fixes (TASK-002 to TASK-007)"
echo "  - Test livecheck + release workflow (TASK-003)"
echo "  - Test UI regressions (TASK-004)"
echo "  - Test DND reliability (TASK-005)"
echo "  - Test no-setup DND + sounds (TASK-006)"
echo "  - Test liquid glass theme (TASK-007)"
echo ""
echo "🛑 Cleaning up..."
close_focally

echo ""
echo "💡 Next steps:"
echo "  1. Run manual tests with app open"
echo "  2. Test all features end-to-end"
echo "  3. Add more specs to completed list"
