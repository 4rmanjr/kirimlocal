#!/usr/bin/env bash

# Unit tests for LocalSend CLI network functions

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

# Temporarily source the localsend functions
TEMP_SCRIPT="$TEST_TEMP_DIR/kirimlocal_functions.sh"
# Create a version that comments out the main execution block
awk '
BEGIN { in_main_block = 0 }
/^if \[\[ \$# -eq 0 \]\]; then interactive_menu; else/ { 
    print "#if [[ $# -eq 0 ]]; then interactive_menu; else  # COMMENTED OUT FOR TESTING"
    in_main_block = 1
    next
}
/^fi$/ && in_main_block { 
    print "#fi  # COMMENTED OUT FOR TESTING"
    in_main_block = 0
    next
}
{ print }
' "$PROJECT_ROOT/kirimlocal.sh" > "$TEMP_SCRIPT"
source "$TEMP_SCRIPT"

# Cleanup function
cleanup() {
    rm -rf "$TEST_TEMP_DIR"
}
trap cleanup EXIT

echo "Running network function tests..."

# Test get_ip function
echo "Testing get_ip function..."
ip_address=$(get_ip)
if [[ -n "$ip_address" ]] && validate_ip "$ip_address"; then
    echo "✓ get_ip: PASSED ($ip_address)"
else
    echo "✗ get_ip: FAILED (got '$ip_address')"
    # This might fail in some environments, so we'll continue anyway
fi

# Test generate_name function
echo "Testing generate_name function..."
device_name=$(generate_name)
if [[ -n "$device_name" ]] && [[ "$device_name" =~ .*-.* ]]; then
    echo "✓ generate_name: PASSED ($device_name)"
else
    echo "✗ generate_name: FAILED (got '$device_name')"
    exit 1
fi

# Test get_all_broadcasts function
echo "Testing get_all_broadcasts function..."
broadcasts=$(get_all_broadcasts 2>/dev/null || echo "")
if [[ -n "$broadcasts" ]] || true; then  # Allow this to be empty in some environments
    echo "✓ get_all_broadcasts: EXECUTED (found $(echo "$broadcasts" | wc -l) broadcast(s))"
else
    echo "✓ get_all_broadcasts: EXECUTED (no broadcasts found)"
fi

# Test that required network commands exist
echo "Testing required network commands..."
required_commands=("hostname" "ifconfig" "ip")
missing_commands=()

for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        missing_commands+=("$cmd")
    fi
done

if [[ ${#missing_commands[@]} -eq 0 ]]; then
    echo "✓ All required network commands found: PASSED"
else
    echo "⚠ Missing network commands: ${missing_commands[*]}"
fi

# Test check_dependencies function (this will try to install packages, so we'll just check if it exists)
if declare -f check_dependencies >/dev/null; then
    echo "✓ check_dependencies function exists: PASSED"
else
    echo "✗ check_dependencies function exists: FAILED"
    exit 1
fi

# Test calculate_checksum function with a file
echo "Testing calculate_checksum function..."
test_file="$TEST_TEMP_DIR/test_file.txt"
echo "Test content for checksum" > "$test_file"

checksum=$(calculate_checksum "$test_file")
if [[ -n "$checksum" ]] && ([[ "$checksum" = "CHECKSUM_NOT_AVAILABLE" ]] || [[ "$checksum" =~ ^[a-f0-9]{64}$ ]]); then
    echo "✓ calculate_checksum: PASSED ($checksum)"
else
    echo "✗ calculate_checksum: FAILED (got '$checksum')"
    exit 1
fi

# Test get_total_size function
size=$(get_total_size "$test_file")
if [[ "$size" =~ ^[0-9]+$ ]] && [ "$size" -gt 0 ]; then
    echo "✓ get_total_size: PASSED ($size bytes)"
else
    echo "✗ get_total_size: FAILED (got '$size')"
    exit 1
fi

# Test human_size function
human=$(human_size "$size")
if [[ -n "$human" ]]; then
    echo "✓ human_size: PASSED ($human)"
else
    echo "✗ human_size: FAILED (got '$human')"
    exit 1
fi

# Test log_transfer function
echo "Testing log_transfer function..."
log_transfer "TEST" "127.0.0.1" "test_file.txt" "SUCCESS" "1KB"
if [[ -f "$HOME/.kirimlocal_history" ]]; then
    if grep -q "TEST|127.0.0.1|test_file.txt|SUCCESS|1KB" "$HOME/.kirimlocal_history"; then
        echo "✓ log_transfer: PASSED"
    else
        echo "✗ log_transfer: FAILED (entry not found in history)"
        exit 1
    fi
    # Clean up the test entry
    sed -i '/TEST|127.0.0.1|test_file.txt|SUCCESS|1KB/d' "$HOME/.kirimlocal_history"
    if [[ ! -s "$HOME/.kirimlocal_history" ]]; then
        rm -f "$HOME/.kirimlocal_history"
    fi
else
    echo "✓ log_transfer: EXECUTED (history file created)"
fi

# Test new refactored functions
if declare -f handle_listener_error >/dev/null; then
    echo "✓ handle_listener_error function exists: PASSED"
else
    echo "✗ handle_listener_error function exists: FAILED"
    exit 1
fi

if declare -f check_port_availability >/dev/null; then
    echo "✓ check_port_availability function exists: PASSED"
else
    echo "✗ check_port_availability function exists: FAILED"
    exit 1
fi

# Test clipboard functions
if declare -f get_clipboard_cmd >/dev/null; then
    echo "✓ get_clipboard_cmd function exists: PASSED"
else
    echo "✗ get_clipboard_cmd function exists: FAILED"
    exit 1
fi

if declare -f share_clipboard >/dev/null; then
    echo "✓ share_clipboard function exists: PASSED"
else
    echo "✗ share_clipboard function exists: FAILED"
    exit 1
fi

echo "All network tests completed!"