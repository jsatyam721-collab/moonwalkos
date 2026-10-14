# Credits

## Code and themes

- **HyDE** by HyDE-Project, GPL-3.0. MoonwalkOS is a fork of it: the engine in
  `.local/lib/moonwalk`, the Lua framework and most Waybar modules come from there.
  https://github.com/HyDE-Project/HyDE
  Some HyDE files keep "The HyDE Project" in their copyright headers; those notices stay.
- **hyprdots** by prasanthrangan, GPL-3.0, the project HyDE grew out of. The rofi
  launcher styles (`.local/share/moonwalk/rofi/themes/style_*.rasi`, `wallbash.rasi`) come
  from there. https://github.com/prasanthrangan/hyprdots
- **Theme gallery** (wallpapers, GTK themes, icons, cursors), downloaded at install time
  from https://github.com/HyDE-Project/hyde-gallery. Each theme belongs to its authors,
  listed in that repo. The theme configs, Kvantum themes and logos for the bundled themes in
  `.config/moonwalk/themes/` (Catppuccin, Rosé Pine, Tokyo Night, Gruvbox, Nordic and
  others) also come from the gallery. Catppuccin is MIT, https://github.com/catppuccin
- **tinytoml** by Fourier Transformer, MIT (license at the top of
  `.local/share/hypr/lua/lib/toml.lua`). https://github.com/FourierTransformer/tinytoml
- **hyproled** by mklan, BSD-3-Clause, the basis of `.config/hypr/shaders/oled-saver.frag`
  (license in the file). https://github.com/mklan/hyproled
- **Blue light filter shader** (`.config/hypr/shaders/blue-light-filter.frag`), from
  https://github.com/hyprwm/Hyprland/issues/1140#issuecomment-1335128437, with a colour
  temperature function from https://www.shadertoy.com/view/4sc3D7 (also in `custom.frag`).
- **Hyprlock layouts** in `.config/hypr/hyprlock/`, adapted by the HyDE Project:
  `greetd.conf` and `greetd-wallbash.conf` by Mahaveer Gurjar
  (https://github.com/mahaveergurjar/Hyprlock-Dots), `SF Pro.conf` by Vivek Rajan
  (https://github.com/MrVivekRajan/Hyprlock-Styles), `Arfan on Clouds.conf` by Arfan on
  Clouds (https://github.com/arfan-on-clouds/hyprclouds).
- **"Classic" animation preset** (`.local/share/hypr/lua/animations/classic.lua`) from ML4W
  by Stephan Raabe, GPL-3.0. https://github.com/mylinuxforwork/dotfiles
- **ChromiumPywal** by metafates, the idea behind the Chromium theme generator in
  `.config/moonwalk/wallbash/scripts/chrome.sh`. https://github.com/metafates/ChromiumPywal
- **Darth Vader Plymouth theme** by Aditya Shakya (adi1090x), GPL-3.0.
  https://github.com/adi1090x/plymouth-themes

## Fonts

- **Silkscreen** by Jason Kottke, SIL Open Font License 1.1 (license in
  `.config/musicwidget/fonts/OFL.txt`). https://github.com/googlefonts/silkscreen
- **Installed from Arch packages**, not bundled: JetBrains Mono and JetBrainsMono Nerd Font
  (OFL 1.1), Noto (OFL 1.1), Nunito (OFL 1.1).
- **Downloaded on first use by some hyprlock layouts**, not bundled: Anurati, Inter (OFL 1.1),
  IBM Plex Sans (OFL 1.1), Alfa Slab One (OFL 1.1) and SF Pro Display. SF Pro Display is
  Apple's font under Apple's own license; `SF Pro.conf`, `Arfan on Clouds.conf` and the
  `macos.css` Waybar style use it.

## Images and video

These are used under fair use for a personal, non-commercial rice. All rights stay with
their owners. If you own one of them and want it gone, open an issue and I'll remove it.

| Where | What | Source / owner |
|---|---|---|
| Random Play login (`system/sddm/randomplay/room.png`) | video store room | Random Play from *Zenless Zone Zero*, © HoYoverse. Upscaled. |
| Random Play login (`tv.mp4`) | clip playing on the TV | "Chainsmoker Cat References" by The Victory Over Himself, https://www.youtube.com/watch?v=BENouaA1vmo |
| Lock screen (`.local/share/mjlock/moonwalk.mp4`) | moonwalk silhouette | Michael Jackson, *Billie Jean* live at Motown 25 (1983), official 4K remaster, © the Michael Jackson Estate and the respective rights holders. Cut out and composited. |
| Lock screen moon (composited into `moonwalk.mp4`) | full moon photo | "FullMoon2010" by Gregory H. Revera, CC BY-SA 3.0, Wikimedia Commons |
| Michael theme (`.config/moonwalk/themes/Michael/wallpapers`) | wallpapers | Michael Jackson photos via https://www.wallpaperflare.com |
| Music player (`.config/musicwidget/stewie.webp`) | dancing Stewie | *Family Guy*, © 20th Television. Green screen by Green Screen VFX, https://www.youtube.com/watch?v=jprsec2i-2U |
| Phone (`.config/phone/wallpaper.jpg`) | hazmat wallpaper | *Breaking Bad*, © Sony Pictures Television / AMC |
| Mogo (`.config/mogo/art/dl/2k_haumea_fictional.jpg`) | planet texture | "Haumea (fictional)" by Solar System Scope, CC BY 4.0, https://www.solarsystemscope.com/textures/ |

Everything else (wallpaper wheel, Mogo, phone, power menu, CRT effects, music player,
Random Play theme code, Waybar layout and scripts) is my own work, GPL-3.0 like the rest.

<!-- To confirm: source of .local/share/sounds/notification.mp3; that .config/phone/matte.png
     and system/sddm/randomplay/knob.png are original; source of the Michael wallpapers not
     named wallpaperflare.com_*. -->
