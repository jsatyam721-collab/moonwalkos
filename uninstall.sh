#!/usr/bin/env bash
set -euo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/moonwalk-install"
BACKUP=$(readlink -f "${1:-$STATE/latest}" 2>/dev/null || true)

say() { printf '\033[1;35m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

[[ -n $BACKUP && -f $BACKUP/manifest ]] || { warn "no install record found in $STATE"; exit 1; }

read -rp "Remove MoonwalkOS and restore your files from $BACKUP? [y/N] " r
[[ $r == [yY]* ]] || exit 0

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

if [[ -s $BACKUP/system ]]; then
    say "undoing system pieces (needs sudo)"
    while read -r part; do
        case $part in
        sddm)
            sudo rm -rf /usr/share/sddm/themes/randomplay /etc/sddm.conf.d/zz-moonwalk.conf
            ;;
        plymouth)
            prev=$(cat "$BACKUP/plymouth-previous" 2>/dev/null || true)
            [[ -n $prev && $prev != darth_vader ]] && sudo plymouth-set-default-theme -R "$prev"
            [[ $prev == darth_vader ]] || sudo rm -rf /usr/share/plymouth/themes/darth_vader
            ;;
        grub)
            sudo rm -f /etc/grub.d/09_silent /etc/pacman.d/hooks/90-grub-quiet.hook /usr/local/sbin/grub-quiet-patch
            [[ -f $BACKUP/10_linux.orig ]] && sudo cp -a "$BACKUP/10_linux.orig" /etc/grub.d/10_linux
            sudo grub-mkconfig -o /boot/grub/grub.cfg
            ;;
        esac
    done <"$BACKUP/system"
fi

rm -f "$STATE/latest"
say "done. packages were left installed, remove them with pacman if you want."
