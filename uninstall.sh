#!/usr/bin/env bash
set -euo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/moonwalk-install"
YES=0
FROM=

usage() {
    cat <<EOF
Usage: ./uninstall.sh [-y] [backup-folder]

Removes MoonwalkOS and puts back what install.sh saved. Without a folder it
uses the latest install in $STATE/.
Packages stay installed.
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
    -y | --yes) YES=1 ;;
    -h | --help) usage; exit 0 ;;
    -*) usage; exit 1 ;;
    *) FROM=$1 ;;
    esac
    shift
done

BACKUP=$(readlink -f "${FROM:-$STATE/latest}" 2>/dev/null || true)
STAMP=$(date +%Y%m%d-%H%M%S)
ASIDE="$BACKUP/uninstalled-$STAMP"

say() { printf '\033[1;35m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
ask() {
    ((YES)) && return 0
    local r
    read -rp "   $1 [y/N] " r </dev/tty
    [[ $r == [yY]* ]]
}

[[ -n $BACKUP && -f $BACKUP/manifest ]] || { warn "no install record found in ${FROM:-$STATE}"; exit 1; }

ask "Remove MoonwalkOS and restore your files from $BACKUP?" || exit 0

say "removing MoonwalkOS files and putting yours back"
while read -r e; do
    [[ $e == .config/?* || $e == .local/bin/?* || $e == .local/lib/?* || $e == .local/share/?* || $e == .local/state/moonwalk || $e == .cache/moonwalk ]] || continue
    [[ $e != *..* ]] || continue
    rm -rf "${HOME:?}/$e"
    if [[ -e $BACKUP/$e || -L $BACKUP/$e ]]; then
        mkdir -p "$HOME/$(dirname "$e")"
        mv "$BACKUP/$e" "$HOME/$e"
    fi
done <"$BACKUP/manifest"

# settings the theme switcher edited in place: what's there now is set aside
# (not deleted), and the copy from before the install goes back
if [[ -s $BACKUP/touched ]]; then
    say "restoring your gtk / qt / cursor settings"
    while read -r e; do
        [[ -n $e && $e != *..* && $e != /* ]] || continue
        if [[ -e $HOME/$e || -L $HOME/$e ]]; then
            mkdir -p "$ASIDE/$(dirname "$e")"
            mv "$HOME/$e" "$ASIDE/$e"
        fi
        if [[ -e $BACKUP/touched.d/$e || -L $BACKUP/touched.d/$e ]]; then
            mkdir -p "$HOME/$(dirname "$e")"
            mv "$BACKUP/touched.d/$e" "$HOME/$e"
        fi
    done <"$BACKUP/touched"
    [[ -d $ASIDE ]] && say "the MoonwalkOS versions of those are in $ASIDE"
fi
if [[ -f $BACKUP/dconf-interface.ini ]] && command -v dconf >/dev/null; then
    { dconf reset -f /org/gnome/desktop/interface/ &&
        dconf load /org/gnome/desktop/interface/ <"$BACKUP/dconf-interface.ini"; } ||
        warn "couldn't restore gtk interface settings, run: dconf load /org/gnome/desktop/interface/ < $BACKUP/dconf-interface.ini"
fi

undo_plymouth() {
    local prev saved="$BACKUP/plymouth-theme/darth_vader" live=/usr/share/plymouth/themes/darth_vader
    prev=$(cat "$BACKUP/plymouth-previous" 2>/dev/null || true)
    if [[ -n $prev && $prev != darth_vader ]]; then
        sudo plymouth-set-default-theme -R "$prev"
        sudo rm -rf "$live"
        if [[ -d $saved ]]; then
            sudo cp -r "$saved" "$live"
        fi
    elif [[ $prev == darth_vader ]]; then
        # you had darth_vader before: put your own copy back, and only rebuild
        # the initramfs if it differs from ours
        if [[ -d $saved ]] && ! diff -rq "$saved" "$live" >/dev/null 2>&1; then
            sudo rm -rf "$live"
            sudo cp -r "$saved" "$live"
            sudo plymouth-set-default-theme -R darth_vader
        fi
    else
        warn "couldn't tell which boot splash you had before, so darth_vader stays."
        warn "to change it: sudo plymouth-set-default-theme -R <theme> (plymouth-set-default-theme -l lists them)"
    fi
}

undo_grub() {
    sudo rm -f /etc/grub.d/09_silent /etc/pacman.d/hooks/90-grub-quiet.hook /usr/local/sbin/grub-quiet-patch
    if [[ -f $BACKUP/10_linux.orig ]]; then
        local was now
        was=$(cat "$BACKUP/grub-version" 2>/dev/null || true)
        now=$(pacman -Q grub 2>/dev/null || true)
        if [[ -n $was && $was == "$now" ]]; then
            sudo install -m755 "$BACKUP/10_linux.orig" /etc/grub.d/10_linux
        else
            # grub was upgraded since (or the version wasn't recorded): the saved
            # 10_linux may be older than the installed grub, so don't use it
            warn "grub changed since MoonwalkOS was installed, so the saved /etc/grub.d/10_linux may not match it."
            if ask "Reinstall the grub package to get a clean 10_linux? (your /etc/default/grub, theme and bootloader stay as they are)"; then
                sudo pacman -S --noconfirm grub
            else
                warn "kept the patched 10_linux, it boots normally and only hides the 'Loading Linux' text."
            fi
        fi
    fi
    if sudo grub-mkconfig -o /boot/grub/grub.cfg.new && sudo grub-script-check /boot/grub/grub.cfg.new; then
        sudo mv /boot/grub/grub.cfg.new /boot/grub/grub.cfg
    else
        sudo rm -f /boot/grub/grub.cfg.new
        warn "the new grub.cfg didn't pass grub-script-check, your current grub.cfg was left untouched"
    fi
}

if [[ -s $BACKUP/system ]]; then
    say "undoing system pieces (needs sudo)"
    while read -r part <&3; do
        case $part in
        sddm)
            sudo rm -rf /usr/share/sddm/themes/randomplay /etc/sddm.conf.d/zz-moonwalk.conf
            ;;
        sddm-enabled)
            # install turned SDDM on because no login manager was enabled
            sudo systemctl disable sddm.service
            ;;
        plymouth) undo_plymouth ;;
        grub) undo_grub ;;
        esac
    done 3<"$BACKUP/system"
fi

[[ $(readlink -f "$STATE/latest" 2>/dev/null) == "$BACKUP" ]] && rm -f "$STATE/latest"
say "done. packages were left installed, remove them with pacman if you want."
say "the backup folder $BACKUP can be deleted once you're happy."
