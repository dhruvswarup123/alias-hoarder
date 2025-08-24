#!/usr/bin/env bash
set -euo pipefail

REPO_RAW_URL="https://raw.githubusercontent.com/dhruvswarup123/alias-hoarder/main"
STARSHIP_TOML_URL="$REPO_RAW_URL/zsh/starship.toml"
UTILS_URL="$REPO_RAW_URL/utils.sh"
OH_MY_ZSH_INSTALL_URL="https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
CATPPUCCIN_THEME_URL="https://raw.githubusercontent.com/catppuccin/zsh-syntax-highlighting/main/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh"
if [ -t 0 ]; then
  INSTALL_MODE="local"
else
  INSTALL_MODE="web"
fi

OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM_PLUGINS="$OH_MY_ZSH_DIR/custom/plugins"
ZSH_CUSTOM_THEMES="$OH_MY_ZSH_DIR/custom/themes"
ZSHRC_PATH="$HOME/.zshrc"
STARSHIP_CONFIG_DEST="$HOME/.config/starship.toml"

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
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  UTILS_PATH="$SCRIPT_DIR/../utils.sh"
fi

. "$UTILS_PATH"

print_status "$([ "$INSTALL_MODE" = "local" ] && echo "Local" || echo "Web") installation detected"

install_packages() {
  print_status "Installing packages (tmux, fzf, zsh, git, curl)..."
  command -v apt >/dev/null 2>&1 || { print_error "Requires apt (Ubuntu/Debian)."; exit 1; }
  sudo apt update
  sudo apt install -y tmux fzf zsh git curl
  print_success "Packages installed."
}

install_starship() {
  print_status "Installing Starship..."
  if ! command -v starship >/dev/null 2>&1; then
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
    print_success "Starship installed."
  else
    print_success "Starship already installed."
  fi
  mkdir -p ~/.config
  if [ "$INSTALL_MODE" = "web" ]; then
    print_status "Downloading starship.toml..."
    backup_file "$STARSHIP_CONFIG_DEST" >/dev/null
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL "$STARSHIP_TOML_URL" -o "$STARSHIP_CONFIG_DEST"
    elif command -v wget >/dev/null 2>&1; then
      wget -qO "$STARSHIP_CONFIG_DEST" "$STARSHIP_TOML_URL"
    else
      print_error "Need curl or wget to download starship.toml"
      exit 1
    fi
  else
    backup_file "$STARSHIP_CONFIG_DEST" >/dev/null
    cp "$SCRIPT_DIR/starship.toml" "$STARSHIP_CONFIG_DEST"
  fi
  print_success "Starship config installed to $STARSHIP_CONFIG_DEST"
}

setup_zsh() {
  print_status "Setting up zsh & Oh My Zsh..."
  if [[ ! -d "$OH_MY_ZSH_DIR" ]]; then
    print_status "  Installing Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL $OH_MY_ZSH_INSTALL_URL)"
    print_success "  Oh My Zsh installed"
  else
    print_success "  Oh My Zsh already installed"
  fi

  print_status "  Installing zsh plugins..."
  git clone --quiet https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM_PLUGINS/zsh-autosuggestions" 2>/dev/null || true
  git clone --quiet https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM_PLUGINS/zsh-syntax-highlighting" 2>/dev/null || true
  print_success "  Plugins installed"

  print_status "  Installing Catppuccin theme..."
  mkdir -p "$ZSH_CUSTOM_THEMES"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$CATPPUCCIN_THEME_URL" -o "$ZSH_CUSTOM_THEMES/catppuccin_mocha-zsh-syntax-highlighting.zsh"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$ZSH_CUSTOM_THEMES/catppuccin_mocha-zsh-syntax-highlighting.zsh" "$CATPPUCCIN_THEME_URL"
  else
    print_error "Need curl or wget to download Catppuccin theme"
    exit 1
  fi
  print_success "  Catppuccin theme installed"

  print_status "  Creating .zshrc configuration..."
  backup_file "$ZSHRC_PATH" >/dev/null
  cat > "$ZSHRC_PATH" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # using Starship

plugins=(
  git
  fzf
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# Starship
eval "$(starship init zsh)"

# Aliases
[[ -f ~/.bash_aliases ]] && source ~/.bash_aliases

# FZF defaults
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border"

# History
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY HIST_IGNORE_DUPS

# Catppuccin syntax-highlighting colors
[[ -f "$ZSH_CUSTOM_THEMES/catppuccin_mocha-zsh-syntax-highlighting.zsh" ]] && \
  source "$ZSH_CUSTOM_THEMES/catppuccin_mocha-zsh-syntax-highlighting.zsh"
EOF

  print_success "Zsh configuration written to $ZSHRC_PATH"
}

setup_shell_switching() {
  print_status "Configuring shell switching..."
  if ! grep -q 'exec zsh' ~/.bashrc 2>/dev/null; then
    {
      echo
      echo "# Auto-switch to zsh for interactive shells"
      echo 'if [[ -t 1 && $- == *i* && $(ps -p $$ -o comm=) != "zsh" ]]; then'
      echo '  exec zsh'
      echo 'fi'
    } >> ~/.bashrc
    print_success "Added auto-switch to ~/.bashrc"
  else
    print_success "Auto-switch already configured in ~/.bashrc"
  fi

  if command -v chsh >/dev/null 2>&1; then
    CHSH_SHELL="$(command -v zsh)"
    if [[ -n "${CHSH_SHELL:-}" && "$(getent passwd "$USER" | cut -d: -f7)" != "$CHSH_SHELL" ]]; then
      print_status "Attempting to set login shell to zsh (may prompt)…"
      chsh -s "$CHSH_SHELL" || print_error "Could not change login shell; run: chsh -s \"$(command -v zsh)\""
    else
      print_success "Login shell already set to zsh"
    fi
  fi
}

cleanup() {
  if [ "$INSTALL_MODE" = "web" ] && [ -f "/tmp/utils.sh" ]; then
    rm -f /tmp/utils.sh
  fi
  unset REPO_RAW_URL STARSHIP_TOML_URL UTILS_URL OH_MY_ZSH_INSTALL_URL CATPPUCCIN_THEME_URL
  unset SCRIPT_DIR OH_MY_ZSH_DIR ZSH_CUSTOM_PLUGINS ZSH_CUSTOM_THEMES ZSHRC_PATH
  unset STARSHIP_CONFIG_DEST UTILS_PATH INSTALL_MODE CHSH_SHELL
}

trap cleanup EXIT

main() {
  print_status "Starting zsh development environment setup..."
  install_packages
  install_starship
  setup_zsh
  setup_shell_switching

  print_success "Setup complete!"
  echo
  print_status "Next steps:"
  echo "1) Restart your terminal (or run 'exec zsh')"
  echo "2) Install a Nerd Font in your terminal for powerline glyphs"
  echo "3) For tmux setup, run the tmux install script separately"
  echo "4) Enjoy your new zsh setup with Starship prompt!"
}

main "$@"
