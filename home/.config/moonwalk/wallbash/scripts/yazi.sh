#!/usr/bin/env bash

if ! source "$(which moonwalk-shell)"; then
    echo "[wallbash] yazi :: Error: moonwalk-shell not found."
    exit 1
fi

confDir="${confDir:-$XDG_CONFIG_HOME}"
cacheDir="${cacheDir:-$XDG_CACHE_HOME/moonwalk}"
YAZI_THEME="${confDir}/yazi/theme.toml"
YAZI_DCOL="${cacheDir}/wallbash/yazi"

if command -v yazi &>/dev/null; then
    cp "${YAZI_DCOL}" "${YAZI_THEME}"
fi
