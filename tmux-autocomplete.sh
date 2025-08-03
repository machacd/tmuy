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
    
    # If this is a new word or different pane, reset cycling
    if [[ "$current_word" != "$original_word"* ]] || [[ "$pane_id" != "$last_pane" ]]; then
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
    
    # Save state
    echo "$original_word:$cycle_index:$pane_id" > "$STATE_FILE"
    
    # Calculate how many characters to delete (current word length)
    local chars_to_delete=${#current_word}
    
    # Send backspaces to delete current partial word, then type the new word
    for ((i=0; i<chars_to_delete; i++)); do
        tmux send-keys -t "$pane_id" "C-h"
    done
    
    tmux send-keys -t "$pane_id" "$selected_word"
}

# Main function
main() {
    local pane_id="${1:-$(tmux display-message -p '#{pane_id}')}"
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