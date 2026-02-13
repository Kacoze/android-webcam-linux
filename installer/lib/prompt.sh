#!/usr/bin/env bash

PROMPT_FD=0

setup_prompt_fd() {
  if [ "$WANTS_HELP" = true ] || [ -t 0 ]; then
    return 0
  fi

  if [ "$AUTO_YES" = true ]; then
    log_warn "No TTY detected. Running in non-interactive mode (--yes)."
    return 0
  fi

  if [ ! -e /dev/tty ] || [ ! -r /dev/tty ]; then
    log_error "Running from a pipe without a TTY. Use --yes or run locally."
    exit 1
  fi

  exec 3</dev/tty 2>/dev/null || {
    log_error "Cannot open /dev/tty. Use --yes or run locally."
    exit 1
  }
  PROMPT_FD=3
  log_warn "Installation run from pipe; prompts will be read from /dev/tty."
}

prompt_read() {
  local prompt="$1"
  local out_var="$2"
  if [ "$AUTO_YES" = true ]; then
    printf -v "$out_var" "y"
    return 0
  fi
  read -u "${PROMPT_FD}" -r -p "$prompt" "$out_var"
}
