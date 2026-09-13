# Hyprland Desktop

This folder builds the Hyprland desktop.

Hyprland is the program that draws and moves windows. This kind of program is
called a compositor. The desktop also uses:

- `silere-shell` for the bar, menus, popups, and wallpaper picker.
- Vicinae for the app launcher, clipboard history, and Alt+Tab window
  switcher.
- An available hyprshell switcher module, currently disabled while Vicinae is
  being evaluated for Alt+Tab.
- hyprlock for the lock screen.
- hypridle for lock, screen-off, and sleep timers.
- hyprsunset for warmer screen colors at night.

Set `desktopProfile = "hyprland"` for the host in `flake.nix` to turn this
desktop on.

## File Map

Each file has one main job:

- `modules/nixos/hyprland.nix` sets up Hyprland, the login screen, Bluetooth,
  KDE Connect, file access services, and helpers that let apps share the screen
  and choose files.
- `default.nix` joins the Home Manager files together. It also sets shared
  apps, file defaults, and the desktop session group.
- `modules/commands.nix` packages the helper scripts and shares their paths
  with the other files.
- `modules/compositor.nix` controls screens, the mouse, the keyboard, window
  rules, borders, blur, and animations.
- `modules/keybindings.nix` holds the normal keyboard and mouse shortcuts.
- `modules/hyprlock.nix` controls the lock screen.
- `modules/hypridle.nix` controls what happens when the computer is left alone.
- `modules/hyprshell.nix` packages and starts the dedicated Alt+Tab switcher;
  its import is currently commented out in `default.nix`.
- `modules/hyprsunset.nix` controls the night color schedule.
- `modules/session-services.nix` starts the media idle blocker, Caffeine, and
  the KDE Connect tray icon.
- `modules/silere.nix` packages and starts `silere-shell`. It also sends the
  default shell settings into the package.
- `modules/wallpaper.nix` joins awww, Matugen, and hyprlock into one wallpaper
  system.
- `modules/zathura.nix` configures the PDF viewer and its Matugen glass theme.
- `scripts/` holds the Bash code used by the helper commands.
- `../vicinae.nix` sets up Vicinae and starts it with this desktop.

## How Login Works

```text
greetd -> tuigreet -> Hyprland -> hyprland.lua -> hyprland-session.target
```

`greetd` runs the login screen. `tuigreet` asks for the user name and password.
It then starts Hyprland.

Home Manager writes `~/.config/hypr/hyprland.lua`. That file starts
`hyprland-session.target`. A target is a named group of background programs.
This target starts and stops the desktop programs together.

The group includes the shell, Vicinae, wallpaper services, idle tools, KDE
Connect icon, and keyring.

This desktop does not use UWSM.

## Keyboard Shortcuts

Most shortcuts live in `modules/keybindings.nix`. That file also makes the
list shown by the shell, so the real shortcuts and the shown shortcuts come
from the same place.

- Press `Super+/` to open the shortcut list.
- Press `Super+Shift+W` to open the wallpaper picker.
- Press `Super+Space`, or tap `Super`, to open Vicinae.
- Press `Alt+Tab` to switch windows.

`modules/keybindings.nix` maps `Alt+Tab` to Vicinae's searchable window list.
The former hyprshell module remains in the tree, with its import commented out
in `default.nix` for an easy rollback.

## Helper Scripts

The files in `scripts/` are pieces of Bash code. Home Manager wraps each file
with `pkgs.writeShellApplication`. The wrapper adds Bash safety settings and
makes the programs that each script needs available.

- `hypr-shell-screenshot` takes an area, screen, or window screenshot.
- `hypr-shell-record` records an area, screen, or window.
- `hypr-shell-caffeine` turns Caffeine on or off so the computer can stay
  awake.
- `wallpaper-set` applies one image to the desktop, shell colors, and lock
  screen.

## Lock, Screen-Off, and Sleep

hypridle watches for keyboard and mouse use.

- After 10 minutes with no use, it locks the session.
- After 11 minutes, it turns the screens off.
- After 15 minutes, it puts the computer to sleep.

Video or audio playback can block these timers. Caffeine can also block them
until the user turns it off.

## Wallpapers

The wallpaper picker reads `$WALLPAPERS_DIR`. If that value is not set, it
uses `~/Pictures/wallpapers`.

When an image is picked, `wallpaper-set <image-path>` does this:

1. It checks that the image can be read.
2. It gives the image to awww. awww uses a two-second `grow` animation at 60
   frames per second.
3. It gives the image to Matugen. Matugen builds the dark `SchemeContent`
   colors used by `silere-shell`.
4. It converts the image to PNG and saves it at
   `~/.config/hypr/wallpapers/default.png` for hyprlock.

Home Manager creates the PNG the first time if it does not exist. It does not
replace a wallpaper that is already there. At login, the restore service gives
this saved image back to awww.

Home Manager also builds Matugen's config and links it to
`~/.config/matugen/config.toml`. Matugen caching stays off because Matugen
would still rebuild the `SchemeContent` colors used here. The cache would add
files without making this wallpaper path faster.

The picker can be opened with `Super+Shift+W`. It can also be found as
`Wallpapers` in Vicinae.

Zathura also uses Matugen's dark `SchemeTonalSpot` palette. Home Manager
generates its initial colors from the saved wallpaper, and `wallpaper-set`
updates them on later picks. Reopen Zathura to read the updated colors.
Its `on_primary` backgrounds use 55% opacity, with opaque `primary` text;
document hues and embedded image colors remain enabled. Matugen writes
`~/.config/zathura/matugen-colors`, which the Home Manager configuration
includes after its fallback colors.

## Other Desktop Support

- Nautilus opens folders.
- Loupe opens images.
- Papers opens PDF files.
- VLC opens video files.
- Gapless opens audio files.
- udiskie mounts removable drives and shows notices.
- GNOME Keyring stores app secrets.
- Hyprland and GTK helpers let apps share the screen and choose files.

## Checks

Run these commands from the repository root:

```sh
shellcheck -s bash modules/home-manager/hyprland/scripts/*.sh

nix build .#homeConfigurations."olaolu@boreas".activationPackage --no-link
```

## Guides

- [Home Manager Hyprland module](https://github.com/nix-community/home-manager/blob/release-26.05/modules/services/window-managers/hyprland.nix)
- [Hyprland wiki](https://wiki.hypr.land/)
- [Vicinae docs](https://docs.vicinae.com/)
- [Satty](https://github.com/Satty-org/Satty)
- [hyprshell](https://github.com/H3rmt/hyprshell)
