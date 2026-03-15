#!/usr/bin/env bash
#
# Hyprland Dotfiles Uninstaller
# https://github.com/cxOrz/dotfiles-hyprland
#
set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

CONFIG_DIR="$HOME/.config"
LOCAL_DIR="$HOME/.local"

info()    { echo -e "${BLUE}::${NC} $1"; }
success() { echo -e "${GREEN} ✓${NC} $1"; }

echo ""
echo -e "${BOLD}  Hyprland Dotfiles Uninstaller${NC}"
echo ""

CONFIGS=(dunst fcitx5 flameshot hypr kitty quickshell rofi uwsm waybar wofi yazi)

info "Removing config symlinks..."
for dir in "${CONFIGS[@]}"; do
    target="$CONFIG_DIR/$dir"
    if [[ -L "$target" ]]; then
        rm "$target"
        success "Removed $dir"
    fi
done

if [[ -L "$LOCAL_DIR/share/fcitx5" ]]; then
    rm "$LOCAL_DIR/share/fcitx5"
    success "Removed .local/share/fcitx5"
fi

echo ""
echo -e "${GREEN}${BOLD}  Uninstall complete.${NC}"
echo ""
echo -e "  ${DIM}Backups (if any) are in ~/.dotfiles-backup/${NC}"
echo -e "  ${DIM}Installed packages were not removed.${NC}"
echo ""
