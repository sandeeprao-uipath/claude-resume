#!/bin/sh
# Remove claude-resume. Leaves your terminal's window-save-state setting alone.
set -eu

ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
SETTINGS="$HOME/.claude/settings.json"

if [ -f "$ZSHRC" ]; then
  tmp=$(mktemp)
  grep -v -e 'claude-resume.zsh' -e '(claude-resume)' "$ZSHRC" > "$tmp" || true
  mv "$tmp" "$ZSHRC"
  echo "  removed source line from $ZSHRC"
fi

if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq '
    if .hooks.SessionStart then
      .hooks.SessionStart |= map(.hooks |= map(select(.command | test("claude-resume-hook") | not)) | select(.hooks | length > 0))
      | if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end
      | if (.hooks | length) == 0 then del(.hooks) else . end
    else . end' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  echo "  removed SessionStart hook from $SETTINGS"
fi

rm -f "$HOME/.zsh/claude-resume.zsh" "$HOME/.zsh/claude-resume-hook.sh"
rm -f "$HOME/.claude/resume-markers/"* 2>/dev/null || true
rmdir "$HOME/.claude/resume-markers" 2>/dev/null || true
echo "Uninstalled. Open a new shell to drop the \`claude\` wrapper."
