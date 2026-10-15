#!/bin/sh
# Claude Code SessionStart hook: record the current session id in the resume marker
# created by the zsh `claude` wrapper (~/.zsh/claude-resume.zsh). No-op otherwise.
[ -n "$CLAUDE_RESUME_MARKER" ] && [ -f "$CLAUDE_RESUME_MARKER" ] || exit 0
input=$(cat)
if command -v jq >/dev/null 2>&1; then
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
else
  sid=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi
[ -n "$sid" ] && echo "sid=$sid" >> "$CLAUDE_RESUME_MARKER"
exit 0
