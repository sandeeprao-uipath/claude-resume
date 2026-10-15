# claude-resume

Chrome-style "restore session" for [Claude Code](https://claude.com/claude-code) in zsh.

Corporate Macs auto-install OS updates and force a restart. That kills every running
`claude` session. With claude-resume, when your terminal reopens its tabs after the
restart, each tab that was running Claude resumes **the exact conversation** it had:

```
↻ Resuming Claude session 3f9c2a1b… (any key within 2s to skip)
```

## Install

```sh
git clone https://github.com/sandeeprao-uipath/claude-resume.git ~/projects/claude-resume
~/projects/claude-resume/install.sh
```

Then quit and reopen your terminal (Cmd+Q). Sessions started from then on are tracked.

The installer is safe to re-run and backs up each file it edits to `*.bak-claude-resume`:

| What | Change |
|---|---|
| `~/.zsh/claude-resume.zsh`, `~/.zsh/claude-resume-hook.sh` | copied in |
| `~/.zshrc` | one `source` line appended |
| `~/.claude/settings.json` | one `SessionStart` hook added (needs `jq`; ships with macOS 15+) |
| Ghostty config | `window-save-state = always`, if not already set |

**Also do this on macOS:** System Settings → General → Login Items → add your terminal.
Forced update restarts don't always relaunch apps.

Uninstall: `~/projects/claude-resume/uninstall.sh`

## Usage

There's nothing to learn. Keep running `claude` as usual.

| Command | What it does |
|---|---|
| `claude-restore` | List interrupted sessions from any folder and pick one to resume |
| `export CLAUDE_AUTO_RESUME=0` | Turn off auto-resume (`claude-restore` keeps working) |
| `CLAUDE_RESUME_MAX_AGE_DAYS` | Forget interrupted sessions older than this (default 7) |

## How it works

1. **Wrapper.** A zsh `claude` function writes a small marker file to
   `~/.claude/resume-markers/` while an interactive session runs. A clean exit
   deletes the marker. `-p`, `--version`, `mcp`, `config` and similar commands
   pass straight through without a marker.
2. **Hook.** A `SessionStart` hook writes the live session ID into that marker.
   The ID stays correct after `/clear` or `/resume` inside Claude.
3. **Restart vs. closed tab.** A marker last written *before the current boot* is a
   session that was running when the machine went down, so it gets resumed. A
   marker from *this* boot whose shell has exited is a tab you closed on purpose,
   so it gets deleted.
4. **Resume.** The terminal restores each tab in its old folder. On its first
   prompt, the shell claims one interrupted marker for `$PWD` (an atomic `mv`,
   so two tabs in the same folder never take the same session) and runs
   `claude --resume <id>`.

### Terminals

The resume logic is in zsh, so it works in any terminal that **restores tabs and
their working directories** on relaunch:

- **Ghostty:** `window-save-state = always` (the installer sets it)
- **iTerm2:** Settings → General → Startup → "Use System Window Restoration Setting".
  Also turn off System Settings → Desktop & Dock → "Close windows when quitting an application".
- **Terminal.app:** works by default with "Reopen windows when logging back in"

If your terminal doesn't restore tabs, open one and run `claude-restore`.

## Limitations

- zsh only (macOS and Linux). No bash or fish yet.
- Only sessions started through the wrapper are tracked. A `claude` that was already
  running when you installed is not.
- Resuming restores the conversation, not processes Claude had started (dev servers,
  background shells).

## Similar tools

| Tool | Approach | Trade-off vs. this |
|---|---|---|
| [cc-session-restore](https://github.com/asadtariq96/cc-session-restore) | Snapshots open sessions every 60s, reopens them in iTerm2 | iTerm2 only; reads Claude's internal session files |
| [claude-afterlife](https://github.com/balintb/claude-afterlife) | cron snapshot every minute; `restore` opens one tab per session | Manual restore step; needs cron |
| [claude-session-restore](https://github.com/Supersynergy/claude-session-restore) | One command reopens every session; supports many terminals | Manual command rather than in-place tab restore |
| [claude-revive](https://github.com/coezbek/claude-revive) | Hooks + reopens sessions in VS Code terminals | VS Code only |
| [session-restore](https://github.com/themidnightgospel/session-restore) | Claude Code plugin, `/session-restore:restore` | Windows Terminal only |
| tmux-resurrect / Zellij | Restore panes and layout | Doesn't re-attach Claude; you still run `claude -c` per pane, and `-c` can't tell apart multiple sessions in one folder |

The difference here: no polling and no background daemon, it doesn't read Claude's
private files (it uses a public hook), it resumes in the same tab the terminal
already restored, and a deliberately closed tab never comes back.
