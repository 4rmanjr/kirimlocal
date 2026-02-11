#!/usr/bin/env bash

# Unit tests for LocalSend CLI validation functions

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

echo "Running validation function tests..."

# Test validate_ip with various inputs
echo "Testing validate_ip with various inputs..."

# Valid IPs
valid_ips=("127.0.0.1" "192.168.1.1" "10.0.0.1" "255.255.255.255" "0.0.0.0")
for ip in "${valid_ips[@]}"; do
    if validate_ip "$ip"; then
        echo "✓ validate_ip with valid IP $ip: PASSED"
    else
        echo "✗ validate_ip with valid IP $ip: FAILED"
        exit 1
    fi
done

# Invalid IPs
invalid_ips=("256.1.1.1" "1.1.1.256" "192.168.1" "192.168.1.1.1" "not.an.ip" "" "-1.1.1.1" "1.-1.1.1")
for ip in "${invalid_ips[@]}"; do
    if ! validate_ip "$ip"; then
        echo "✓ validate_ip with invalid IP '$ip': PASSED"
    else
        echo "✗ validate_ip with invalid IP '$ip': FAILED"
        exit 1
    fi
done

# Test validate_paths with various inputs
echo "Testing validate_paths with various inputs..."

# Create test files and directories
test_file="$TEST_TEMP_DIR/test_file.txt"
test_dir="$TEST_TEMP_DIR/test_dir"
mkdir -p "$test_dir"
touch "$test_file"

# Valid paths
if validate_paths "$test_file"; then
    echo "✓ validate_paths with existing file: PASSED"
else
    echo "✗ validate_paths with existing file: FAILED"
    exit 1
fi

if validate_paths "$test_dir"; then
    echo "✓ validate_paths with existing directory: PASSED"
else
    echo "✗ validate_paths with existing directory: FAILED"
    exit 1
fi

if validate_paths "$test_file" "$test_dir"; then
    echo "✓ validate_paths with multiple existing paths: PASSED"
else
    echo "✗ validate_paths with multiple existing paths: FAILED"
    exit 1
fi

# Invalid paths
if ! validate_paths "/non/existing/file"; then
    echo "✓ validate_paths with non-existing file: PASSED"
else
    echo "✗ validate_paths with non-existing file: FAILED"
    exit 1
fi

if ! validate_paths "$test_file" "/non/existing/file"; then
    echo "✓ validate_paths with mix of valid and invalid paths: PASSED"
else
    echo "✗ validate_paths with mix of valid and invalid paths: FAILED"
    exit 1
fi

# Test calculate_checksum function
echo "Testing calculate_checksum function..."

# Create a test file with known content
echo "This is a test file for checksum calculation." > "$TEST_TEMP_DIR/checksum_test.txt"

checksum=$(calculate_checksum "$TEST_TEMP_DIR/checksum_test.txt")
if [[ -n "$checksum" ]] && ([[ "$checksum" = "CHECKSUM_NOT_AVAILABLE" ]] || [[ "$checksum" =~ ^[a-f0-9]{64}$ ]]); then
    echo "✓ calculate_checksum: PASSED ($checksum)"
else
    echo "✗ calculate_checksum: FAILED (got $checksum)"
    exit 1
fi

# Test get_total_size function
echo "Testing get_total_size function..."

size=$(get_total_size "$TEST_TEMP_DIR/checksum_test.txt")
if [[ "$size" =~ ^[0-9]+$ ]] && [ "$size" -gt 0 ]; then
    echo "✓ get_total_size: PASSED ($size bytes)"
else
    echo "✗ get_total_size: FAILED (got $size)"
    exit 1
fi

# Test human_size function with edge cases
echo "Testing human_size function with edge cases..."

# Test boundary values
size_1023=$(human_size 1023)
if [[ "$size_1023" = "1023B" ]]; then
    echo "✓ human_size 1023 bytes: PASSED ($size_1023)"
else
    echo "✗ human_size 1023 bytes: FAILED (got $size_1023)"
    exit 1
fi

size_1024=$(human_size 1024)
if [[ "$size_1024" =~ ^[0-9.]+K$ ]]; then
    echo "✓ human_size 1024 bytes: PASSED ($size_1024)"
else
    echo "✗ human_size 1024 bytes: FAILED (got $size_1024)"
    exit 1
fi

size_1048575=$(human_size 1048575)
if [[ "$size_1048575" =~ ^[0-9.]+K$ ]]; then
    echo "✓ human_size 1048575 bytes: PASSED ($size_1048575)"
else
    echo "✗ human_size 1048575 bytes: FAILED (got $size_1048575)"
    exit 1
fi

size_1048576=$(human_size 1048576)
if [[ "$size_1048576" =~ ^[0-9.]+M$ ]]; then
    echo "✓ human_size 1048576 bytes: PASSED ($size_1048576)"
else
    echo "✗ human_size 1048576 bytes: FAILED (got $size_1048576)"
    exit 1
fi

size_1073741823=$(human_size 1073741823)
if [[ "$size_1073741823" =~ ^[0-9.]+M$ ]]; then
    echo "✓ human_size 1073741823 bytes: PASSED ($size_1073741823)"
else
    echo "✗ human_size 1073741823 bytes: FAILED (got $size_1073741823)"
    exit 1
fi

size_1073741824=$(human_size 1073741824)
if [[ "$size_1073741824" =~ ^[0-9.]+G$ ]]; then
    echo "✓ human_size 1073741824 bytes: PASSED ($size_1073741824)"
else
    echo "✗ human_size 1073741824 bytes: FAILED (got $size_1073741824)"
    exit 1
fi

echo "All validation tests passed!"