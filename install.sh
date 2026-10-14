#!/usr/bin/env bash
set -euo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/moonwalk-install"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$STATE/backup-$STAMP"
PACKAGES=1
DOWNLOAD=1
SYSTEM=ask
YES=0

# files the theme switcher edits in place (not shipped in home/), copied before
# the first theme apply so uninstall can put them back
TOUCHED=(
    .config/gtk-3.0/settings.ini
    .config/gtk-4.0
    .config/qt5ct/qt5ct.conf
    .config/qt6ct/qt6ct.conf
    .config/kdeglobals
    .config/Kvantum
    .config/xsettingsd/xsettingsd.conf
    .gtkrc-2.0
    .Xresources
    .Xdefaults
    .icons/default/index.theme
    .local/share/icons/default/index.theme
    .local/share/flatpak/overrides/global
)

usage() {
    cat <<EOF
Usage: ./install.sh [options]

  --no-packages   don't install anything with pacman / the AUR
  --no-download   skip downloading theme wallpapers / icons (do it later)
  --system        also set up the login screen, boot splash and silent GRUB
  --no-system     never touch anything outside your home folder
  -y, --yes       answer yes to every question
  -h, --help      show this

Everything it replaces in your home folder is moved to
$STATE/ first, and ./uninstall.sh puts it back.
Running it again updates MoonwalkOS and keeps the first backup of your files.
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
    --no-packages) PACKAGES=0 ;;
    --no-download) DOWNLOAD=0 ;;
    --system) SYSTEM=yes ;;
    --no-system) SYSTEM=no ;;
    -y | --yes) YES=1 ;;
    -h | --help) usage; exit 0 ;;
    *) usage; exit 1 ;;
    esac
    shift
done

