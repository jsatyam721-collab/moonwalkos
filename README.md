# MoonwalkOS

My Hyprland setup, packaged so anyone on Arch can run it. It started as a fork of
[HyDE](https://github.com/HyDE-Project/HyDE) and grew its own stuff on top.

What's in it:

- **Wallpaper wheel** (`Super+Shift+W`), a radial picker that burns the old wallpaper away
- **Mogo** (`Super+A`), app launcher built around a spinning planet
- **Phone** (`Super+N`), wifi / bluetooth / audio / quick settings
- **Comic music player** (`Super+M`), full-screen comic page for whatever is playing
- **Power menu** and a **CRT power-off** on logout (`Super+Delete`) that hands over to
  the login screen
- **Random Play** SDDM login, a CRT TV in a video store that you log in through
- Waybar layout with live CPU / GPU temperature and load
- 14 themes with wallbash colors, Darth Vader boot splash, silent GRUB

## Install

You need Arch Linux (or something Arch based) and a normal user with sudo.

```sh
git clone <this repo> moonwalkos
cd moonwalkos
./install.sh
```

It installs the packages (official repos + AUR, it builds `yay` if you don't have an AUR
helper), copies everything into your home folder, sets up the python/lua environments and
downloads the theme wallpapers, GTK themes, icons and cursors.

At the end it asks if you want the system parts too (login screen, boot splash, silent
GRUB). Those are optional and each one asks separately.

When it's done, log out and pick **Hyprland (uwsm-managed)** on the login screen.

Options:

```
--no-packages   skip pacman / AUR
--no-download   skip downloading theme assets
--system        go straight to the system parts
--no-system     don't touch anything outside $HOME
-y, --yes       say yes to everything
```

## Your old config

Nothing gets deleted. Every folder or file the installer replaces is moved to
`~/.local/state/moonwalk-install/backup-<date>/` first.

```sh
./uninstall.sh
```

removes MoonwalkOS and puts your files back, and undoes the system parts if you
installed them. Packages stay installed.

## Notes

- The Darth Vader splash needs `plymouth` in your mkinitcpio `HOOKS` and `splash` on
  the kernel line. The installer tells you if it's missing.
- The GPU module in Waybar only shows something on NVIDIA.
- Themes come from the HyDE gallery, so `moonwalk-shell theme.import.py --fetch all` is
  how you re-download them later.

## License

GPL-3.0, same as HyDE. See [CREDITS.md](CREDITS.md) for everything that isn't mine.
