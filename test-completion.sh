#!/bin/bash
echo "=== DEBUG TEST ===" > /tmp/test_debug.log

pane_id="$(tmux display-message -p '#{pane_id}')"
cursor_x=$(tmux display-message -p -t "$pane_id" '#{cursor_x}')
cursor_y=$(tmux display-message -p -t "$pane_id" '#{cursor_y}')

echo "pane_id: $pane_id" >> /tmp/test_debug.log
echo "cursor: $cursor_x,$cursor_y" >> /tmp/test_debug.log

current_line=$(tmux capture-pane -t "$pane_id" -p | sed -n "$((cursor_y + 1))p")
before_cursor="${current_line:0:$cursor_x}"
current_word=$(echo "$before_cursor" | grep -oE '[a-zA-Z0-9_/.-]+$' || echo "")

echo "current_line: '$current_line'" >> /tmp/test_debug.log
echo "before_cursor: '$before_cursor'" >> /tmp/test_debug.log
echo "current_word: '$current_word'" >> /tmp/test_debug.log

# Simple word extraction test
tmux list-panes -a -F '#{pane_id}' | while read -r pane; do
    tmux capture-pane -t "$pane" -p
done > /tmp/all_content.txt

echo "=== ALL CONTENT ===" >> /tmp/test_debug.log
cat /tmp/all_content.txt >> /tmp/test_debug.log

grep -oE '[a-zA-Z0-9_/.-]{2,}' /tmp/all_content.txt | grep "^a" | sort -u > /tmp/test_words.txt
echo "=== WORDS FOR 'a' ===" >> /tmp/test_debug.log
cat /tmp/test_words.txt >> /tmp/test_debug.log