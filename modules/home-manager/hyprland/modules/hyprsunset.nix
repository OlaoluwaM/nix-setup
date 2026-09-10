{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.local.hyprland;

  hyprsunsetPackage = pkgs.hyprsunset.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./hyprsunset-realtime-schedule.patch
    ];
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      "-DBUILD_TESTING=ON"
    ];
    doCheck = true;
  });
in
{
  config = lib.mkIf cfg.enable {
    # hyprsunset shifts the display color temperature later in the day. Lower
    # temperature values look warmer/oranger. This is shared session
    # infrastructure, independent of whatever shell UI eventually lands.
    #
    # The endpoints mirror the GNOME profile this replaces (neutral during
    # the day, 2467K overnight -- see modules/home-manager/gnome/default.nix:
    # org/gnome/settings-daemon/plugins/color, from = 19.0, to = 8.0,
    # temperature = 2467). hyprsunset applies each profile entry abruptly and
    # has no native fade, so the 19:00 and 19:30 entries step the temperature
    # down across the hour after GNOME's configured start time instead of
    # jumping straight to 2467K.
    services.hyprsunset = {
      enable = true;
      package = hyprsunsetPackage;
      systemdTarget = config.wayland.systemd.target;
      settings = {
        profile = [
          {
            time = "8:00";
            identity = true;
          }
          {
            time = "19:00";
            temperature = 4500;
          }
          {
            time = "19:30";
            temperature = 3500;
          }
          {
            time = "20:00";
            temperature = 2467;
          }
        ];
      };
    };
  };
}
