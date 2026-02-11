#!/usr/bin/env bash

# Advanced test runner for KirimLocal CLI
# Implements industry-standard testing practices

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$SCRIPT_DIR"
LIB_DIR="$TEST_DIR/lib"
FIXTURES_DIR="$TEST_DIR/fixtures"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
FAILED_TESTS_LIST=()

# Create the lib directory and assertion library
mkdir -p "$LIB_DIR"
cat > "$LIB_DIR/assert.bash" << 'EOF'
#!/usr/bin/env bash

# Basic assertion library for LocalSend CLI tests

assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Expected '$expected', got '$actual'}"
    
    if [[ "$expected" != "$actual" ]]; then
        echo -e "${RED}FAIL${NC}: $message"
        return 1
    else
        echo -e "${GREEN}PASS${NC}: Values match"
        return 0
    fi
}

assert_success() {
    local exit_code="${1:-$?}"
    local message="${2:-Command should succeed}"
    
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}FAIL${NC}: $message (exit code: $exit_code)"
        return 1
    else
        echo -e "${GREEN}PASS${NC}: Command succeeded"
        return 0
    fi
}

assert_failure() {
    local exit_code="${1:-$?}"
    local message="${2:-Command should fail}"
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${RED}FAIL${NC}: $message (exit code: $exit_code)"
        return 1
    else
        echo -e "${GREEN}PASS${NC}: Command failed as expected"
        return 0
    fi
}

assert_contains() {
    local string="$1"
    local substring="$2"
    local message="${3:-String should contain '$substring'}"
    
    if [[ "$string" != *"$substring"* ]]; then
        echo -e "${RED}FAIL${NC}: $message"
        return 1
    else
        echo -e "${GREEN}PASS${NC}: String contains '$substring'"
        return 0
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}FAIL${NC}: $message"
        return 1
    else
        echo -e "${GREEN}PASS${NC}: File exists: $file"
        return 0
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist: $file}"
    
    if [[ -f "$file" ]]; then
        echo -e "${RED}FAIL${NC}: $message"
        return 1
    else
        echo -e "${GREEN}PASS${NC}: File does not exist: $file"
        return 0
    fi
}
EOF

# Source the assertion library
source "$LIB_DIR/assert.bash"

# Create fixtures directory and sample files
mkdir -p "$FIXTURES_DIR"
echo "This is a test file for LocalSend CLI testing." > "$FIXTURES_DIR/sample.txt"
dd if=/dev/urandom of="$FIXTURES_DIR/sample.bin" bs=1024 count=1 2>/dev/null

# Function to run a single test
run_test() {
    local test_name="$1"
    local test_function="$2"
    local test_file="$3"
    
    echo -e "${BLUE}Running test:${NC} $test_name ($test_file)"
    
    # Capture output and exit code
    local output
    local exit_code
    
    if output=$(eval "$test_function" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ $exit_code -eq 0 ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo -e "${GREEN}✓ PASSED${NC}: $test_name"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TESTS_LIST+=("$test_name: $output")
        echo -e "${RED}✗ FAILED${NC}: $test_name"
        echo "   Error: $output"
    fi
    
    echo
}

# Test functions
test_syntax_check() {
    bash -n "$PROJECT_ROOT/kirimlocal.sh"
}

test_version_command() {
    local output
    output=$(bash "$PROJECT_ROOT/kirimlocal.sh" --version)
    if [[ "$output" == *"KirimLocal CLI v2.5"* ]]; then
        return 0
    else
        echo "Expected 'KirimLocal CLI v2.5', got '$output'"
        return 1
    fi
}

test_help_command() {
    local output
    output=$(bash "$PROJECT_ROOT/kirimlocal.sh" --help)
    if [[ "$output" != *"USAGE:"* ]] || [[ "$output" != *"OPTIONS:"* ]]; then
        echo "Help output missing required sections"
        return 1
    fi
    return 0
}

test_function_definitions() {
    # Check that key functions exist in the script
    local script_content
    script_content=$(cat "$PROJECT_ROOT/kirimlocal.sh")
    
    local required_functions=(
        "validate_ip"
        "human_size" 
        "generate_name"
        "validate_paths"
        "get_clipboard_cmd"
        "handle_listener_error"
        "check_port_availability"
        "share_clipboard"
    )
    
    for func in "${required_functions[@]}"; do
        if [[ "$script_content" != *"function $func"* ]] && [[ "$script_content" != *"$func()"* ]]; then
            echo "Function $func not found"
            return 1
        fi
    done
    
    return 0
}

test_strict_mode_enabled() {
    local script_content
    script_content=$(head -n 20 "$PROJECT_ROOT/kirimlocal.sh")
    
    if [[ "$script_content" != *"set -euo pipefail"* ]]; then
        echo "set -euo pipefail not found in first 20 lines"
        return 1
    fi
    
    return 0
}

test_clipboard_functions_exist() {
    local script_content
    script_content=$(cat "$PROJECT_ROOT/kirimlocal.sh")
    
    local clipboard_functions=(
        "get_clipboard_cmd"
        "get_clipboard_content"
        "set_clipboard_content"
        "share_clipboard"
        "receive_clipboard"
    )
    
    for func in "${clipboard_functions[@]}"; do
        if [[ "$script_content" != *"function $func"* ]] && [[ "$script_content" != *"$func()"* ]]; then
            echo "Clipboard function $func not found"
            return 1
        fi
    done
    
    return 0
}

test_menu_option_added() {
    local script_content
    script_content=$(cat "$PROJECT_ROOT/kirimlocal.sh")
    
    if [[ "$script_content" != *"Share Clipboard"* ]]; then
        echo "'Share Clipboard' option not found in menu"
        return 1
    fi
    
    if [[ "$script_content" != *"3)"* ]] || [[ "$script_content" != *"share_clipboard"* ]]; then
        echo "Option 3 for share_clipboard not found in menu"
        return 1
    fi
    
    return 0
}

# Main test execution
main() {
    echo -e "${YELLOW}Starting LocalSend CLI Advanced Test Suite${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    echo
    
    # Run all tests
    run_test "Syntax Check" "test_syntax_check" "syntax_test"
    run_test "Version Command" "test_version_command" "version_test"
    run_test "Help Command" "test_help_command" "help_test"
    run_test "Function Definitions" "test_function_definitions" "function_test"
    run_test "Strict Mode Enabled" "test_strict_mode_enabled" "strict_mode_test"
    run_test "Clipboard Functions Exist" "test_clipboard_functions_exist" "clipboard_test"
    run_test "Menu Option Added" "test_menu_option_added" "menu_test"
    
    # Print summary
    echo -e "${YELLOW}=========================================${NC}"
    echo -e "${YELLOW}Test Summary${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    echo "Total tests: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo
        echo -e "${RED}Failed tests:${NC}"
        for failure in "${FAILED_TESTS_LIST[@]}"; do
            echo "  - $failure"
        done
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

# Run main function if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF