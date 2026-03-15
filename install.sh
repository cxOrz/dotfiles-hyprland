#!/usr/bin/env bash
#
# Hyprland Dotfiles Installer
# https://github.com/cxOrz/dotfiles-hyprland
#
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Paths ────────────────────────────────────────────────────────
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config"
LOCAL_DIR="$HOME/.local"
BACKUP_DIR=""

# ─── Helpers ──────────────────────────────────────────────────────
info()    { echo -e "${BLUE}::${NC} $1"; }
success() { echo -e "${GREEN} ✓${NC} $1"; }
warn()    { echo -e "${YELLOW} !${NC} $1"; }
error()   { echo -e "${RED} ✗${NC} $1"; exit 1; }

ask() {
    local prompt="$1" default="$2" result
    echo -en "${CYAN} ?${NC} ${prompt} ${DIM}[${default}]${NC}: " >&2
    read -r result
    echo "${result:-$default}"
}

ask_yn() {
    local prompt="$1" default="${2:-Y}" result
    echo -en "${CYAN} ?${NC} ${prompt} ${DIM}[${default}]${NC}: "
    read -r result
    result="${result:-$default}"
    [[ "${result,,}" == "y" || "${result,,}" == "yes" ]]
}

link_config() {
    local src="$1" dst="$2"
    [[ -L "$dst" ]] && rm "$dst"
    ln -sf "$src" "$dst"
}

# ─── Banner ───────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ╔══════════════════════════════════════╗"
echo -e "  ║     Hyprland Dotfiles Installer      ║"
echo -e "  ╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "  Source  ${DIM}${DOTFILES_DIR}${NC}"
echo -e "  Target  ${DIM}${CONFIG_DIR}${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Step 1: Dependencies
# ═══════════════════════════════════════════════════════════════════
DEPS=(
    # Session & Login
    uwsm greetd
    # Terminal
    kitty
    # Notification
    dunst
    # UI Toolkit
    quickshell
    # Status bar
    waybar
    # Utilities
    brightnessctl pavucontrol playerctl
    # Audio
    pipewire pipewire-pulse pipewire-alsa wireplumber
    # Hyprland ecosystem
    hyprpaper hyprlock hyprpicker hyprpolkitagent
    # Screenshot & Image
    feh flameshot grim slurp
    # Launcher
    rofi
    # Clipboard
    wl-clipboard cliphist
    # File Manager
    yazi
    # GTK/QT integration
    gtk4 qt6-wayland qt5-wayland qt6ct
    # Secrets & Auth
    seahorse gnome-keyring
    # Portals
    xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
    # Font
    ttf-jetbrains-mono-nerd
)

DEPS_FCITX=(
    fcitx5 fcitx5-rime rime-ice-git fcitx5-configtool
)

if ask_yn "Install dependencies?"; then
    # Detect package manager
    if command -v yay &>/dev/null; then
        PKG_CMD="yay -S --needed --noconfirm"
    elif command -v paru &>/dev/null; then
        PKG_CMD="paru -S --needed --noconfirm"
    else
        PKG_CMD="sudo pacman -S --needed --noconfirm"
        warn "No AUR helper found (yay/paru). AUR packages may fail."
        warn "Install yay first: https://github.com/Jguer/yay"
    fi

    info "Installing core packages..."
    if $PKG_CMD "${DEPS[@]}"; then
        success "Core packages installed"
    else
        warn "Some packages failed. You may need to install them manually."
    fi

    echo ""
    if ask_yn "Install Chinese input method (Fcitx5 + Rime)?" "n"; then
        info "Installing Fcitx5 + Rime..."
        if $PKG_CMD "${DEPS_FCITX[@]}"; then
            success "Input method packages installed"
        else
            warn "Some input method packages failed to install."
        fi
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Step 2: Monitor Configuration
# ═══════════════════════════════════════════════════════════════════
info "Monitor Configuration"
echo -e "  ${DIM}Format: monitor = name, resolution, position, scale"
echo -e ""
echo -e "  Examples:"
echo -e "    Single (auto-detect):   monitor = ,preferred,auto,auto"
echo -e "    Specific:               monitor = HDMI-A-1, 1920x1080@60, 0x0, 1"
echo -e "    Dual:                   monitor = DP-1, 2560x1440@165, 0x0, 1"
echo -e "                            monitor = HDMI-A-1, 1920x1080@60, 2560x0, 1"
echo -e "    HiDPI:                  monitor = eDP-1, 2560x1600@120, 0x0, 1.5${NC}"
echo ""

MONITORS=()
echo -e "${CYAN} ?${NC} Enter monitor config (one line per monitor, empty line to finish)"
echo -e "   ${DIM}Press Enter directly to use default: auto-detect${NC}"
while true; do
    echo -en "   > "
    read -r line
    [[ -z "$line" ]] && break
    MONITORS+=("$line")
done

