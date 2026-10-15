# claude-resume.zsh — bring Claude Code sessions back after a forced OS restart.
# Installed to ~/.zsh/claude-resume.zsh by install.sh.
#
# How it works:
#   * `claude` is wrapped: each interactive session leaves a marker in $CLAUDE_RESUME_DIR
#     while it runs (cwd + session id; the id is written by a SessionStart hook so it
#     stays correct across /clear and /resume). A clean exit removes the marker.
#   * A marker older than the current boot = the session was alive when the Mac restarted.
#   * When Ghostty restores a tab (window-save-state = always restores the cwd), the new
#     shell claims a leftover marker for that cwd and runs `claude --resume <id>`.
#   * Markers from this boot whose shell is gone = tab closed on purpose -> discarded.
#
# Commands: claude-restore (list/resume leftovers anywhere), CLAUDE_AUTO_RESUME=0 to disable.

zmodload zsh/datetime 2>/dev/null
: ${CLAUDE_RESUME_DIR:=$HOME/.claude/resume-markers}
: ${CLAUDE_AUTO_RESUME:=1}
: ${CLAUDE_RESUME_MAX_AGE_DAYS:=7}

_claude_boot_time() {
  local bt
  if bt=$(sysctl -n kern.boottime 2>/dev/null) && [[ $bt =~ 'sec = ([0-9]+)' ]]; then
    print -r -- $match[1]                                  # macOS
  elif [[ -r /proc/stat ]]; then
    bt=$(grep '^btime' /proc/stat) && print -r -- ${bt##* } # Linux
  fi
}

_claude_mtime() { stat -f %m $1 2>/dev/null || stat -c %Y $1 2>/dev/null; }

# Print a field (cwd|sid) from a marker; for sid the last write wins.
_claude_marker_get() {
  local line val
  while IFS= read -r line; do
    [[ $line == $2=* ]] && val=${line#$2=}
  done < $1
  print -r -- $val
}

claude() {
  # Pass through anything that isn't an interactive session.
  local a
  for a in "$@"; do
    case $a in -p|--print|-h|--help|-v|--version) command claude "$@"; return;; esac
  done
  case $1 in
    mcp|config|update|upgrade|doctor|install|plugin|plugins|agents|attach|logs|stop|rm|setup-token|migrate-installer|auth)
      command claude "$@"; return;;
  esac

  mkdir -p $CLAUDE_RESUME_DIR
  local marker=$CLAUDE_RESUME_DIR/$$.$EPOCHSECONDS.$RANDOM
  print -r -- "cwd=$PWD" > $marker
  CLAUDE_RESUME_MARKER=$marker command claude "$@"
  local rc=$?
  rm -f $marker
  return $rc
}

# Sort leftover markers: delete stale ones, print "interrupted" ones (alive at last reboot).
_claude_interrupted_markers() {
  [[ -d $CLAUDE_RESUME_DIR ]] || return
  local boot=$(_claude_boot_time) m pid mtime
  for m in $CLAUDE_RESUME_DIR/*(N.); do
    [[ $m == *.claimed ]] && { rm -f $m; continue; }
    mtime=$(_claude_mtime $m) || continue
    if (( EPOCHSECONDS - mtime > CLAUDE_RESUME_MAX_AGE_DAYS * 86400 )); then
      rm -f $m; continue
    fi
    if [[ -n $boot ]] && (( mtime >= boot )); then
      # Started this boot: keep only if its shell is still running.
      pid=${${m:t}%%.*}
      kill -0 $pid 2>/dev/null || rm -f $m
      continue
    fi
    [[ -n $(_claude_marker_get $m sid) ]] && print -r -- $m || rm -f $m
  done
}

# Atomically take a marker so two restored tabs never resume the same session.
_claude_claim() {
  mv $1 $1.$$.claimed 2>/dev/null || return 1
  REPLY=$(_claude_marker_get $1.$$.claimed sid)
  rm -f $1.$$.claimed
}

_claude_resume_banner_and_run() {
  local sid=$1
  print -P "%F{cyan}↻ Resuming Claude session ${sid[1,8]}… (any key within 2s to skip)%f"
  if read -s -t 2 -k 1; then
    print -P "%F{yellow}Skipped. Resume later with: claude --resume $sid%f"
    return
  fi
  claude --resume $sid
}

claude-restore() {
  local -a ms; ms=(${(f)"$(_claude_interrupted_markers)"})
  if (( ! $#ms )); then print "No interrupted Claude sessions."; return; fi
  local i=1 m
  for m in $ms; do
    printf '%2d) %s  %s\n' $i ${$(_claude_marker_get $m sid)[1,8]} $(_claude_marker_get $m cwd)
    (( i++ ))
  done
  local n; read "n?Resume which (number, empty to cancel)? "
  [[ $n == <1-> && -n $ms[n] ]] || return
  local dir=$(_claude_marker_get $ms[n] cwd)
  _claude_claim $ms[n] || { print "Already taken by another tab."; return 1; }
  cd $dir && claude --resume $REPLY
}

_claude_auto_resume() {
  [[ -o interactive && $CLAUDE_AUTO_RESUME == 1 && -z $CLAUDE_RESUME_MARKER ]] || return
  local -a ms; ms=(${(f)"$(_claude_interrupted_markers)"})
  (( $#ms )) || return
  local m others=0
  for m in $ms; do
    if [[ $(_claude_marker_get $m cwd) == $PWD ]] && _claude_claim $m; then
      _claude_resume_banner_and_run $REPLY
      return
    fi
  done
  # Nothing for this directory, but there are leftovers elsewhere.
  print -P "%F{cyan}↻ ${#ms} interrupted Claude session(s) from before the restart — run %Bclaude-restore%b%f"
}

# Run once the prompt is about to appear (after the rest of .zshrc has loaded).
_claude_auto_resume_once() {
  add-zsh-hook -d precmd _claude_auto_resume_once
  _claude_auto_resume
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _claude_auto_resume_once
