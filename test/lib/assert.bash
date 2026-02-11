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
