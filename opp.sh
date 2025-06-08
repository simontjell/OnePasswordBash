#!/bin/bash
# OnePasswordBash: Find and copy passwords using 1Password CLI
# Usage: opp <search_term> [index]

function opp() {
    if ! command -v op &> /dev/null; then
        echo "Error: 1Password CLI (op) is not installed." >&2
        return 1
    fi
    if [ -z "$1" ]; then
        echo "Usage: opp <search_term> [index]" >&2
        return 1
    fi
    local search_term="$1"
    local index="$2"
    local raw_output=""
    local reveal_output=""
    if [ "$3" == "--raw" ]; then
        raw_output=1
    elif [ "$3" == "--reveal" ]; then
        reveal_output=1
    fi
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
    # Filtrér tomme linjer fra items_json
    items_json=$(echo "$items_json_raw" | jq -c ".[] | select(.title | test(\"$search_term\"; \"i\"))" | grep -v '^$')
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
        local password
        password=$(get_password "$uuid")
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
            echo "Multiple matches found. Run: opp '$search_term' <index>"
            return 0
        else
            local uuid
            uuid=$(echo "$items_json" | sed -n "${index}p" | jq -r '.id')
            if [ -z "$uuid" ]; then
                echo "Invalid index: $index" >&2
                return 1
            fi
            handle_single_result "$uuid"
        fi
    fi
}

get_password() {
    local uuid="$1"
    op item get "$uuid" --reveal --field password
}

copy_to_clipboard() {
    local password="$1"
    if command -v xclip &> /dev/null; then
        echo -n "$password" | xclip -selection clipboard
        echo -n "$password" | xclip -selection primary
        echo "Password copied to clipboard (xclip)."
    elif command -v pbcopy &> /dev/null; then
        echo -n "$password" | pbcopy
        echo "Password copied to clipboard (pbcopy)."
    elif command -v clip.exe &> /dev/null; then
        echo -n "$password" | clip.exe
        echo "Password copied to clipboard (clip.exe)."
    else
        echo "No clipboard utility found (xclip, pbcopy, or clip.exe). Use --reveal to print the password in the terminal." >&2
        return 1
    fi
}
