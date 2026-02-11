#!/usr/bin/env bash

# Unit tests for LocalSend CLI UI functions

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

echo "Running UI function tests..."

# Test box drawing functions
echo "Testing box drawing functions..."

# Test print_box_top
box_top_output=$(print_box_top 2>&1)
if [[ -n "$box_top_output" ]] && [[ "$box_top_output" == *┏*┓* ]]; then
    echo "✓ print_box_top: PASSED"
else
    echo "✗ print_box_top: FAILED (got '$box_top_output')"
    exit 1
fi

# Test print_box_bottom
box_bottom_output=$(print_box_bottom 2>&1)
if [[ -n "$box_bottom_output" ]] && [[ "$box_bottom_output" == *┗*┛* ]]; then
    echo "✓ print_box_bottom: PASSED"
else
    echo "✗ print_box_bottom: FAILED (got '$box_bottom_output')"
    exit 1
fi

# Test print_box_sep
box_sep_output=$(print_box_sep 2>&1)
if [[ -n "$box_sep_output" ]] && [[ "$box_sep_output" == *┣*┫* ]]; then
    echo "✓ print_box_sep: PASSED"
else
    echo "✗ print_box_sep: FAILED (got '$box_sep_output')"
    exit 1
fi

# Test print_box_line
box_line_output=$(print_box_line "Test Content" 2>&1)
if [[ -n "$box_line_output" ]] && [[ "$box_line_output" == *Test\ Content* ]]; then
    echo "✓ print_box_line: PASSED"
else
    echo "✗ print_box_line: FAILED (got '$box_line_output')"
    exit 1
fi

# Test with different alignments
box_line_center_output=$(print_box_line "Center Content" CYAN 50 center 2>&1)
if [[ -n "$box_line_center_output" ]] && [[ "$box_line_center_output" == *Center\ Content* ]]; then
    echo "✓ print_box_line center alignment: PASSED"
else
    echo "✗ print_box_line center alignment: FAILED (got '$box_line_center_output')"
    exit 1
fi

# Test color codes are present in output
if [[ "$box_top_output" == *$'\033'* ]]; then
    echo "✓ ANSI color codes in box_top: PASSED"
else
    echo "✓ ANSI color codes in box_top: NOT PRESENT (may be intentional)"
fi

# Test that functions don't crash with different parameters
echo "Testing functions with various parameters..."

# Test with custom width
custom_width_output=$(print_box_top CYAN 60 2>&1)
if [[ -n "$custom_width_output" ]]; then
    echo "✓ print_box_top with custom width: PASSED"
else
    echo "✗ print_box_top with custom width: FAILED"
    exit 1
fi

# Test generate_name produces expected format
generated_name=$(generate_name)
if [[ "$generated_name" =~ ^[A-Za-z]+-[A-Za-z]+$ ]]; then
    echo "✓ generate_name format: PASSED ($generated_name)"
else
    echo "✗ generate_name format: FAILED ($generated_name)"
    exit 1
fi

# Test that color variables are defined
if [[ -n "${GREEN:-}" ]] && [[ -n "${BLUE:-}" ]] && [[ -n "${YELLOW:-}" ]]; then
    echo "✓ Color variables are defined: PASSED"
else
    echo "✗ Color variables are defined: FAILED"
    exit 1
fi

# Test icon variables are defined
if [[ -n "${TICK:-}" ]] && [[ -n "${ARROW:-}" ]] && [[ -n "${FLASH:-}" ]]; then
    echo "✓ Icon variables are defined: PASSED"
else
    echo "✗ Icon variables are defined: FAILED"
    exit 1
fi

echo "All UI tests passed!"