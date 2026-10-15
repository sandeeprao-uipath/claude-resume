#!/bin/sh
# Install claude-resume: auto-resume Claude Code sessions after an OS restart.
# Safe to re-run. Backs up every file it edits to <file>.bak-claude-resume.
set -eu

SRC=$(cd "$(dirname "$0")" && pwd)
ZSH_DIR="$HOME/.zsh"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
SETTINGS="$HOME/.claude/settings.json"
HOOK_CMD="~/.zsh/claude-resume-hook.sh"

say() { printf '  %s\n' "$*"; }
backup() { [ -f "$1" ] && [ ! -f "$1.bak-claude-resume" ] && cp "$1" "$1.bak-claude-resume" || true; }

echo "Installing claude-resume…"

# 1. Scripts
mkdir -p "$ZSH_DIR"
cp "$SRC/claude-resume.zsh" "$ZSH_DIR/claude-resume.zsh"
cp "$SRC/claude-resume-hook.sh" "$ZSH_DIR/claude-resume-hook.sh"
chmod +x "$ZSH_DIR/claude-resume-hook.sh"
say "copied scripts to $ZSH_DIR"

# 2. Source from .zshrc (last, so it wraps whatever `claude` resolves to)
if ! grep -q 'claude-resume.zsh' "$ZSHRC" 2>/dev/null; then
  backup "$ZSHRC"
  printf '\n# Claude Code: auto-resume sessions after an OS restart (claude-resume)\n[ -f ~/.zsh/claude-resume.zsh ] && source ~/.zsh/claude-resume.zsh\n' >> "$ZSHRC"
  say "added source line to $ZSHRC"
else
  say "$ZSHRC already sources claude-resume.zsh"
fi

# 3. Claude Code SessionStart hook (records the live session id)
mkdir -p "$HOME/.claude"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
if grep -q 'claude-resume-hook.sh' "$SETTINGS"; then
  say "SessionStart hook already registered"
elif command -v jq >/dev/null 2>&1; then
  backup "$SETTINGS"
  tmp=$(mktemp)
  jq --arg cmd "$HOOK_CMD" '.hooks.SessionStart += [{"hooks":[{"type":"command","command":$cmd}]}]' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  say "registered SessionStart hook in $SETTINGS"
else
  say "jq not found — add this to $SETTINGS manually:"
  say '  "hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "~/.zsh/claude-resume-hook.sh"}]}]}'
fi

# 4. Ghostty: restore windows/tabs/cwd on relaunch (other terminals: see README)
for f in "$HOME/.config/ghostty/config" \
         "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty" \
         "$HOME/Library/Application Support/com.mitchellh.ghostty/config"; do
  [ -f "$f" ] && GHOSTTY_CFG="$f" && break
done
if [ -z "${GHOSTTY_CFG:-}" ] && { [ -d /Applications/Ghostty.app ] || command -v ghostty >/dev/null 2>&1; }; then
  GHOSTTY_CFG="$HOME/.config/ghostty/config"
  mkdir -p "$(dirname "$GHOSTTY_CFG")"; touch "$GHOSTTY_CFG"
fi
if [ -n "${GHOSTTY_CFG:-}" ]; then
  if grep -q '^ *window-save-state' "$GHOSTTY_CFG"; then
    say "Ghostty: window-save-state already set in $GHOSTTY_CFG (want: always)"
  else
    backup "$GHOSTTY_CFG"
    printf '# Restore windows, tabs, splits and their working directories (claude-resume)\nwindow-save-state = always\n' >> "$GHOSTTY_CFG"
    say "Ghostty: set window-save-state = always"
  fi
else
  say "Ghostty not found — make sure your terminal restores tabs + working directory (see README)"
fi

cat <<'EOF'

Done. Next:
  • Quit and reopen your terminal (Cmd+Q) — new `claude` sessions are tracked from now on.
  • macOS: add your terminal to System Settings → General → Login Items so it relaunches after a forced update.
  • `claude-restore` lists interrupted sessions; `export CLAUDE_AUTO_RESUME=0` disables auto-resume.
EOF
