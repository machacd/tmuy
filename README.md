# Tmux Autocomplete

A bash script that provides word autocompletion in tmux, similar to Emacs Alt+/ functionality. It cycles through words found in all tmux panes.

## Setup

1. Clone this repository or download the scripts
2. Make the scripts executable:
   ```bash
   chmod +x tmux-autocomplete-wrapper.sh tmux-autocomplete-direct.sh
   ```

3. Add the following line to your `~/.tmux.conf`:
   ```bash
   bind-key M-/ run-shell '/path/to/your/tmux-autocomplete-wrapper.sh'
   ```
   
   Replace `/path/to/your/` with the actual path to the script. For example:
   ```bash
   bind-key M-/ run-shell '~/tmuy/tmux-autocomplete-wrapper.sh'
   ```

4. Reload your tmux configuration:
   ```bash
   tmux source-file ~/.tmux.conf
   ```

## Usage

1. Position your cursor at the end of a partial word
2. Press `Alt+/` to cycle through possible completions
3. Continue pressing `Alt+/` to cycle through all matching words found in all tmux panes

## How it works

The script:
- Captures the current word under cursor
- Searches all tmux panes for matching words
- Cycles through completions with each invocation
- Remembers the original word to cycle back to it