# Hyprland Dotfiles

Hyrpland dotfiles for Arch Linux — Chrome OS style with Material Design 3.

## Gallery

| Desktop | Lock Screen | App Launcher |
| :---: | :---: | :---: |
| ![Desktop](./examples/desktop.webp) | ![Lock Screen](./examples/lockscreen.webp) | ![App Launcher](./examples/app-launcher.webp) |

| Control Center | Notification | Theme Panel |
| :---: | :---: | :---: |
| ![Control Center](./examples/control-center.webp) | ![Notification](./examples/notification.webp) | ![Theme Panel](./examples/theme-panel.webp) |

| Terminal |
| :---: |
| ![Kitty Theme](./examples/kitty-theme.webp) |


## Prerequisites

- Arch Linux (or Arch-based distro)
- [Hyprland](https://wiki.hyprland.org/Getting-Started/Installation/) installed
- An AUR helper ([yay](https://github.com/Jguer/yay) or [paru](https://github.com/Morganamilo/paru)) is recommended

## Installation

```bash
git clone https://github.com/cxOrz/dotfiles-hyprland.git
cd dotfiles-hyprland
./install.sh
```

After installation, set up the login screen and **reboot to start a Hyprland session**. Hyprland is started directly with `start-hyprland` (no session manager is required).

### Post-install

```bash
# Set GTK dark theme
gsettings set org.gnome.desktop.interface gtk-theme Material-Black-Blueberry
gsettings set org.gnome.desktop.interface color-scheme prefer-dark

# Set up the greetd + tuigreet login screen
sudo install -Dm644 greetd/config.toml /etc/greetd/config.toml
sudo systemctl enable greetd
```

### Login screen (greetd + tuigreet)

The login screen is [tuigreet](https://github.com/apognu/tuigreet), configured in [`greetd/config.toml`](./greetd/config.toml):

```toml
[terminal]
vt = 1

[default_session]
command = "tuigreet --remember --cmd 'start-hyprland'"
user = "greeter"
```

- `--remember` pre-fills the last used username.
- `--cmd 'start-hyprland'` launches Hyprland directly; press `F3` in tuigreet to pick a different session.

### Wi-Fi

Wi-Fi is handled by NetworkManager with the iwd backend. For the backend settings and
auto-connect behaviour, see [networkmanager/README.md](./networkmanager/README.md).

## Keybindings

### General

| Key | Action |
| --- | --- |
| `Super + Q` | Terminal (Kitty) |
| `Super + E` | File Manager (Yazi) |
| `Super + Space` | App Launcher (Rofi) |
| `Super + X` | Close Window |
| `Super + F` | Toggle Floating |
| `Super + L` | Lock Screen |
| `Super + V` | Clipboard History |
| `Super + Escape` | Window Switcher |
| `Super + Delete` | Power Menu |
| `Super + A` | Control Center |
| `Super + Shift + S` | Screenshot |
| `Super + Shift + P` | Color Picker |

### Window Management

| Key | Action |
| --- | --- |
| `Super + Arrow Keys` | Move Focus |
| `Super + Shift + Arrow Keys` | Move Window |
| `Super + Ctrl + Arrow Keys` | Resize Window |
| `Super + P` | Pseudo Tile |
| `Super + J` | Toggle Split |

### Workspaces

| Key | Action |
| --- | --- |
| `Super + 1-0` | Switch to Workspace 1-10 |
| `Super + Shift + 1-0` | Move Window to Workspace 1-10 |
| `Super + Tab` | Next Workspace |
| `Super + [ / ]` | Previous / Next Workspace |
| `Super + Scroll` | Cycle Workspaces |

### Media

| Key | Action |
| --- | --- |
| `Volume Up/Down/Mute` | Audio Control |
| `Brightness Up/Down` | Screen Brightness |
| `Media Play/Next/Prev` | Playback Control |


## Directory Structure

```
.
├── .config/
│   ├── dunst/              # Notification daemon
│   ├── fcitx5/             # Chinese input method
│   ├── hypr/               # Hyprland window manager
│   │   ├── hyprland.lua    #   Main config (keybinds, rules, appearance)
│   │   ├── hyprlock.conf   #   Lock screen
│   │   ├── hypridle.conf  #   Idle daemon
│   │   ├── hyprpaper.conf  #   Wallpaper
│   │   ├── monitors.lua    #   Monitor setup
│   │   └── scripts/
│   ├── kitty/              # Terminal emulator
│   ├── quickshell/         # Custom desktop UI
│   │   ├── modules/
│   │   │   ├── controlcenter/  # WiFi, Bluetooth, Volume, Brightness, Themes
│   │   │   ├── notifications/  # Notification center + toast popups
│   │   │   ├── powermenu/      # Shutdown, Reboot, Suspend, Lock
│   │   │   └── shelf/          # Bottom bar with workspaces
│   │   ├── scripts/        # Theme switching script
│   │   ├── shell.qml       # Main shell entry point
│   │   └── Theme.qml       # Theme definitions (6 themes)
│   ├── rofi/               # App launcher
│   ├── waybar/             # Status bar
│   └── yazi/               # File manager
├── .local/share/
│   └── fcitx5/             # Rime config & input themes
├── examples/               # Screenshots
├── greetd/
│   └── config.toml         # Login screen (greetd + tuigreet)
├── networkmanager/
│   ├── README.md            # Wi-Fi (NetworkManager + iwd) notes
│   └── wifi_backend.conf    # NetworkManager Wi-Fi backend settings
├── install.sh
├── uninstall.sh
├── LICENSE
└── README.md
```

## Dependencies

<details>
<summary>Full package list</summary>

| Package | Description |
| --- | --- |
| `greetd` | Login manager |
| `greetd-tuigreet` | TUI login screen for greetd |
| `kitty` | Terminal emulator |
| `dunst` | Notification daemon |
| `quickshell` | QML-based desktop shell toolkit |
| `waybar` | Wayland status bar |
| `brightnessctl` | Screen brightness control |
| `pavucontrol` | PulseAudio volume GUI |
| `playerctl` | Media player control |
| `pipewire` | Audio server |
| `pipewire-pulse` | PulseAudio compatibility |
| `pipewire-alsa` | ALSA compatibility |
| `wireplumber` | PipeWire session manager |
| `hyprpaper` | Wallpaper manager |
| `hypridle` | Idle daemon (auto lock / dpms) |
| `hyprlock` | Lock screen |
| `hyprpicker` | Color picker |
| `hyprpolkitagent` | Authentication agent |

| `grim` | Wayland screenshot utility |
| `slurp` | Region selector |
| `satty` | Screenshot annotation tool |
| `rofi-wayland` | Application launcher |
| `wl-clipboard` | Wayland clipboard |
| `cliphist` | Clipboard history |
| `yazi` | Terminal file manager |
| `gtk4` | GTK4 (required for Fcitx5 in Chromium) |
| `qt6-wayland` | Qt6 Wayland support |
| `qt5-wayland` | Qt5 Wayland support |
| `qt6ct` | Qt6 theme configuration |
| `seahorse` | Password manager GUI |
| `gnome-keyring` | Secret/password storage |
| `xdg-desktop-portal-gtk` | GTK file picker portal |
| `xdg-desktop-portal-hyprland-git` | Hyprland screen sharing portal |
| `ttf-jetbrains-mono-nerd` | JetBrainsMono Nerd Font |

**Optional — Chinese input method:**

| Package | Description |
| --- | --- |
| `fcitx5` | Input method framework |
| `fcitx5-rime` | Rime engine |
| `rime-ice-git` | Rime Ice pinyin schema |
| `fcitx5-configtool` | Configuration GUI |

</details>

## Chinese Input Method

For Fcitx5 + Rime setup, see [.config/fcitx5/README.md](./.config/fcitx5/README.md).

## Uninstall

```bash
./uninstall.sh
```

This removes all symlinks created by the installer. Your backups remain in `~/.dotfiles-backup/`. Installed packages are not removed.

## License

[MIT](./LICENSE)
