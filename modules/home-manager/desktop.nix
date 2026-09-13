{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.desktop;
  fonts = config.local.fonts;

  fontSpec = font: "${font.name} ${toString font.size}";

  gtkTheme = {
    name = "Adwaita-dark";
    package = pkgs.gnome-themes-extra;
  };

  cursorTheme = {
    name = "catppuccin-mocha-dark-cursors";
    package = pkgs.catppuccin-cursors.mochaDark;
    size = 24;
  };

  iconTheme = {
    name = "Colloid-Dark";
    package = pkgs.colloid-icon-theme;
  };
in
{
  imports = [
    ./theme.nix
    ./desktop-applications
    ./gnome
    ./hyprland
  ];
  # This option should mirror what's in ../../modules/nixos/desktop.nix
  options.local.desktop = {
    profile = lib.mkOption {
      type = lib.types.enum [
        "gnome"
        "hyprland"
        "none"
      ];
      default = "gnome";
      example = "hyprland";
      description = ''
        Home Manager desktop profile to enable for this user.

        Use "gnome" for GNOME user packages and settings, "hyprland" for
        Hyprland user packages and settings, and "none" for users without a
        local graphical session.
      '';
    };
  };

  config = lib.mkMerge [
    {
      local.gnome.enable = cfg.profile == "gnome";
      local.hyprland.enable = cfg.profile == "hyprland";
    }

    (lib.mkIf (cfg.profile != "none") {
      # Default applications for every desktop profile, codifying the explicit
      # choices from the Fedora install's user-level mimeapps.list. Stock GNOME
      # defaults (Evince, Loupe, Totem, Nautilus, ...) are deliberately not
      # pinned: GNOME ships those anyway, and pinning them would leave dangling
      # entries on the Hyprland profile.
      #
      # mimeapps.list is the freedesktop-standard mechanism, honored by GNOME,
      # Hyprland (via xdg-open and the portals), and anything else that opens
      # links or files. Note this makes the file Home Manager-managed: changing
      # default apps in GNOME Settings or "Open With" dialogs won't stick;
      # change it here instead.
      xdg.mimeApps = {
        enable = true;

        # Exclude Readest from the default associations for these MIME types
        associations.removed = lib.genAttrs [
          "text/plain"
          "text/markdown"
          "application/pdf"
          "application/epub+zip"
        ] (_: [ "com.bilingify.readest.desktop" ]);

        defaultApplications =
          # Firefox owns web content and the browser scheme handlers. It is
          # installed system-wide by the NixOS config (programs.firefox.enable).
          # The x-extension-* entries are Firefox-convention pseudo-types for
          # local HTML-ish files; about/unknown are what GNOME consults when
          # deciding what "the default browser" is.
          lib.genAttrs [
            "text/html"
            "application/xhtml+xml"
            "application/x-extension-htm"
            "application/x-extension-html"
            "application/x-extension-shtml"
            "application/x-extension-xhtml"
            "application/x-extension-xht"
            "x-scheme-handler/http"
            "x-scheme-handler/https"
            "x-scheme-handler/about"
            "x-scheme-handler/unknown"
          ] (_: "firefox.desktop")
          // {
            # TeX and JSON sources open in VS Code (vscode-fhs ships
            # code.desktop). JSON used GNOME Text Editor on Fedora, but VS Code
            # works on every profile.
            "text/x-tex" = "code.desktop";
            "application/json" = "code.desktop";

            # slack:// deep links (the nixpkgs slack package ships slack.desktop).
            "x-scheme-handler/slack" = "slack.desktop";

            # Keep GNOME's native email launcher and mailto links deterministic
            # across desktop profiles.
            "x-scheme-handler/mailto" = "proton-mail.desktop";

            # claude-cli:// OAuth callbacks. The claude-code package ships no
            # desktop file — the CLI writes claude-code-url-handler.desktop
            # into ~/.local/share/applications at runtime. It can no longer
            # register the scheme itself (mimeapps.list is read-only under
            # Home Manager), so the association is pinned here.
            "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
          };

        # The gnome module contributes GSConnect's sms:/tel: associations here;
        # HM merges xdg.mimeApps contributions across modules.
      };

      # For terminal tools that read $BROWSER instead of going through xdg-open.
      home.sessionVariables.BROWSER = "firefox";

      # Shared app theming for graphical desktop sessions.
      gtk = {
        enable = true;
        colorScheme = "dark";
        cursorTheme = cursorTheme;
        iconTheme = iconTheme;
        theme = gtkTheme;
        font = {
          name = fonts.ui.name;
          size = fonts.ui.size;
        };
        gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
        gtk4 = {
          theme = gtkTheme;
          extraConfig.gtk-application-prefer-dark-theme = true;
        };
      };

      dconf.settings."org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        cursor-size = cursorTheme.size;
        cursor-theme = cursorTheme.name;
        document-font-name = fontSpec fonts.document;
        font-name = fontSpec fonts.ui;
        gtk-theme = gtkTheme.name;
        icon-theme = iconTheme.name;
        monospace-font-name = fontSpec fonts.mono;
      };

      home.pointerCursor = cursorTheme // {
        gtk.enable = true;
        hyprcursor.enable = true;
        x11.enable = true;
      };

      home.sessionVariables = {
        XCURSOR_SIZE = toString cursorTheme.size;
        XCURSOR_THEME = cursorTheme.name;
      };

      qt = {
        enable = true;
        platformTheme.name = "adwaita";
        style.name = "adwaita-dark";
        qt5ctSettings.Fonts = {
          fixed = "\"${fonts.mono.family},${toString fonts.mono.size}\"";
          general = "\"${fonts.ui.family},${toString fonts.ui.size}\"";
        };
        qt6ctSettings.Fonts = {
          fixed = "\"${fonts.mono.family},${toString fonts.mono.size}\"";
          general = "\"${fonts.ui.family},${toString fonts.ui.size}\"";
        };
      };
    })
  ];
}
