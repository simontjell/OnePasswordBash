#!/bin/bash
# Mock test to verify --raw flag behavior without requiring 1Password authentication

# Mock the op command
function op() {
    case "$1 $2" in
        "item list")
            echo '[{"id":"test-uuid-123","title":"GitHub Personal","fields":[{"id":"username","value":"testuser"}]}]'
            ;;
        "item get")
            if [ "$2" == "test-uuid-123" ] && [ "$3" == "--format" ] && [ "$4" == "json" ]; then
                echo '{"id":"test-uuid-123","title":"GitHub Personal","fields":[{"id":"password","value":"secret123"}]}'
            elif [ "$2" == "test-uuid-123" ] && [ "$3" == "--reveal" ] && [ "$4" == "--field" ] && [ "$5" == "password" ]; then
                echo "secret123"
            fi
            ;;
    esac
}

# Mock jq command (simplified for this test)
function jq() {
    if [ "$1" == "-c" ]; then
        # Simulate filtering
        echo '{"id":"test-uuid-123","title":"GitHub Personal","fields":[{"id":"username","value":"testuser"}]}'
    elif [ "$1" == "-r" ] && [ "$2" == ".id" ]; then
        echo "test-uuid-123"
    elif [ "$1" == "-r" ] && [[ "$2" == *"username"* ]]; then
        echo "testuser"
    fi
}

# Mock clipboard commands
function xclip() {
    echo "Mock: xclip called with: $@" >&2
}

function pbcopy() {
    echo "Mock: pbcopy called" >&2
}

# Source the main script
source opp.sh

echo "=== Testing --raw flag behavior ==="
echo
echo "Test 1: Single match with --raw flag (should only show JSON, no clipboard)"
opp github --raw
echo
echo "Test 2: Single match without --raw flag (should copy to clipboard)"
opp github
echo
