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
    if [ "$3" == "--raw" ]; then
        raw_output=1
    fi
    local items_json
    # Filtrér tomme linjer fra items_json
    items_json=$(op item list --format json 2>&1 | jq -c ".[] | select(.title | test(\"$search_term\"; \"i\"))" | grep -v '^$')
    local op_status=$?
    if echo "$items_json" | grep -q 'You are not currently signed in'; then
        echo "Error: You are not signed in to 1Password CLI (op). Please run: op signin" >&2
        return 1
    fi
    if [ $op_status -ne 0 ]; then
        echo "No items found or unable to access 1Password CLI (op)." >&2
        return 1
    fi
    local count
    count=$(echo "$items_json" | grep -c .)
    if [ "$count" -eq 0 ]; then
        echo "No matches found for '$search_term'." >&2
        return 1
    elif [ "$count" -eq 1 ]; then
        local uuid
        uuid=$(echo "$items_json" | jq -r '.id')
        if [ -n "$raw_output" ]; then
            op item get "$uuid" --format json
            return $?
        fi
        local password
        password=$(op item get "$uuid" --field password)
        if command -v xclip &> /dev/null; then
            echo -n "$password" | xclip -selection clipboard
            echo "Password copied to clipboard."
        elif command -v pbcopy &> /dev/null; then
            echo -n "$password" | pbcopy
            echo "Password copied to clipboard."
        else
            echo "$password"
        fi
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
            if [ -n "$raw_output" ]; then
                op item get "$uuid" --format json
                return $?
            fi
            local password
            password=$(op item get "$uuid" --field password)
            if command -v xclip &> /dev/null; then
                echo -n "$password" | xclip -selection clipboard
                echo "Password copied to clipboard."
            elif command -v pbcopy &> /dev/null; then
                echo -n "$password" | pbcopy
                echo "Password copied to clipboard."
            else
                echo "$password"
            fi
        fi
    fi
}
