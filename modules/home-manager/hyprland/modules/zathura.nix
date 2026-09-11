{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.local.hyprland;
  theme = config.local.theme.colors;

  # Keep transient controls readable even when the document surface is clear.
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

        # Recolor maps the document's light pixels to a clear surface and its
        # dark pixels to opaque text. App-provided alpha lets Hyprland blur the
        # wallpaper without reducing glyph opacity.
        recolor = true;
        "recolor-lightcolor" = transparentBackground;
        "recolor-darkcolor" = theme.text;
        "recolor-keephue" = true;
        # Preserve embedded photographs while recoloring the page and text.
        "recolor-reverse-video" = true;

        # This is the surface underneath the PDF page. It must also stay clear
        # or it will replace the compositor blur with a flat application fill.
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
  };
}
