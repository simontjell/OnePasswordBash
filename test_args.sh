#!/bin/bash
# Test script to verify argument parsing works correctly

function test_opp_args() {
    local search_term="$1"
    local index=""
    local raw_output=""
    local reveal_output=""
    
    # Parse arguments
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --raw)
                raw_output=1
                ;;
            --reveal)
                reveal_output=1
                ;;
            *)
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    index="$1"
                else
                    echo "Error: Invalid argument '$1'" >&2
                    return 1
                fi
                ;;
        esac
        shift
    done
    
    echo "Search term: $search_term"
    echo "Index: ${index:-'not set'}"
    echo "Raw output: ${raw_output:-'not set'}"
    echo "Reveal output: ${reveal_output:-'not set'}"
}

echo "Test 1: opp github --raw"
test_opp_args github --raw
echo

echo "Test 2: opp github 2 --raw"
test_opp_args github 2 --raw
echo

echo "Test 3: opp github --reveal 2"
test_opp_args github --reveal 2
echo

echo "Test 4: opp github 3"
test_opp_args github 3
echo
