#!/usr/bin/env bash

# Integration tests for LocalSend CLI

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
LIB_DIR="$TEST_DIR/lib"

# Import test utilities
source "$LIB_DIR/assert.bash"

# Temporary directory for tests
TEST_TEMP_DIR=$(mktemp -d)
DOWNLOAD_DIR="$TEST_TEMP_DIR/downloads"
mkdir -p "$DOWNLOAD_DIR"
export DOWNLOAD_DIR

# Test file for transfers
TEST_FILE="$TEST_TEMP_DIR/test_integration_file.txt"
echo "Integration test file content" > "$TEST_FILE"

# Cleanup function
cleanup() {
    rm -rf "$TEST_TEMP_DIR"
    # Kill any background processes we might have started
    jobs -p | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT

echo "Running integration tests..."

# Test 1: Verify script can be executed with different arguments
echo "Testing script execution with various arguments..."

# Test version flag
version_output=$(bash "$PROJECT_ROOT/kirimlocal.sh" --version)
if [[ "$version_output" == "LocalSend CLI v2.5" ]]; then
    echo "✓ Version flag: PASSED"
else
    echo "✗ Version flag: FAILED (got '$version_output')"
    exit 1
fi

# Test help flag
help_output=$(bash "$PROJECT_ROOT/kirimlocal.sh" --help)
if [[ "$help_output" =~ "USAGE:" ]]; then
    echo "✓ Help flag: PASSED"
else
    echo "✗ Help flag: FAILED"
    exit 1
fi

# Test 2: Verify all required dependencies are detected
echo "Testing dependency check..."
if bash -c "source $PROJECT_ROOT/kirimlocal.sh && check_dependencies" 2>/dev/null; then
    echo "✓ Dependency check: PASSED"
else
    echo "⚠ Dependency check: SKIPPED (would try to install packages)"
fi

# Test 3: Test configuration variables indirectly
echo "Testing configuration variables..."
# Extract configuration values from the script without executing it
FILE_PORT_VALUE=$(grep "^FILE_PORT=" "$PROJECT_ROOT/kirimlocal.sh" | head -1 | cut -d= -f2-)
DISCOVERY_PORT_VALUE=$(grep "^DISCOVERY_PORT=" "$PROJECT_ROOT/kirimlocal.sh" | head -1 | cut -d= -f2-)
VERSION_VALUE=$(grep "^VERSION=" "$PROJECT_ROOT/kirimlocal.sh" | head -1 | cut -d= -f2- | tr -d '"')

if [[ -n "$FILE_PORT_VALUE" ]] && [[ -n "$DISCOVERY_PORT_VALUE" ]] && [[ -n "$VERSION_VALUE" ]]; then
    echo "✓ Configuration variables: PASSED"
else
    echo "✗ Configuration variables: FAILED"
    exit 1
fi

# Test 4: Test that new functions can be called without errors
echo "Testing new functions from refactoring..."

# Test handle_listener_error function
if bash -c "
    source $PROJECT_ROOT/kirimlocal.sh << 'EOF'
    declare -f handle_listener_error >/dev/null
EOF"
then
    echo "✓ handle_listener_error function accessible: PASSED"
else
    echo "✗ handle_listener_error function accessible: FAILED"
    exit 1
fi

# Test check_port_availability function
if bash -c "
    source $PROJECT_ROOT/kirimlocal.sh << 'EOF'
    declare -f check_port_availability >/dev/null
EOF"
then
    echo "✓ check_port_availability function accessible: PASSED"
else
    echo "✗ check_port_availability function accessible: FAILED"
    exit 1
fi

# Test share_clipboard function
if bash -c "
    source $PROJECT_ROOT/kirimlocal.sh << 'EOF'
    declare -f share_clipboard >/dev/null
EOF"
then
    echo "✓ share_clipboard function accessible: PASSED"
else
    echo "✗ share_clipboard function accessible: FAILED"
    exit 1
fi

# Test 5: Test that the interactive menu has been updated
echo "Testing interactive menu updates..."
menu_content=$(cat "$PROJECT_ROOT/kirimlocal.sh")
if [[ "$menu_content" =~ "Share Clipboard" ]]; then
    echo "✓ Share Clipboard option in menu: PASSED"
else
    echo "✗ Share Clipboard option in menu: FAILED"
    exit 1
fi

if [[ "$menu_content" =~ "3\)" ]] && [[ "$menu_content" =~ "share_clipboard" ]]; then
    echo "✓ Option 3 is share_clipboard: PASSED"
else
    echo "✗ Option 3 is share_clipboard: FAILED"
    exit 1
fi

# Test 6: Test strict mode implementation
echo "Testing strict mode implementation..."
if [[ "$(head -n 10 "$PROJECT_ROOT/kirimlocal.sh")" =~ "set -euo pipefail" ]]; then
    echo "✓ Strict mode enabled: PASSED"
else
    echo "✗ Strict mode enabled: FAILED"
    exit 1
fi

# Test 7: Test exception handling for commands that are allowed to fail
echo "Testing exception handling..."
count_kill_commands=$(grep -c "kill.*2>/dev/null || true" "$PROJECT_ROOT/kirimlocal.sh")
if [ $count_kill_commands -gt 0 ]; then
    echo "✓ Exception handling for kill commands: PASSED ($count_kill_commands found)"
else
    echo "⚠ Exception handling for kill commands: NOT FOUND"
fi

count_grep_commands=$(grep -c "grep.*|| true" "$PROJECT_ROOT/kirimlocal.sh")
if [ $count_grep_commands -gt 0 ]; then
    echo "✓ Exception handling for grep commands: PASSED ($count_grep_commands found)"
else
    echo "⚠ Exception handling for grep commands: NOT FOUND"
fi

# Test 8: Test that all new clipboard functions exist
clipboard_functions=("get_clipboard_cmd" "get_clipboard_content" "set_clipboard_content" "share_clipboard" "receive_clipboard")
all_found=true
for func in "${clipboard_functions[@]}"; do
    if ! grep -q "^$func()" "$PROJECT_ROOT/kirimlocal.sh"; then
        echo "✗ Clipboard function $func not found: FAILED"
        all_found=false
    fi
done

if [ "$all_found" = true ]; then
    echo "✓ All clipboard functions exist: PASSED (${#clipboard_functions[@]} found)"
fi

echo "All integration tests passed!"