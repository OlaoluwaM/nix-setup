{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.local.hyprland;
  theme = config.local.theme.colors;

  # Fallback colors before the first Matugen palette is generated.
  pageBackground = "rgba(0, 0, 0, 0.55)";
  # Use neutral near-white for document text to improve reading contrast.
  pageForeground = "#f5f5f5";
  # Keep transient controls more opaque than the document surface.
  controlBackground = "rgba(0, 0, 0, 0.78)";
  transparentBackground = "rgba(0, 0, 0, 0)";
in
{
  config = lib.mkIf cfg.enable {
    programs.zathura = {
      enable = true;

      # Keep PDF rendering independent of Papers' Poppler/GTK path.
      package = pkgs.zathura.override { useMupdf = true; };

      options = {
        "adjust-open" = "best-fit";
        "selection-clipboard" = "clipboard";
        guioptions = "s"; # Show the statusbar by default. The inputbar can always be shown when needed.

        # Recolor maps the document's light pixels to a tinted surface and its
        # dark pixels to opaque text. App-provided alpha lets Hyprland blur the
        # wallpaper without reducing glyph opacity.
        recolor = true;
        "recolor-lightcolor" = pageBackground;
        "recolor-darkcolor" = pageForeground;
        "recolor-keephue" = true;
        # Preserve embedded photographs while recoloring the page and text.
        "recolor-reverse-video" = true;

        # The fallback uses a clear backing surface; Matugen overrides these
        # colors with its translucent on_primary background below.
        "default-bg" = transparentBackground;
        "default-fg" = theme.text;
        "inputbar-bg" = controlBackground;
        "inputbar-fg" = theme.text;
        "completion-bg" = controlBackground;
        "completion-fg" = theme.text;
        "render-loading-bg" = controlBackground;
        "render-loading-fg" = theme.text;
      };

      # Custom keybindings. If you want to restore the default bindings for something, just remove the custom binding from here
      mappings = {
        "<C-g>" = "search forward";
        "<C-S-g>" = "search backward";
        n = "navigate next";
        p = "navigate previous";
        e = ''exec "papers --page-index=$PAGE '$FILE'"'';
      };
    };

    # Adapted from InioX/matugen-themes/templates/zathura-colors. Keep the
    # generated palette separate from Home Manager's settings and mappings.
    xdg.configFile."matugen/templates/zathura-colors".text = ''
      set default-bg "{{colors.on_primary.default.rgba | set_alpha: 0.55}}"
      set default-fg "{{colors.primary.default.hex}}"
      set recolor-lightcolor "{{colors.on_primary.default.rgba | set_alpha: 0.55}}"
      set recolor-darkcolor "{{colors.primary.default.hex}}"
      set statusbar-bg "{{colors.on_primary.default.hex}}"
      set statusbar-fg "{{colors.primary.default.hex}}"
      set inputbar-bg "{{colors.on_primary.default.hex}}"
      set inputbar-fg "{{colors.primary.default.hex}}"
      set completion-bg "{{colors.on_primary.default.hex}}"
      set completion-fg "{{colors.primary.default.hex}}"
      set completion-highlight-bg "{{colors.primary.default.hex}}"
      set completion-highlight-fg "{{colors.on_primary.default.hex}}"
      set render-loading-bg "{{colors.on_primary.default.hex}}"
      set render-loading-fg "{{colors.primary.default.hex}}"
      set notification-bg "{{colors.on_primary.default.hex}}"
      set notification-fg "{{colors.primary.default.hex}}"
      set notification-error-bg "{{colors.on_error.default.hex}}"
      set notification-error-fg "{{colors.error.default.hex}}"
      set notification-warning-bg "{{colors.primary_fixed.default.hex}}"
      set notification-warning-fg "{{colors.error_container.default.hex}}"
      set highlight-color "{{colors.primary_fixed.default.hex}}"
      set highlight-active-color "{{colors.primary_fixed_dim.default.hex}}"
    '';

    # extraConfig is emitted before options, so append the include here to
    # let the generated colors override the fallback palette above.
    xdg.configFile."zathura/zathurarc".text = lib.mkAfter ''
      include matugen-colors
    '';
  };
}
