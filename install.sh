#!/usr/bin/env bash
set -euo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/moonwalk-install"
BACKUP="$STATE/backup-$(date +%Y%m%d-%H%M%S)"
PACKAGES=1
DOWNLOAD=1
SYSTEM=ask
YES=0

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

install_packages() {
    say "installing packages"
    local -a repo aur
    mapfile -t repo < <(grep -vE '^\s*(#|$)' "$SRC/pkgs/repo.lst")
    mapfile -t aur < <(grep -vE '^\s*(#|$)' "$SRC/pkgs/aur.lst")
    sudo pacman -S --needed --noconfirm "${repo[@]}"

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
}

entries() {
    (cd "$SRC/home" && find .config .local/bin .local/lib .local/share -mindepth 1 -maxdepth 1 | sort)
    printf '%s\n' .local/state/moonwalk .cache/moonwalk
}

install_home() {
    say "saving what gets replaced to $BACKUP"
    mkdir -p "$BACKUP"
    : >"$BACKUP/manifest"
    local e
    while read -r e; do
        if [[ -e $HOME/$e || -L $HOME/$e ]]; then
            mkdir -p "$BACKUP/$(dirname "$e")"
            mv "$HOME/$e" "$BACKUP/$e"
        fi
        printf '%s\n' "$e" >>"$BACKUP/manifest"
    done < <(entries)

    say "copying MoonwalkOS into $HOME"
    cp -a "$SRC/home/." "$HOME/"
    while read -r e; do
        [[ -e $HOME/$e ]] && grep -rIlZ '@HOME@' "$HOME/$e" 2>/dev/null || true
    done <"$BACKUP/manifest" | xargs -0 -r sed -i "s|@HOME@|$HOME|g"
    chmod +x "$HOME"/.local/bin/* "$HOME"/.local/lib/moonwalk/*.sh 2>/dev/null || true
    ln -sfn "$BACKUP" "$STATE/latest"
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

install_system() {
    say "system pieces (these need sudo)"
    : >"$BACKUP/system"

    if ask "Random Play login screen (SDDM on weston)?"; then
        sudo pacman -S --needed --noconfirm sddm weston qt6-multimedia
        sudo rm -rf /usr/share/sddm/themes/randomplay
        sudo cp -r "$SRC/system/sddm/randomplay" /usr/share/sddm/themes/
        sudo install -Dm644 "$SRC/system/sddm/zz-moonwalk.conf" /etc/sddm.conf.d/zz-moonwalk.conf
        echo sddm >>"$BACKUP/system"
        if grep -qs '^Current=' /etc/sddm.conf; then
            warn "/etc/sddm.conf sets its own theme and wins over ours, remove its Current= line"
        fi
        systemctl is-enabled display-manager.service >/dev/null 2>&1 || sudo systemctl enable sddm.service
    fi

    if ask "Darth Vader boot splash (Plymouth)?"; then
        sudo pacman -S --needed --noconfirm plymouth
        plymouth-set-default-theme >"$BACKUP/plymouth-previous" 2>/dev/null || true
        sudo rm -rf /usr/share/plymouth/themes/darth_vader
        sudo cp -r "$SRC/system/plymouth/darth_vader" /usr/share/plymouth/themes/
        sudo plymouth-set-default-theme -R darth_vader
        echo plymouth >>"$BACKUP/system"
        grep -q plymouth /etc/mkinitcpio.conf || warn "add 'plymouth' to HOOKS in /etc/mkinitcpio.conf and 'splash' to your kernel line to see it"
    fi

    if [[ -f /boot/grub/grub.cfg && -f /etc/grub.d/10_linux ]] && ask "Hide the GRUB boot text?"; then
        sudo cp -a /etc/grub.d/10_linux "$BACKUP/10_linux.orig"
        sudo install -m755 "$SRC/system/grub/09_silent" /etc/grub.d/09_silent
        sudo install -Dm644 "$SRC/system/grub/90-grub-quiet.hook" /etc/pacman.d/hooks/90-grub-quiet.hook
        sudo install -Dm755 "$SRC/system/grub/grub-quiet-patch" /usr/local/sbin/grub-quiet-patch
        sudo /usr/local/sbin/grub-quiet-patch
        echo grub >>"$BACKUP/system"
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
