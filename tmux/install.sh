#!/usr/bin/env bash
set -euo pipefail

REPO_RAW_URL="https://raw.githubusercontent.com/dhruvswarup123/alias-hoarder/main"
UTILS_URL="$REPO_RAW_URL/utils.sh"
TMUX_CONF_URL="$REPO_RAW_URL/tmux/tmux.conf"
TPM_REPO_URL="https://github.com/tmux-plugins/tpm"
TARGET="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ -t 0 ]; then
  INSTALL_MODE="local"
else
  INSTALL_MODE="web"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null || dirname "$0")" && pwd)"
UTILS_PATH="$SCRIPT_DIR/../utils.sh"

if [ "$INSTALL_MODE" = "web" ]; then
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$UTILS_URL" -o /tmp/utils.sh
  elif command -v wget >/dev/null 2>&1; then
    wget -qO /tmp/utils.sh "$UTILS_URL"
  else
    echo "Error: Need curl or wget to download utils.sh" >&2
    exit 1
  fi
  UTILS_PATH="/tmp/utils.sh"
fi

. "$UTILS_PATH"
cleanup() {
  if [ "$INSTALL_MODE" = "web" ] && [ -f "/tmp/utils.sh" ]; then
    rm -f /tmp/utils.sh
  fi
  unset REPO_RAW_URL UTILS_URL TMUX_CONF_URL TPM_REPO_URL TARGET TPM_DIR
  unset SCRIPT_DIR UTILS_PATH INSTALL_MODE BAK LOCAL_CONF PLUGIN_OUTPUT PLUGINS_INSTALLED
}

trap cleanup EXIT

print_status "$([ "$INSTALL_MODE" = "local" ] && echo "Local" || echo "Web") installation detected"


print_status "[1/5] Checking for existing config..."
BAK=$(backup_file "$TARGET")


print_status "[2/5] Installing new config..."
if [ "$INSTALL_MODE" = "local" ]; then

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  LOCAL_CONF="$SCRIPT_DIR/tmux.conf"
  print_status "  Looking for config in: $SCRIPT_DIR"
  if [ -f "$LOCAL_CONF" ]; then
    cp "$LOCAL_CONF" "$TARGET"
    print_success "Copied local config -> $TARGET"
  else
    print_error "tmux.conf not found in script directory: $SCRIPT_DIR"
    restore_backup "$BAK" "$TARGET"
    exit 1
  fi
else

  print_status "  Downloading from: $TMUX_CONF_URL"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$TMUX_CONF_URL" -o "$TARGET"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$TARGET" "$TMUX_CONF_URL"
  else
    print_error "need curl or wget to fetch tmux.conf"
    restore_backup "$BAK" "$TARGET"
    exit 1
  fi
  print_success "  Downloaded new config -> $TARGET"
fi


print_status "[3/5] Installing deps..."
if [ ! -d "$TPM_DIR" ]; then
  if ! command -v git >/dev/null 2>&1; then
    print_error "git is required to install TPM"
    restore_backup "$BAK" "$TARGET"
    exit 1
  fi
  git clone --depth=1 "$TPM_REPO_URL" "$TPM_DIR"
  print_success "  Installed TPM -> $TPM_DIR"
else
  print_warning "  TPM already present -> $TPM_DIR"
fi


print_status "[4/5] Installing tmux plugins..."
PLUGINS_INSTALLED=false
if [ -d "$TPM_DIR" ]; then

  if [ -x "$TPM_DIR/bin/install_plugins" ]; then

    if PLUGIN_OUTPUT=$("$TPM_DIR/bin/install_plugins" 2>&1); then
      echo "$PLUGIN_OUTPUT" | sed 's/^/\t/'
      print_success "  Plugins installed automatically"
      PLUGINS_INSTALLED=true
    else
      echo "$PLUGIN_OUTPUT" | sed 's/^/\t/'
      print_warning "  Auto-install failed"
    fi
  else
    print_warning "  TPM install script not found, skipping auto-install"
  fi
else
  print_warning "  TPM not installed, skipping plugin installation"
fi

print_status "[5/5] Reloading tmux session..."
if command -v tmux >/dev/null 2>&1; then
  if [ -n "${TMUX:-}" ]; then
    tmux source-file "$TARGET"
    print_success "  Reloaded current tmux session"
  else
    print_status "  Not in tmux session, skipping reload"
  fi
else
  print_status "  tmux not found, skipping reload"
fi

echo
print_status "New prefix key: C-Space"


if [ "$PLUGINS_INSTALLED" = true ]; then
  print_success "Plugins installed automatically"
else
  print_warning "Auto-install failed - press [prefix] + Shift+I inside tmux to install plugins"
fi

echo
print_success "🎉 Success!"

