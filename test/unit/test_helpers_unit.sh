#!/usr/bin/env bash

# Unit tests for LocalSend CLI helper functions

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
export DOWNLOAD_DIR="$TEST_TEMP_DIR/downloads"
mkdir -p "$DOWNLOAD_DIR"

# Temporarily source the localsend functions
# We'll use a modified version that doesn't execute the main logic
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

echo "Running unit tests for helper functions..."

# Test validate_ip function
echo "Testing validate_ip function..."
if validate_ip "192.168.1.1"; then
    echo "✓ validate_ip with valid IP: PASSED"
else
    echo "✗ validate_ip with valid IP: FAILED"
    exit 1
fi

if ! validate_ip "999.999.999.999"; then
    echo "✓ validate_ip with invalid IP: PASSED"
else
    echo "✗ validate_ip with invalid IP: FAILED"
    exit 1
fi

if ! validate_ip "not.an.ip"; then
    echo "✓ validate_ip with non-IP string: PASSED"
else
    echo "✗ validate_ip with non-IP string: FAILED"
    exit 1
fi

# Test human_size function
echo "Testing human_size function..."
size_512=$(human_size 512)
if [[ "$size_512" == "512B" ]]; then
    echo "✓ human_size 512 bytes: PASSED ($size_512)"
else
    echo "✗ human_size 512 bytes: FAILED (got $size_512)"
    exit 1
fi

size_1024=$(human_size 1024)
if [[ "$size_1024" =~ ^[0-9.]+K$ ]]; then
    echo "✓ human_size 1024 bytes: PASSED ($size_1024)"
else
    echo "✗ human_size 1024 bytes: FAILED (got $size_1024)"
    exit 1
fi

size_1048576=$(human_size 1048576)
if [[ "$size_1048576" =~ ^[0-9.]+M$ ]]; then
    echo "✓ human_size 1MB: PASSED ($size_1048576)"
else
    echo "✗ human_size 1MB: FAILED (got $size_1048576)"
    exit 1
fi

# Test generate_name function
echo "Testing generate_name function..."
name=$(generate_name)
if [[ -n "$name" ]] && [[ "$name" =~ .*-.* ]]; then
    echo "✓ generate_name: PASSED ($name)"
else
    echo "✗ generate_name: FAILED (got $name)"
    exit 1
fi

# Test validate_paths function
echo "Testing validate_paths function..."
temp_file="$TEST_TEMP_DIR/test_file.txt"
touch "$temp_file"

if validate_paths "$temp_file"; then
    echo "✓ validate_paths with existing file: PASSED"
else
    echo "✗ validate_paths with existing file: FAILED"
    exit 1
fi

if ! validate_paths "/non/existing/file"; then
    echo "✓ validate_paths with non-existing file: PASSED"
else
    echo "✗ validate_paths with non-existing file: FAILED"
    exit 1
fi

# Test new clipboard functions if they exist
if declare -f get_clipboard_cmd >/dev/null; then
    clipboard_type=$(get_clipboard_cmd)
    echo "✓ get_clipboard_cmd: PASSED ($clipboard_type)"
else
    echo "✗ get_clipboard_cmd: FUNCTION NOT FOUND"
    exit 1
fi

if declare -f get_clipboard_content >/dev/null; then
    echo "✓ get_clipboard_content function exists: PASSED"
else
    echo "✗ get_clipboard_content function exists: FAILED"
    exit 1
fi

if declare -f set_clipboard_content >/dev/null; then
    echo "✓ set_clipboard_content function exists: PASSED"
else
    echo "✗ set_clipboard_content function exists: FAILED"
    exit 1
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

if declare -f share_clipboard >/dev/null; then
    echo "✓ share_clipboard function exists: PASSED"
else
    echo "✗ share_clipboard function exists: FAILED"
    exit 1
fi

echo "All unit tests passed!"