say() { printf '\033[1;35m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
ask() {
    ((YES)) && return 0
    local r
    read -rp "   $1 [y/N] " r
    [[ $r == [yY]* ]]
}

[[ $EUID -ne 0 ]] || { warn "run this as your normal user, not root"; exit 1; }
command -v pacman >/dev/null || { warn "MoonwalkOS is made for Arch Linux (pacman not found)"; exit 1; }

# an earlier install keeps its backup: re-running must never back up our own
# files over the user's originals
REINSTALL=0
if [[ -f $STATE/latest/manifest ]]; then
    BACKUP=$(readlink -f "$STATE/latest")
    REINSTALL=1
fi

install_packages() {
    say "installing packages"
    local -a list repo=() aur confirm=()
    ((YES)) && confirm=(--noconfirm)
    mapfile -t list < <(grep -vE '^\s*(#|$)' "$SRC/pkgs/repo.lst")
    mapfile -t aur < <(grep -vE '^\s*(#|$)' "$SRC/pkgs/aur.lst")

    # names the sync databases don't know go to the AUR helper instead,
    # so one misplaced name can't fail the whole pacman call
    local -A known=()
    local p
    while read -r p; do known[$p]=1; done < <(pacman -Slq)
    for p in "${list[@]}"; do
        if [[ -n ${known[$p]:-} ]]; then
            repo+=("$p")
        else
            aur+=("$p")
        fi
    done

    if ! sudo pacman -S --needed "${confirm[@]}" "${repo[@]}"; then
        warn "pacman failed. if it couldn't download, run 'sudo pacman -Syu' and try again."
        warn "if it stopped on a conflict (like pulseaudio vs pipewire-pulse), run without -y and let it replace the package."
        exit 1
    fi

    local helper
    helper=$(command -v paru || command -v yay || true)
    if [[ -z $helper ]]; then
        say "no AUR helper found, building yay"
        sudo pacman -S --needed --noconfirm base-devel git
        local tmp
        tmp=$(mktemp -d)
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
        helper=$(command -v yay)
    fi
    "$helper" -S --needed --noconfirm "${aur[@]}"

    # the theme switcher needs hyq to turn hypr.theme into lua
    if ! command -v hyq >/dev/null; then
        "$helper" -S --needed --noconfirm hyprquery ||
            "$helper" -S --needed --noconfirm hyprquery-git ||
            warn "couldn't install hyprquery (hyq), theme switching won't work until it's installed"
    fi
}

entries() {
    (cd "$SRC/home" && {
        find .config .local/bin .local/lib .local/share -mindepth 1 -maxdepth 1 ! -name environment.d ! -name sounds
        find .config/environment.d .local/share/sounds -mindepth 1 -maxdepth 1
    } | sort)
    printf '%s\n' .local/state/moonwalk .cache/moonwalk
}

save_touched() {
    # copied, not moved: these stay in use and the theme switcher edits them
    touch "$BACKUP/touched"
    local e
    for e in "${TOUCHED[@]}"; do
        grep -qxF "$e" "$BACKUP/touched" && continue
        if [[ -e $HOME/$e || -L $HOME/$e ]]; then
            mkdir -p "$BACKUP/touched.d/$(dirname "$e")"
            cp -a "$HOME/$e" "$BACKUP/touched.d/$e"
        fi
        printf '%s\n' "$e" >>"$BACKUP/touched"
    done
    if [[ ! -e $BACKUP/dconf-interface.ini ]] && command -v dconf >/dev/null; then
        dconf dump /org/gnome/desktop/interface/ >"$BACKUP/dconf-interface.ini" 2>/dev/null ||
            rm -f "$BACKUP/dconf-interface.ini"
    fi
}

install_home() {
    mkdir -p "$BACKUP"
    touch "$BACKUP/manifest"
    # linked first, so an install that dies halfway can still be undone
    ln -sfn "$BACKUP" "$STATE/latest"

    local e old="$BACKUP/reinstall-$STAMP"
    if ((REINSTALL)); then
        say "updating MoonwalkOS, your original files stay in $BACKUP"
    else
        say "saving what gets replaced to $BACKUP"
    fi
    while read -r e; do
        if grep -qxF "$e" "$BACKUP/manifest"; then
            # ours from the last install: keep any edits made since, out of the way
            if [[ -e $SRC/home/$e ]] && [[ -e $HOME/$e || -L $HOME/$e ]]; then
                mkdir -p "$old/$(dirname "$e")"
                mv "$HOME/$e" "$old/$e"
            fi
            continue
        fi
        if [[ -e $HOME/$e || -L $HOME/$e ]]; then
            mkdir -p "$BACKUP/$(dirname "$e")"
            mv "$HOME/$e" "$BACKUP/$e"
        fi
        printf '%s\n' "$e" >>"$BACKUP/manifest"
    done < <(entries)
    [[ -d $old ]] && say "your edits to the previous MoonwalkOS files are in $old"
    save_touched

    say "copying MoonwalkOS into $HOME"
    cp -a "$SRC/home/." "$HOME/"
    while read -r e; do
        [[ -e $HOME/$e ]] && grep -rIlZ '@HOME@' "$HOME/$e" 2>/dev/null || true
    done <"$BACKUP/manifest" | xargs -0 -r sed -i "s|@HOME@|$HOME|g"
    # only our own scripts, not whatever else lives in ~/.local/bin
    local f
    while read -r f; do
        chmod +x "$HOME/.local/bin/$f"
    done < <(find "$SRC/home/.local/bin" -maxdepth 1 -type f -printf '%f\n')
    chmod +x "$HOME"/.local/lib/moonwalk/*.sh 2>/dev/null || true
}

setup_engine() {
    export PATH="$HOME/.local/bin:$PATH"
    say "setting up the python and lua environments"
    moonwalk-shell pyinit || warn "pyinit failed, run 'moonwalk-shell pyinit' later"
    moonwalk-shell luainit || warn "luainit failed, run 'moonwalk-shell luainit' later"
    ((DOWNLOAD)) || return 0
    say "downloading theme wallpapers, gtk themes, icons and cursors"
    moonwalk-shell theme.import.py --fetch all ||
        warn "theme download didn't finish, run 'moonwalk-shell theme.import.py --fetch all' later"
}

mark() { grep -qxF "$1" "$BACKUP/system" || echo "$1" >>"$BACKUP/system"; }

install_system() {
    say "system pieces (these need sudo)"
    touch "$BACKUP/system"

    if ask "Random Play login screen (SDDM on weston)?"; then
        sudo pacman -S --needed --noconfirm sddm weston qt6-multimedia
        sudo rm -rf /usr/share/sddm/themes/randomplay
        sudo cp -r "$SRC/system/sddm/randomplay" /usr/share/sddm/themes/
        sudo install -Dm644 "$SRC/system/sddm/zz-moonwalk.conf" /etc/sddm.conf.d/zz-moonwalk.conf
        mark sddm
        if grep -qs '^Current=' /etc/sddm.conf; then
            warn "/etc/sddm.conf sets its own theme and wins over ours, remove its Current= line"
        fi
        local dm
        dm=$(readlink -e /etc/systemd/system/display-manager.service || true)
        if [[ -z $dm ]]; then
            sudo systemctl enable sddm.service
            mark sddm-enabled
        elif [[ ${dm##*/} != sddm.service ]]; then
            warn "${dm##*/} is your login manager, the Random Play screen only shows with SDDM."
            warn "to switch: sudo systemctl disable ${dm##*/} && sudo systemctl enable sddm"
        fi
    fi

    if ask "Darth Vader boot splash (Plymouth)?"; then
        sudo pacman -S --needed --noconfirm plymouth
        # the first install's answer is the one uninstall goes back to
        if ! grep -qxF plymouth "$BACKUP/system"; then
            plymouth-set-default-theme >"$BACKUP/plymouth-previous" 2>/dev/null || true
            # a darth_vader you already had is kept, uninstall puts it back
            if [[ -d /usr/share/plymouth/themes/darth_vader ]]; then
                mkdir -p "$BACKUP/plymouth-theme"
                sudo tar -C /usr/share/plymouth/themes -cf - darth_vader | tar -C "$BACKUP/plymouth-theme" -xf -
            fi
        fi
        sudo rm -rf /usr/share/plymouth/themes/darth_vader
        sudo cp -r "$SRC/system/plymouth/darth_vader" /usr/share/plymouth/themes/
        sudo plymouth-set-default-theme -R darth_vader
        mark plymouth
        grep -q plymouth /etc/mkinitcpio.conf || warn "add 'plymouth' to HOOKS in /etc/mkinitcpio.conf and 'splash' to your kernel line to see it"
    fi

    if [[ -f /boot/grub/grub.cfg && -f /etc/grub.d/10_linux ]] && ask "Hide the GRUB boot text?"; then
        # only the first time: a later run would save an already patched copy
        if [[ ! -e $BACKUP/10_linux.orig ]]; then
            sudo cat /etc/grub.d/10_linux >"$BACKUP/10_linux.orig"
            pacman -Q grub >"$BACKUP/grub-version" 2>/dev/null || true
        fi
        sudo install -m755 "$SRC/system/grub/09_silent" /etc/grub.d/09_silent
        sudo install -Dm644 "$SRC/system/grub/90-grub-quiet.hook" /etc/pacman.d/hooks/90-grub-quiet.hook
        sudo install -Dm755 "$SRC/system/grub/grub-quiet-patch" /usr/local/sbin/grub-quiet-patch
        sudo /usr/local/sbin/grub-quiet-patch
        mark grub
    fi
}

cat <<'EOF'

   M O O N W A L K O S

EOF

((PACKAGES)) && install_packages
install_home
setup_engine

case $SYSTEM in
yes) install_system ;;
ask) ask "Set up the login screen / boot splash / silent GRUB too?" && install_system ;;
esac

say "done. log out, pick 'Hyprland (uwsm-managed)' and log back in."
say "your old files are in $BACKUP, './uninstall.sh' restores them."
