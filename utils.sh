#!/bin/bash

# Catppuccin Mocha Palette
ROSEWATER='\033[38;2;245;224;220m'
FLAMINGO='\033[38;2;242;205;205m'
PINK='\033[38;2;245;194;231m'
MAUVE='\033[38;2;203;166;247m'
RED='\033[38;2;243;139;168m'
MAROON='\033[38;2;235;160;172m'
PEACH='\033[38;2;250;179;135m'
YELLOW='\033[38;2;249;226;175m'
GREEN='\033[38;2;166;227;161m'
TEAL='\033[38;2;148;226;213m'
SKY='\033[38;2;137;220;235m'
SAPPHIRE='\033[38;2;116;199;236m'
BLUE='\033[38;2;137;180;250m'
LAVENDER='\033[38;2;180;190;254m'
TEXT='\033[38;2;205;214;244m'
SUBTEXT1='\033[38;2;186;194;222m'
SUBTEXT0='\033[38;2;166;173;200m'
OVERLAY2='\033[38;2;147;153;178m'
OVERLAY1='\033[38;2;127;132;156m'
OVERLAY0='\033[38;2;108;112;134m'
SURFACE2='\033[38;2;88;91;112m'
SURFACE1='\033[38;2;69;71;90m'
SURFACE0='\033[38;2;49;50;68m'
BASE='\033[38;2;30;30;46m'
MANTLE='\033[38;2;24;24;37m'
CRUST='\033[38;2;17;17;27m'
RESET='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

# Generic backup function
# Usage: backup_file <file_path>
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local bak="$file.bak.$(date +%Y%m%d-%H%M%S)"
        mv "$file" "$bak"
        print_status "Backed up $file -> $bak"
        echo "$bak"
    fi
}

# Generic restore function
# Usage: restore_backup <backup_path> <target_path>
restore_backup() {
    local bak="$1"
    local target="$2"
    if [ -n "$bak" ] && [ -f "$bak" ]; then
        mv "$bak" "$target"
        print_status "Restored backup -> $target"
    fi
}
