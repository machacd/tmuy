#!/bin/bash

# tmux-autocomplete.sh - Word autocompletion for tmux similar to emacs Alt+/
# This script cycles through words found in all tmux panes

CACHE_DIR="/tmp/tmux-autocomplete"
STATE_FILE="$CACHE_DIR/state"
WORDS_FILE="$CACHE_DIR/words"

mkdir -p "$CACHE_DIR"

get_current_word() {
    local pane_id="${1:-$(tmux display-message -p '#{pane_id}')}"
    
    # Get cursor position and current line
    local cursor_x=$(tmux display-message -p -t "$pane_id" '#{cursor_x}')
    local cursor_y=$(tmux display-message -p -t "$pane_id" '#{cursor_y}')
    
    # Capture the specific line where cursor is
    local current_line=$(tmux capture-pane -t "$pane_id" -p | sed -n "$((cursor_y + 1))p")
    
    # Extract the partial word under cursor
    local before_cursor="${current_line:0:$cursor_x}"
    local word_start=$(echo "$before_cursor" | grep -oE '[a-zA-Z0-9_]+$' || echo "")
    
    echo "$word_start"
}

get_all_words() {
    local current_word="$1"
    local min_length="${#current_word}"
    
    # Capture content from all panes
    tmux list-panes -a -F '#{pane_id}' | while read -r pane; do
        tmux capture-pane -t "$pane" -p
    done | \
    # Extract words (alphanumeric + underscore)
    grep -oE '[a-zA-Z0-9_]{2,}' | \
    # Filter words that start with current partial word
    grep "^$current_word" | \
    # Remove duplicates and sort
    sort -u | \
    # Filter out the exact current word if it's complete
    grep -v "^$current_word$"
}

cycle_word() {
    local current_word="$1"
    local pane_id="${2:-$(tmux display-message -p '#{pane_id}')}"
    
    # Check if we're continuing a previous cycle
    local state_info=""
    if [[ -f "$STATE_FILE" ]]; then
        state_info=$(cat "$STATE_FILE")
    fi
    
    local original_word=$(echo "$state_info" | cut -d: -f1)
    local cycle_index=$(echo "$state_info" | cut -d: -f2)
    local last_pane=$(echo "$state_info" | cut -d: -f3)
    local last_completed=$(echo "$state_info" | cut -d: -f4)
    
    # Check if we should reset the cycle or continue
    local reset_cycle=false
    
    echo "=== CYCLE DEBUG ===" >> /tmp/cycle_debug.log
    echo "current_word='$current_word'" >> /tmp/cycle_debug.log
    echo "original_word='$original_word'" >> /tmp/cycle_debug.log
    echo "last_completed='$last_completed'" >> /tmp/cycle_debug.log
    echo "pane_id='$pane_id', last_pane='$last_pane'" >> /tmp/cycle_debug.log
    
    # Reset if different pane
    if [[ "$pane_id" != "$last_pane" ]]; then
        reset_cycle=true
        echo "RESET: Different pane" >> /tmp/cycle_debug.log
    # Reset if original word is empty (first time)
    elif [[ -z "$original_word" ]]; then
        reset_cycle=true
        echo "RESET: Empty original word (first time)" >> /tmp/cycle_debug.log
    # Continue cycle if current word matches the last completion exactly
    elif [[ "$current_word" == "$last_completed" ]]; then
        reset_cycle=false
        echo "CONTINUE: Current word matches last completion" >> /tmp/cycle_debug.log
    # Reset if current word is different from both original word and last completion
    else
        reset_cycle=true
        echo "RESET: Current word '$current_word' doesn't match original '$original_word' or last completion '$last_completed'" >> /tmp/cycle_debug.log
    fi
    
    echo "reset_cycle=$reset_cycle" >> /tmp/cycle_debug.log
    
    if [[ "$reset_cycle" == "true" ]]; then
        original_word="$current_word"
        cycle_index=0
        
        # Get fresh word list
        get_all_words "$original_word" > "$WORDS_FILE"
    fi
    
    # Read available completions
    local words=()
    while IFS= read -r word; do
        words+=("$word")
    done < "$WORDS_FILE"
    
    # If no completions found, do nothing
    if [[ ${#words[@]} -eq 0 ]]; then
        return
    fi
    
    # Get the next word in cycle
    local selected_word="${words[$cycle_index]}"
    
    # Update cycle index
    cycle_index=$(( (cycle_index + 1) % ${#words[@]} ))
    
    # Calculate how many characters to delete
    local chars_to_delete
    if [[ "$reset_cycle" == "false" && -n "$last_completed" ]]; then
        # When cycling, only delete the suffix that was added by the previous completion
        # Keep the original partial word (e.g., keep "r", delete "epeat" from "repeat")
        chars_to_delete=$((${#last_completed} - ${#original_word}))
        echo "CYCLING: Deleting $chars_to_delete chars (suffix of '$last_completed', keeping '$original_word')" >> /tmp/cycle_debug.log
    else
        # Starting new cycle, delete the original partial word to replace it entirely
        chars_to_delete=${#current_word}
        echo "NEW CYCLE: Deleting $chars_to_delete chars of '$current_word'" >> /tmp/cycle_debug.log
    fi
    
    # Send backspaces to delete current word, then type the new word
    for ((i=0; i<chars_to_delete; i++)); do
        tmux send-keys -t "$pane_id" "C-h"
    done
    
    # When cycling, only type the suffix of the new word (after the original partial word)
    # When starting new cycle, type the entire selected word
    if [[ "$reset_cycle" == "false" && -n "$original_word" ]]; then
        local suffix="${selected_word:${#original_word}}"
        echo "CYCLING: Typing suffix '$suffix' of '$selected_word'" >> /tmp/cycle_debug.log
        tmux send-keys -t "$pane_id" "$suffix"
    else
        echo "NEW CYCLE: Typing full word '$selected_word'" >> /tmp/cycle_debug.log
        tmux send-keys -t "$pane_id" "$selected_word"
    fi
    
    echo "FINAL STATE: '$original_word:$cycle_index:$pane_id:$selected_word'" >> /tmp/cycle_debug.log
    echo "===================" >> /tmp/cycle_debug.log
    
    # Save state with the completed word
    echo "$original_word:$cycle_index:$pane_id:$selected_word" > "$STATE_FILE"
}

# Main function
main() {
    local pane_target="$1"
    local pane_id
    
    # Convert pane target to actual pane ID
    if [[ -n "$pane_target" ]]; then
        pane_id=$(tmux display-message -p -t "$pane_target" '#{pane_id}')
    else
        pane_id=$(tmux display-message -p '#{pane_id}')
    fi
    
    local current_word=$(get_current_word "$pane_id")
    
    # If no partial word, do nothing
    if [[ -z "$current_word" ]]; then
        return
    fi
    
    cycle_word "$current_word" "$pane_id"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi