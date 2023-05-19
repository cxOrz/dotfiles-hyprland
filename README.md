# Hyprland & ArchLinux
My daily-use config, collected from the Internet and customized for myself.

Reference: https://wiki.hyprland.org/Getting-Started/Master-Tutorial/

![20230519150904_1](https://github.com/cxOrz/dotfiles-hyprland/assets/32982052/9ab26e58-f752-407d-8e70-84e09773676d)

![20230519152017_1](https://github.com/cxOrz/dotfiles-hyprland/assets/32982052/1e05fad4-720c-4b3c-bca2-7a0ed09ab22d)

![20230519151619_1](https://github.com/cxOrz/dotfiles-hyprland/assets/32982052/1129974b-6132-408f-ad4f-18897eae1b01)



## Hyprland Dependencies
> You are supposed to have hyprland already installed.

```bash
sddm-git # Login manager
kitty # Terminal
dunst # Notification
waybar-hyprland # Top Bar
brightnessctl # Screen brightness command line utils
pavucontrol # GUI pulseaudio controller
pamixer # Pulseaudio command line utils
pulseaudio # Audio
pulseaudio-bluetooth # bluetooth audio support
hyprpaper # Wallpaper
swaylock # lockscreen
grim # screenshot - Screenshot utility for Wayland
slurp # screenshot - select a region from Wayland compositors
rofi-lbonn-wayland-git # application launcher
cliphist # clipboard
thunar # File explorer
gvfs # Show Trash, Computer and other devices in thunar
gtk4 # Necessary for Chrome to use Fcitx5
gnome-keyring # Store secrets, passwords, keys, certificates
polkit-kde-agent # Authentication Agent
qt6-wayland # Hyprland Need
qt5-wayland # Hyprland Need
qt5ct # Hyprland Need
xdg-desktop-portal-gtk # Chrome needed, choose file & upload something
xdg-desktop-portal-hyprland-git # Screen Sharing
```

## Configure

### rofi
Install Dracula Theme (OPTIONAL)
```
git clone https://github.com/dracula/rofi
cp rofi/theme/config1.rasi ~/.config/rofi/config.rassi
```

### waybar
Copy from the folder.

### swaylock
Install Dracula Theme (OPTIONAL)
```
git clone https://githucb.com/dracula/swaylock.git
cp swaylock/ ~/.config/
```

### kitty
OPTIONAL:
1. Install `zsh` and [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
2. Install [JetBrainsMono Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases)

> It's okay if you don't want those things, kitty will use it's default config.

## Might be useful

### google-chrome

~/.config/chrome-flags.conf
```
--ozone-platform-hint=wayland
--force-dark-mode
--enable-features=WebUIDarkMode
--ignore-gpu-blocklist
--enable-gpu-rasterization
--enable-zero-copy
--gtk-version=4
```

### VS Code

Enable fcitx5

~/.config/code-flags.conf
```bash
--ozone-platform=wayland
--enable-wayland-ime
```

### SDDM

/etc/sddm.conf
```
[General]
Numlock=on
```

### zsh

`zsh`, `zsh-syntax-highlighting`, `zsh-autosuggestions` is required.

~/.zshrc
```bash
# ...
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
```

### Dark Theme for gtk widgets
Run the following commands:
```bash
gsettings set org.gnome.desktop.interface gtk-theme Adwaita
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
```

Config files:
```bash
# Both gtk-3.0 and gtk-4.0 config files.
# ~/.config/gtk-3.0/settings.ini
# ~/.config/gtk-4.0/settings.ini
gtk-application-prefer-dark-theme = true
```
