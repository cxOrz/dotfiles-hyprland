# Hyprland & ArchLinux
My daily-use config, collected from the Internet and customized for myself.

Reference: https://wiki.hyprland.org/Getting-Started/Master-Tutorial/

![20230522011457_1](https://github.com/cxOrz/dotfiles-hyprland/assets/32982052/c4f5e420-110d-46eb-a95d-d9c20c36c3c7)

![20230522010745_1](https://github.com/cxOrz/dotfiles-hyprland/assets/32982052/2d07f78b-5002-4f0c-8937-af7493a1f56a)

![20230522011816_1](https://github.com/cxOrz/dotfiles-hyprland/assets/32982052/226709be-92d5-42ea-b1da-9884126a2b17)

## Hyprland Dependencies
> You are supposed to have hyprland already installed.

```bash
sddm-git # Login manager
kitty # Terminal
dunst # Notification
waybar-hyprland-git # Top Bar
brightnessctl # Screen brightness command line utils
pavucontrol # GUI pulseaudio controller
pamixer # Pulseaudio command line utils
pipewire
pipewire-pulse # Audio
pipewire-alsa
wireplumber
hyprpaper # Wallpaper
swaylock # lockscreen
grim # screenshot - Screenshot utility for Wayland
slurp # screenshot - select a region from Wayland compositors
wofi # application launcher
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
nvidia-vaapi-driver
```

## Configure

### waybar
Copy from the folder.

### swaylock
Install Dracula Theme (OPTIONAL)
```
git clone https://github.com/dracula/swaylock.git
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
--enable-wayland-ime
--use-angle=opengl
```

### VS Code

If you need to enable enable fcitx5

~/.config/code-flags.conf
```bash
--ozone-platform-hint=wayland
--enable-wayland-ime
--use-angle=opengl
```

If it takes long time to launch, try add `--disable-gpu` or just use x11
```bash
--ozone-platform-hint=x11
--gtk-version=4
```
### SDDM

If you are using hybrid card (Intel+Nvidia), sddm might not showing on the external screen when you using HDMI, which can be solved by the following conifg:
```bash
# /usr/share/sddm/scripts/Xsetup
xrandr --setprovideroutputsource modesetting NVIDIA-0
```

/etc/sddm.conf
```
[General]
Numlock=on
```

### Dark Theme for gtk widgets
Install `flat-remix-gtk` theme first.

Run the following commands:
```bash
gsettings set org.gnome.desktop.interface gtk-theme Flat-Remix-GTK-Blue-Darkest
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
```

Config files:
```bash
# Both gtk-3.0 and gtk-4.0 config files.
# ~/.config/gtk-3.0/settings.ini
# ~/.config/gtk-4.0/settings.ini
gtk-theme-name = Flat-Remix-GTK-Blue-Darkest
gtk-application-prefer-dark-theme = true
```
