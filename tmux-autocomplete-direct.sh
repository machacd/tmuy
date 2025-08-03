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

echo "DEBUG: cursor_x=$cursor_x, cursor_y=$cursor_y" >> /tmp/debug.log
echo "DEBUG: current_line='$current_line'" >> /tmp/debug.log
echo "DEBUG: before_cursor='$before_cursor'" >> /tmp/debug.log
echo "DEBUG: current_word='$current_word'" >> /tmp/debug.log

if [[ -z "$current_word" ]]; then
    echo "DEBUG: No current word found" >> /tmp/debug.log
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

# Reset if new word or pane
if [[ "$current_word" != "$original_word"* ]] || [[ "$pane_id" != "$last_pane" ]]; then
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
echo "$original_word:$cycle_index:$pane_id" > "$STATE_FILE"

# Delete current word and type new one
chars_to_delete=${#current_word}
for ((i=0; i<chars_to_delete; i++)); do
    tmux send-keys -t "$pane_id" "C-h"
done
tmux send-keys -t "$pane_id" "$selected_word"