#!/usr/bin/env bash
set -e

### --- Constants ---
TMUX_CONF_URL="https://raw.githubusercontent.com/dhruvswarup123/alias-hoarder/main/tmux/tmux.conf"
TPM_REPO_URL="https://github.com/tmux-plugins/tpm"
TARGET="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"

### --- Helper Functions ---
restore_backup() {
  if [ -n "${BAK:-}" ] && [ -f "$BAK" ]; then
    mv "$BAK" "$TARGET"
    echo "Restored backup -> $TARGET"
  fi
}

### --- Environment Detection ---
if [ -t 0 ]; then
  echo "Local installation detected"
  INSTALL_MODE="local"
else
  echo "Web installation detected (piped from curl/wget)"
  INSTALL_MODE="web"
fi
echo ""

### --- Step 1: Backup existing config (if any) ---
echo "[1/5] Backing up existing config..."
if [ -f "$TARGET" ]; then
  BAK="$TARGET.bak.$(date +%Y%m%d-%H%M%S)"
  mv "$TARGET" "$BAK"
  echo "  Backed up old config -> $BAK"
fi

### --- Step 2: Download/copy new config ---
echo "[2/5] Installing new config..."
if [ "$INSTALL_MODE" = "local" ]; then
  # Local install - copy from same directory as script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  LOCAL_CONF="$SCRIPT_DIR/tmux.conf"
  echo "  Looking for config in: $SCRIPT_DIR"
  if [ -f "$LOCAL_CONF" ]; then
    cp "$LOCAL_CONF" "$TARGET"
    echo "  Copied local config -> $TARGET"
  else
    echo "Error: tmux.conf not found in script directory: $SCRIPT_DIR" >&2
    restore_backup
    exit 1
  fi
else
  # Web install - download from URL
  echo "  Downloading from: $TMUX_CONF_URL"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$TMUX_CONF_URL" -o "$TARGET"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$TARGET" "$TMUX_CONF_URL"
  else
    echo "Error: need curl or wget to fetch tmux.conf" >&2
    restore_backup
    exit 1
  fi
  echo "  Downloaded new config -> $TARGET"
fi

### --- Step 3: Install TPM (if missing) ---
echo "[3/5] Installing TPM..."
if [ ! -d "$TPM_DIR" ]; then
  if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is required to install TPM" >&2
    restore_backup
    exit 1
  fi
  git clone --depth=1 "$TPM_REPO_URL" "$TPM_DIR"
  echo "  Installed TPM -> $TPM_DIR"
else
  echo "  TPM already present -> $TPM_DIR"
fi

### --- Step 4: Install plugins automatically ---
echo "[4/5] Installing tmux plugins..."
PLUGINS_INSTALLED=false
if [ -d "$TPM_DIR" ]; then
  # Try to install plugins automatically
  if [ -x "$TPM_DIR/bin/install_plugins" ]; then
    # Capture output and check exit code properly
    if PLUGIN_OUTPUT=$("$TPM_DIR/bin/install_plugins" 2>&1); then
      echo "$PLUGIN_OUTPUT" | sed 's/^/\t/'
      echo "  Plugins installed automatically"
      PLUGINS_INSTALLED=true
    else
      echo "$PLUGIN_OUTPUT" | sed 's/^/\t/'
      echo "  Auto-install failed"
    fi
  else
    echo "  TPM install script not found, skipping auto-install"
  fi
else
  echo "  TPM not installed, skipping plugin installation"
fi

### --- Step 5: Optionally reload ---
if command -v tmux >/dev/null 2>&1; then
  # Reload the current session if we're inside tmux
  if [ -n "${TMUX:-}" ]; then
    tmux source-file "$TARGET"
    echo "  Reloaded current tmux session"
  fi
fi

echo ""
echo "New prefix key: C-Space"

# Check if plugins were installed and provide appropriate message
if [ "$PLUGINS_INSTALLED" = true ]; then
  echo "Plugins installed automatically"
else
  echo "Auto-install failed - press [prefix] + Shift+I inside tmux to install plugins"
fi

echo ""
echo "🎉 Success!"

### --- Cleanup ---
unset BAK TMUX_CONF_URL TPM_REPO_URL TARGET TPM_DIR INSTALL_MODE PLUGINS_INSTALLED