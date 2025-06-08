#!/bin/bash
# OnePasswordBash: Find and copy passwords using 1Password CLI
# Usage: opp <search_term> [index]

function opp() {
    if ! command -v op &> /dev/null; then
        echo "Error: 1Password CLI (op) is not installed." >&2
        return 1
    fi
    if [ -z "$1" ]; then
        echo "Usage: opp <search_term> [index] [--raw|--reveal|--totp]" >&2
        return 1
    fi
    
    local search_term="$1"
    local index=""
    local raw_output=""
    local reveal_output=""
    local totp_output=""
    
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
            --totp)
                totp_output=1
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
    
    local items_json_raw
    items_json_raw=$(op item list --format json 2>&1)
    if echo "$items_json_raw" | grep -q 'You are not currently signed in'; then
        echo "You are not signed in to 1Password CLI (op). Starting signin..." >&2
        while true; do
            eval $(op signin)
            # Test if login succeeded
            items_json_raw=$(op item list --format json 2>&1)
            if ! echo "$items_json_raw" | grep -q 'You are not currently signed in'; then
                break
            fi
            echo "Signin failed. Please try again." >&2
        done
    fi
    if echo "$items_json_raw" | grep -q '^\[ERROR\]'; then
        echo "$items_json_raw" >&2
        return 1
    fi
    local items_json
    # Filter and sort by UUID to ensure consistent ordering
    items_json=$(echo "$items_json_raw" | jq -c "[.[] | select(.title | test(\"$search_term\"; \"i\"))] | sort_by(.id) | .[]")
    local op_status=${PIPESTATUS[0]}
    if [ $op_status -ne 0 ]; then
        echo "No items found or unable to access 1Password CLI (op)." >&2
        return 1
    fi
    
    local count
    count=$(echo "$items_json" | grep -c .)
    handle_single_result() {
        local uuid="$1"
        if [ -n "$raw_output" ]; then
            op item get "$uuid" --format json
            return $?
        fi
        if [ -n "$totp_output" ]; then
            local totp_value
            totp_value=$(op item get "$uuid" --format json | jq -r '.fields[] | select(.type == "OTP") | .totp')
            if [ -n "$totp_value" ] && [ "$totp_value" != "null" ]; then
                copy_to_clipboard "$totp_value" "TOTP code"
            else
                echo "No TOTP field found for this item." >&2
                return 1
            fi
            return 0
        fi
        local password
        password=$(get_password "$uuid")
        if [ -z "$password" ] || [ "$password" == "null" ]; then
            echo "No password field found for this item." >&2
            return 1
        fi
        if [ -n "$reveal_output" ]; then
            echo "$password"
        else
            copy_to_clipboard "$password"
        fi
    }
    if [ "$count" -eq 0 ]; then
        echo "No matches found for '$search_term'." >&2
        return 1
    elif [ "$count" -eq 1 ]; then
        local uuid
        uuid=$(echo "$items_json" | jq -r '.id')
        handle_single_result "$uuid"
    else
        if [ -z "$index" ]; then
            local i=1
            echo "$items_json" | while read -r item; do
                local title
                local username
                title=$(echo "$item" | jq -r '.title')
                username=$(echo "$item" | jq -r '.fields[]? | select(.id=="username" or .label=="username") | .value' | head -n1)
                if [ -n "$username" ]; then
                    echo "$i: $title (user: $username)"
                else
                    echo "$i: $title"
                fi
                i=$((i+1))
            done
            echo "Multiple matches found. Run: opp '$search_term' <index> [--raw|--reveal|--totp]"
            return 0
        else
            local uuid
            # Convert the newline-separated JSON objects to an array and get the item at index
            uuid=$(echo "$items_json" | jq -s -r ".[$((index-1))].id" 2>/dev/null)
            if [ -z "$uuid" ] || [ "$uuid" == "null" ]; then
                echo "Invalid index: $index" >&2
                return 1
            fi
            handle_single_result "$uuid"
        fi
    fi
}

get_password() {
    local uuid="$1"
    # Try different common password field names in order of preference
    local password
    password=$(op item get "$uuid" --reveal --field password 2>/dev/null)
    if [ -z "$password" ]; then
        password=$(op item get "$uuid" --reveal --field credential 2>/dev/null)
    fi
    if [ -z "$password" ]; then
        # Fallback: try to find any concealed field that might contain a password
        password=$(op item get "$uuid" --format json | jq -r '.fields[] | select(.type == "CONCEALED") | .value' | head -n1 2>/dev/null)
    fi
    # Return empty string if password is "null" from jq
    if [ "$password" == "null" ]; then
        password=""
    fi
    echo "$password"
}

copy_to_clipboard() {
    local content="$1"
    local content_type="${2:-Password}"
    if command -v xclip &> /dev/null; then
        echo -n "$content" | xclip -selection clipboard
        echo -n "$content" | xclip -selection primary
        echo "$content_type copied to clipboard (xclip)."
    elif command -v pbcopy &> /dev/null; then
        echo -n "$content" | pbcopy
        echo "$content_type copied to clipboard (pbcopy)."
    elif command -v clip.exe &> /dev/null; then
        echo -n "$content" | clip.exe
        echo "$content_type copied to clipboard (clip.exe)."
    else
        echo "No clipboard utility found (xclip, pbcopy, or clip.exe). Use --reveal to print the password in the terminal." >&2
        return 1
    fi
}

# Bash completion for opp command
_opp_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Available options
    opts="--raw --reveal --totp"
    
    # If current word starts with -, complete with flags
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
    
    # If previous word was opp and current doesn't start with -, don't complete
    # (let user type search term freely)
    if [[ ${prev} == "opp" ]] && [[ ${cur} != -* ]]; then
        return 0
    fi
    
    # For other positions, offer flags
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
}

# Register completion function
complete -F _opp_completion opp
