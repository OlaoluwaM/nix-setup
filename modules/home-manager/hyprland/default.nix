{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:

# Beginner orientation:
#
# This is the entry point for the Home Manager side of the Hyprland profile.
# "Entry point" means other config files import this module, and this module
# imports the smaller Hyprland-related files under ./modules/.
#
# This file itself stays thin, mirroring the split the gnome profile uses
# (modules/home-manager/gnome/default.nix + modules/home-manager/gnome/
# modules/*.nix): it declares the top-level options (enable, wallpaper),
# wires up the imports, and owns the handful of settings that genuinely
# belong to the whole profile rather than one subsystem -- the shared
# session target, session-variable plumbing, baseline packages, mime
# defaults, and portals. Everything else lives under ./modules/:
# - modules/commands.nix: shared helper-script packages (screenshot,
#   screenrecord, caffeine) and the local.hyprland.commands option tree
# - modules/compositor.nix: compositor config (monitors, input, decoration,
#   animations, window rules)
# - modules/hyprshell.nix: the available, currently-disabled hyprshell
#   Alt-Tab window switcher daemon
# - modules/keybindings.nix: every Hyprland key chord
# - modules/hyprlock.nix: lock-screen look and behavior
# - modules/hypridle.nix: idle locking behavior
# - modules/hyprsunset.nix: display color temperature schedule
# - modules/session-services.nix: extra Hyprland-session user services
# - modules/silere.nix: the silere-shell Quickshell bar (packaging + user
#   service)
# - modules/wallpaper.nix: the wallpaper pipeline (awww + matugen + hyprlock's
#   stable path) and the Vicinae wallpaper commands
# - modules/zathura.nix: MuPDF-backed document viewing and its glass theme
#
# silere-shell is the sole shell for this profile -- there is no backend
# option, unlike the old Caffyne/Quickshell split this profile tore down.
# silere.nix declares its first-generation defaults; the shell's own
# Settings UI can still override any of them per-key at runtime.
#
# Home Manager source/options:
# https://nix-community.github.io/home-manager/options.xhtml
let
  cfg = config.local.hyprland;
  commands = cfg.commands;
  hyprlandSessionTarget = "hyprland-session.target";

  # Wallpaper folder read by wallpaper.nix's wallpaper-set and the Vicinae
  # wallpaper commands. If WALLPAPERS_DIR is set in the session environment,
  # use that. Otherwise fall back to ~/Pictures/wallpapers.
  wallpapersDir =
    config.home.sessionVariables.WALLPAPERS_DIR or "${config.xdg.userDirs.pictures}/wallpapers";

  # Keep the built-in default at a stable path outside any particular shell's
  # own config directory. hyprlock reads this same path, so the lock screen
  # must not depend on any shell being active before its background exists.
  defaultWallpaperConfigPath = "hypr/wallpapers/default.png";
  defaultWallpaper = "${config.xdg.configHome}/${defaultWallpaperConfigPath}";
in
{
  # Import the focused modules that make up the Hyprland session.
  imports = [
    ./modules/commands.nix
    ./modules/compositor.nix
    ./modules/hypridle.nix
    ./modules/hyprlock.nix
    # Disabled while Vicinae owns Alt+Tab through keybindings.nix. Keep the
    # import here so restoring the dedicated hyprshell switcher is a one-line
    # change rather than rediscovering how it was wired into the profile.
    # ./modules/hyprshell.nix
    ./modules/hyprsunset.nix
    ./modules/keybindings.nix
    ./modules/session-services.nix
    ./modules/silere.nix
    ./modules/wallpaper.nix
    ./modules/zathura.nix
    ../vicinae.nix
  ];

  options.local.hyprland = {
    # Creates the option local.hyprland.enable. Other files can set this to true
    # to enable the whole Home Manager Hyprland profile.
    enable = lib.mkEnableOption "Hyprland configuration";

    wallpaper = lib.mkOption {
      type = lib.types.str;
      default = defaultWallpaper;
      description = ''
        Stable wallpaper path shared by the desktop shell and hyprlock. Prefer
        a Home Manager path over a versioned Nix store path so applications can
        persist the value without retaining an obsolete store generation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    local.vicinae.enable = true;
    local.vicinae.systemd.target = hyprlandSessionTarget;

    # Tells Home Manager which user systemd target represents "the Hyprland
    # desktop session is running." Services such as hypridle, hyprsunset, and
    # Vicinae attach themselves to this same target, so they start when
    # Hyprland starts and stop when the Hyprland session stops. Without one
    # shared target, each service would need its own separate start/stop
    # rules and they could drift out of sync.
    wayland.systemd.target = hyprlandSessionTarget;

    # PAM unlocks the login keyring through greetd. This service keeps the
    # GNOME Keyring Secret Service running for the Hyprland session so apps
    # such as VS Code can store credentials through org.freedesktop.secrets.
    services.gnome-keyring = {
      enable = true;
      components = [ "secrets" ];
    };

    # Home Manager normally attaches its GNOME Keyring service to
    # graphical-session-pre.target. This profile uses its own
    # hyprland-session.target, so attach the service there as well.
    systemd.user.services.gnome-keyring = {
      Unit.PartOf = [ hyprlandSessionTarget ];
      Install.WantedBy = [ hyprlandSessionTarget ];
    };

    # WALLPAPERS_DIR is set via home.sessionVariables (modules/home-manager/
    # dotfiles.nix), which only lands in
    # ~/.nix-profile/etc/profile.d/hm-session-vars.sh. Nothing sources that
    # file for this greetd-launched session: there is no ~/.profile, greetd's
    # worker only tries /etc/profile and $HOME/.profile before exec'ing
    # start-hyprland, and start-hyprland is an ELF binary, not a shell
    # script, so it can never source anything either.
    #
    # Setting it here instead makes Home Manager write it into
    # ~/.config/environment.d/, which every unit the systemd user manager
    # starts inherits, without needing a per-unit Environment= line. Read by
    # the Vicinae wallpaper commands (wallpaper.nix), which resolve a bare
    # filename against this directory before handing it to wallpaper-set.
    #
    # Caveat: environment.d is only read when the systemd user manager itself
    # starts, not on every `home-manager switch`. An already-running session
    # will not pick this up until the next login.
    systemd.user.sessionVariables.WALLPAPERS_DIR = wallpapersDir;

    # Same value, exposed as a commands.nix option (see the re-plumb comment
    # on commands.wallpaperSetScript) so silere.nix's wallpapersDir default
    # -- what the shell's picker scans -- reads this exact expression
    # instead of a second, potentially divergent copy of it.
    local.hyprland.commands.wallpapersDir = wallpapersDir;

    # Baseline user packages for the Hyprland profile. These are not all visible
    # apps; some are fonts and Qt support libraries that make the UI render
    # correctly.
    home.packages = with pkgs; [
      # General font/icon support. This is a stock Hyprland profile with no
      # shell UI, so nothing here depends on Nerd Font glyph icons. The
      # symbols font is kept as a broad fallback for terminal/app text that
      # may still contain those characters. Noto (incl. color emoji) comes
      # from the fontconfig module, which owns the fallback fonts for every
      # profile.
      font-awesome
      nerd-fonts.symbols-only

      nautilus

      # Hyprland session utilities and apps launched by the keybinds above.
      brightnessctl
      commands.caffeineScript
      commands.screenrecordScript
      commands.screenshotScript
      # On PATH for manual terminal use, same as grim/slurp below; the
      # keybound path goes through commands.screenrecordScript, whose own
      # runtimeInputs (commands.nix) already pull this in independently.
      gpu-screen-recorder
      grim
      jq
      libnotify
      # Image viewer for the session. GNOME ships an equivalent as part of the
      # desktop, while Hyprland has to bring its own. Zathura is packaged by
      # modules/zathura.nix; both defaults are declared in xdg.mimeApps below.
      loupe
      mission-center
      papers
      satty
      slurp
      wayland-pipewire-idle-inhibit
      # TUIs behind the shell's escape-hatch rows: wifitui for the wifi
      # details view (local.hyprland.silere.wifiEditCommand, themed by the
      # catppuccin mocha theme.toml declared below), bluetui for the
      # bluetooth details view (btEditCommand). Both open as normal tiles.
      bluetui
      wifitui
      # Behind the Sound section's "Advanced settings" row. The shell finds it
      # by probe (SystemTools.hasPwvucontrol), not by a rendered path, so the
      # row lights up simply because this package is on PATH.
      pwvucontrol
      unstable.wiremix
      unstable.matugen
    ];

    # Catppuccin Mocha for wifitui (auto-discovered: wifitui probes
    # $XDG_CONFIG_HOME via WIFITUI_THEME; we pass --theme explicitly from
    # wifiEditCommand's template instead of a session variable so the theme
    # rides along however the TUI is launched from the shell). Role mapping:
    # lavender selection to match the rice's accent direction, green/red for
    # success/error, peach-to-green signal gradient, blue for saved profiles.
    xdg.configFile."wifitui/theme.toml".text = ''
      # Catppuccin Mocha (https://catppuccin.com/palette) -- single dark
      # variant, so both halves of each [light, dark] pair are identical.
      Primary = ["#b4befe", "#b4befe"] # Lavender
      Subtle = ["#7f849c", "#7f849c"] # Overlay1
      Success = ["#a6e3a1", "#a6e3a1"] # Green
      Error = ["#f38ba8", "#f38ba8"] # Red
      Normal = ["#cdd6f4", "#cdd6f4"] # Text
      Disabled = ["#6c7086", "#6c7086"] # Overlay0
      Border = ["#585b70", "#585b70"] # Surface2
      SignalHigh = ["#a6e3a1", "#a6e3a1"] # Green
      SignalLow = ["#fab387", "#fab387"] # Peach
      Saved = ["#89b4fa", "#89b4fa"] # Blue
    '';

    # Everyday file-type defaults for the Hyprland session, merged into the
    # xdg.mimeApps set that desktop.nix enables. GNOME gets these as stock
    # desktop defaults; outside GNOME they must be declared, or xdg-open falls
    # back to whatever app happens to advertise the type (opening a directory
    # in VS Code, say). Zathura comes from modules/zathura.nix; Loupe,
    # Nautilus, Celluloid, and Gapless come from home.packages.
    xdg.mimeApps.defaultApplications =
      lib.genAttrs [
        "image/png"
        "image/jpeg"
        "image/gif"
        "image/webp"
        "image/svg+xml"
        "image/bmp"
        "image/tiff"
        "image/avif"
      ] (_: "org.gnome.Loupe.desktop")
      // lib.genAttrs [
        "video/mp4"
        "video/x-matroska"
        "video/webm"
        "video/mpeg"
        "video/x-msvideo"
        "video/quicktime"
      ] (_: "io.github.celluloid_player.Celluloid.desktop")
      // lib.genAttrs [
        "audio/mpeg"
        "audio/flac"
        "audio/ogg"
        "audio/x-vorbis+ogg"
        "audio/mp4"
        "audio/x-wav"
      ] (_: "com.github.neithern.g4music.desktop")
      // lib.genAttrs [
        "text/plain"
        "text/x-log"
        "text/markdown"
        "text/x-markdown"
        "application/json"
      ] (_: "org.gnome.TextEditor.desktop")
      // {
        "application/pdf" = "org.pwmt.zathura-pdf-mupdf.desktop";
        "inode/directory" = "org.gnome.Nautilus.desktop";
      };

    home.sessionVariables = {
      # wifitui probes this itself, so a bare `wifitui` in any terminal picks
      # up the catppuccin mocha theme declared above -- the --theme flag in
      # wifiEditCommand stays as belt-and-braces for the shell's launch path,
      # whose service environment doesn't source login-session variables.
      WIFITUI_THEME = "${config.xdg.configHome}/wifitui/theme.toml";
    };

    # udiskie watches removable drives. automount=true means USB drives can show
    # up automatically without manually running mount commands.
    services.udiskie = {
      enable = true;
      automount = true;
      notify = true;
    };

    services.hypridle.systemdTarget = hyprlandSessionTarget;

    services.hyprpolkitagent.enable = true;
  };
}