if [[ ${#MONITORS[@]} -eq 0 ]]; then
    MONITORS=("monitor = ,preferred,auto,auto")
    success "Using default: auto-detect"
else
    success "Custom config set (${#MONITORS[@]} monitor(s))"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Step 3: Wallpaper
# ═══════════════════════════════════════════════════════════════════
WALLPAPER=$(ask "Wallpaper path" "~/Pictures/wallpaper.jpg")

echo ""

# ═══════════════════════════════════════════════════════════════════
# Step 4: Write Personal Configs to Repo
# ═══════════════════════════════════════════════════════════════════
info "Writing personal configuration to repo..."

# monitors.conf
{
    echo "# Monitor Configuration"
    echo "# See: https://wiki.hyprland.org/Configuring/Monitors/"
    echo "#"
    echo "# Format: monitor = name, resolution, position, scale"
    echo "#"
    echo "# Examples:"
    echo "#   monitor = ,preferred,auto,auto"
    echo "#   monitor = HDMI-A-1, 1920x1080@60, 0x0, 1"
    echo "#   monitor = DP-1, 2560x1440@165, 0x0, 1"
    echo "#   monitor = eDP-1, 2560x1600@120, 0x0, 1.5"
    echo "#"
    echo "# List connected monitors: hyprctl monitors all"
    echo ""
    printf '%s\n' "${MONITORS[@]}"
} > "$DOTFILES_DIR/.config/hypr/monitors.conf"
success "Updated monitors.conf"

# hyprpaper.conf
cat > "$DOTFILES_DIR/.config/hypr/hyprpaper.conf" << EOF
wallpaper {
    monitor =
    path = $WALLPAPER
    fit_mode = cover
}
EOF
success "Updated hyprpaper.conf"

echo ""

# ═══════════════════════════════════════════════════════════════════
# Step 5: Backup Existing Configs
# ═══════════════════════════════════════════════════════════════════
CONFIGS_TO_LINK=(dunst fcitx5 flameshot hypr kitty quickshell rofi uwsm waybar wofi yazi)
BACKUP_NEEDED=false

for dir in "${CONFIGS_TO_LINK[@]}"; do
    target="$CONFIG_DIR/$dir"
    if [[ -e "$target" && ! -L "$target" ]]; then
        BACKUP_NEEDED=true
        break
    fi
done

if [[ -e "$LOCAL_DIR/share/fcitx5" && ! -L "$LOCAL_DIR/share/fcitx5" ]]; then
    BACKUP_NEEDED=true
fi

if [[ "$BACKUP_NEEDED" == true ]]; then
    BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
    info "Backing up existing configs to ${DIM}${BACKUP_DIR}${NC}"
    mkdir -p "$BACKUP_DIR/.config"

    for dir in "${CONFIGS_TO_LINK[@]}"; do
        target="$CONFIG_DIR/$dir"
        if [[ -e "$target" && ! -L "$target" ]]; then
            mv "$target" "$BACKUP_DIR/.config/$dir"
            success "Backed up $dir"
        fi
    done

    if [[ -e "$LOCAL_DIR/share/fcitx5" && ! -L "$LOCAL_DIR/share/fcitx5" ]]; then
        mkdir -p "$BACKUP_DIR/.local/share"
        mv "$LOCAL_DIR/share/fcitx5" "$BACKUP_DIR/.local/share/fcitx5"
        success "Backed up .local/share/fcitx5"
    fi

    echo ""
fi

# ═══════════════════════════════════════════════════════════════════
# Step 6: Create Symlinks
# ═══════════════════════════════════════════════════════════════════
info "Deploying configurations..."

mkdir -p "$CONFIG_DIR"
mkdir -p "$LOCAL_DIR/share"

for dir in "${CONFIGS_TO_LINK[@]}"; do
    link_config "$DOTFILES_DIR/.config/$dir" "$CONFIG_DIR/$dir"
done
success "Linked config directories"

# .local/share/fcitx5
link_config "$DOTFILES_DIR/.local/share/fcitx5" "$LOCAL_DIR/share/fcitx5"
success "Linked .local/share/fcitx5"

echo ""

# ═══════════════════════════════════════════════════════════════════
# Step 7: Apply Default Theme
# ═══════════════════════════════════════════════════════════════════
info "Applying default theme (Cobalt Night)..."
if bash "$DOTFILES_DIR/.config/quickshell/scripts/apply-theme.sh" md3-cobalt-night 2>/dev/null; then
    success "Theme applied"
else
    warn "Theme script failed (normal if not in a Hyprland session)"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Done
# ═══════════════════════════════════════════════════════════════════
echo -e "${GREEN}${BOLD}  Installation complete!${NC}"
echo ""
echo -e "  ${BOLD}Post-install checklist:${NC}"
echo ""
echo -e "  1. Place your wallpaper at: ${CYAN}${WALLPAPER}${NC}"
echo ""
echo -e "  2. Install a GTK dark theme and apply it:"
echo -e "     ${DIM}gsettings set org.gnome.desktop.interface gtk-theme Material-Black-Blueberry"
echo -e "     gsettings set org.gnome.desktop.interface color-scheme prefer-dark${NC}"
echo ""
echo -e "  3. Enable greetd login manager:"
echo -e "     ${DIM}sudo systemctl enable greetd${NC}"
echo ""
echo -e "  4. For Chinese input method setup, see:"
echo -e "     ${DIM}.config/fcitx5/README.md${NC}"
echo ""
echo -e "  5. Log out and start a new Hyprland session."
echo ""
echo -e "  ${DIM}─────────────────────────────────────────────${NC}"
echo -e "  ${DIM}Backups:      ${BACKUP_DIR:-none}${NC}"
echo -e "  ${DIM}Edit configs: ${DOTFILES_DIR}/.config/${NC}"
echo -e "  ${DIM}Switch theme: ~/.config/quickshell/scripts/apply-theme.sh <theme>${NC}"
echo ""
