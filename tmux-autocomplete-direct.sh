#!/bin/bash

# Direct tmux command that executes in the target pane
CACHE_DIR="/tmp/tmux-autocomplete"
STATE_FILE="$CACHE_DIR/state"
WORDS_FILE="$CACHE_DIR/words"

mkdir -p "$CACHE_DIR"

pane_id="$(tmux display-message -p '#{pane_id}')"
cursor_x=$(tmux display-message -p -t "$pane_id" '#{cursor_x}')
cursor_y=$(tmux display-message -p -t "$pane_id" '#{cursor_y}')

# Get current line and extract word
current_line=$(tmux capture-pane -t "$pane_id" -p | sed -n "$((cursor_y + 1))p")
before_cursor="${current_line:0:$cursor_x}"
current_word=$(echo "$before_cursor" | grep -oE '[a-zA-Z0-9_]+$' || echo "")

if [[ -z "$current_word" ]]; then
    exit 0
fi

# Get all words from all panes
tmux list-panes -a -F '#{pane_id}' | while read -r pane; do
    tmux capture-pane -t "$pane" -p
done | grep -oE '[a-zA-Z0-9_]{2,}' | grep "^$current_word" | sort -u | grep -v "^$current_word$" > "$WORDS_FILE"

# Check cycling state
state_info=""
if [[ -f "$STATE_FILE" ]]; then
    state_info=$(cat "$STATE_FILE")
fi

original_word=$(echo "$state_info" | cut -d: -f1)
cycle_index=$(echo "$state_info" | cut -d: -f2)
last_pane=$(echo "$state_info" | cut -d: -f3)
last_completed=$(echo "$state_info" | cut -d: -f4)

# Check if we should reset the cycle or continue
reset_cycle=false

# Reset if different pane
if [[ "$pane_id" != "$last_pane" ]]; then
    reset_cycle=true
# Reset if current word doesn't match original word and isn't a completion
elif [[ "$current_word" != "$original_word"* ]] && [[ "$current_word" != "$last_completed" ]]; then
    reset_cycle=true
# Continue cycle if current word matches the last completion
elif [[ "$current_word" == "$last_completed" ]]; then
    reset_cycle=false
# Reset if original word is empty (first time)
elif [[ -z "$original_word" ]]; then
    reset_cycle=true
fi

if [[ "$reset_cycle" == "true" ]]; then
    original_word="$current_word"
    cycle_index=0
fi

# Read words
words=()
while IFS= read -r word; do
    words+=("$word")
done < "$WORDS_FILE"

if [[ ${#words[@]} -eq 0 ]]; then
    exit 0
fi

# Get next completion
selected_word="${words[$cycle_index]}"
cycle_index=$(( (cycle_index + 1) % ${#words[@]} ))

# Save state
echo "$original_word:$cycle_index:$pane_id:$selected_word" > "$STATE_FILE"

# Delete current word and type new one
chars_to_delete=${#current_word}
for ((i=0; i<chars_to_delete; i++)); do
    tmux send-keys -t "$pane_id" "C-h"
done
tmux send-keys -t "$pane_id" "$selected_word"