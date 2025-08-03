#!/bin/bash
# Wrapper script to call autocomplete with proper pane targeting
/workspace/tmux-autocomplete.sh "$(tmux display-message -p '#{pane_id}')"