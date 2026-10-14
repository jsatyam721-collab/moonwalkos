#!/usr/bin/env bash
[[ $MOONWALK_SHELL_INIT -ne 1 ]] && eval "$(moonwalk-shell init)"

notify-send -a "Deprecation Notice" "moonwalk-launch.sh is deprecated. Please use moonwalk-shell open instead." -i dialog-information

moonwalk-shell open "$@"
