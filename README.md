# tmux-completion

A tmux plugin that provides emacs-style word completion with cycling functionality, similar to `Alt+/` in emacs.

## Features

- **Word completion**: Complete partial words by searching through all panes
- **Cycling**: Press the completion key multiple times to cycle through matches  
- **Scrollback support**: Option to search through entire scrollback history
- **Path component extraction**: Handles both full paths and individual components

## Installation

### Using TPM (Tmux Plugin Manager)

Add this line to your `~/.tmux.conf`:

```bash
set -g @plugin 'machacd/tmuy'
```

Then press `prefix + I` to install.

### Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/machacd/tmuy ~/.tmux/plugins/tmux-completion
   ```

2. Add this line to your `~/.tmux.conf`:
   ```bash
   run-shell ~/.tmux/plugins/tmux-completion/tmux-completion/tmux-completion.tmux
   ```

3. Reload tmux configuration:
   ```bash
   tmux source-file ~/.tmux.conf
   ```

## Usage

### Default Key Bindings

- **`prefix + /`** - Complete word using visible pane content
- **`prefix + ?`** - Complete word using entire scrollback history (larger word pool)
- **`Alt+/`** - Direct completion (no prefix needed)

### How It Works

1. Type a partial word (e.g., `test`)
2. Press the completion key (e.g., `prefix + /`)
3. The word completes to the first match (e.g., `testing_function`)
4. Press the completion key again to cycle to the next match (e.g., `test_variable`)
5. Continue cycling through all available matches

## Requirements

- tmux 2.0+
- bash
- Standard Unix utilities (grep, sed, awk)