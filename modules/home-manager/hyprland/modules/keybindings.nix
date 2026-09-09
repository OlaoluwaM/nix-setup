{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:

# Beginner orientation:
#
# This module owns every Hyprland key chord: application launches,
# screenshot/screenrecord binds, window management, workspace switching,
# mouse drag/resize, and the hardware media/brightness keys. Window rules,
# compositor config (input/general/decoration/animations/monitor), and
# services stay in default.nix.
#
# Every chord is declared once in `bindDefs` below with a human description
# and a group, and two artifacts derive from that single list:
#   1. the Hyprland lua binds (the description rides along as a bind option,
#      so `hyprctl binds` is self-documenting), and
#   2. ~/.local/share/silere/keybinds.json, the data behind the shell's
#      searchable keybindings viewer (silere.nix points its keybindsFile
#      key here; Super+/ opens the viewer).
# Entries with `viewer = false` bind without cluttering the viewer (the 20
# generated workspace chords collapse into two synthetic rows instead), and
# `viewerExtras` documents generated chords and gestures that do not have a
# one-to-one entry in `bindDefs`, so the viewer still lists them.
#
# AGENTS.md's rule to keep equivalent GNOME and Hyprland keybindings on the
# same chord applies here: before changing a binding, check the GNOME
# profile and preserve parity unless a desktop-specific constraint requires
# an intentional difference.
let
  cfg = config.local.hyprland;
  commands = cfg.commands;
  enableAsusRogKeybindings = config.local.capabilities.hardware.asusRog;
  lua = lib.generators.mkLuaInline;
  luaString = builtins.toJSON;
  mod = "SUPER";
  terminal = "kitty";

  vicinaeCommand = lib.getExe' config.programs.vicinae.package "vicinae";
  brightnessCommand = lib.getExe pkgs.brightnessctl;
  wpctlCommand = lib.getExe' pkgs.wireplumber "wpctl";
  qsCommand = lib.getExe' commands.quickshellPackage "qs";
  colloidAppIcons = "${pkgs.colloid-icon-theme}/share/icons/Colloid-Dark/apps/scalable";
  # `qs ipc` locates the running instance by config path, and this shell runs
  # from a Nix store path (silere.nix's ExecStart -p flag), not the default
  # config dir -- a bare `qs ipc call` finds nothing. Every IPC call must
  # carry the same -p the service uses.
  #
  # The trailing `--` is load-bearing: quickshell 0.3.0's CLI only accepts
  # positionals past <target> <function> after a separator, so any call that
  # passes a function argument (`menu show notifications`) is rejected by the
  # qs binary itself without it -- the shell never sees the call. Harmless on
  # argument-less calls, so it lives here rather than per call site.
  silereIpc = "${qsCommand} -p ${commands.silereShellPackage}/share/silere-shell/shell.qml ipc call --";

  execDispatcher = command: "hl.dsp.exec_cmd(${luaString command})";

  # One definition per chord. `flags` holds Hyprland bind options (release,
  # locked, mouse, ...); the description is merged in when the lua bind is
  # rendered, so flags never need to carry it themselves.
  mkDef =
    {
      keys,
      dsp,
      desc,
      group,
      flags ? { },
      viewer ? true,
    }:
    {
      inherit
        keys
        dsp
        desc
        group
        flags
        viewer
        ;
    };

  toLuaBind = d: {
    _args = [
      d.keys
      (lua d.dsp)
      ({ description = d.desc; } // d.flags)
    ];
  };

  # Match Hyprland's standard workspace bindings:
  # Super+1..9 selects workspaces 1..9, Super+0 selects workspace 10.
  # Adding Shift moves the focused window to that workspace. viewer = false:
  # twenty near-identical rows would drown the viewer, so `viewerExtras`
  # carries two collapsed rows for them instead.
  workspaceDefs = lib.concatMap (
    workspace:
    let
      key = if workspace == 10 then "0" else toString workspace;
    in
    [
      (mkDef {
        keys = "${mod} + ${key}";
        dsp = "hl.dsp.focus({ workspace = ${toString workspace} })";
        desc = "Switch to workspace ${toString workspace}";
        group = "Workspaces";
        viewer = false;
      })
      (mkDef {
        keys = "${mod} + SHIFT + ${key}";
        dsp = "hl.dsp.window.move({ workspace = ${toString workspace} })";
        desc = "Move window to workspace ${toString workspace}";
        group = "Workspaces";
        viewer = false;
      })
    ]
  ) (lib.range 1 10);

  bindDefs = [
    # -- Applications ------------------------------------------------------
    (mkDef {
      keys = "${mod} + T";
      dsp = execDispatcher terminal;
      desc = "Open a terminal";
      group = "Applications";
    })
    (mkDef {
      keys = "${mod} + W";
      dsp = execDispatcher (lib.getExe pkgs.firefox);
      desc = "Open Firefox";
      group = "Applications";
    })
    (mkDef {
      keys = "ALT + O";
      dsp = execDispatcher (lib.getExe unstable.obsidian);
      desc = "Open Obsidian";
      group = "Applications";
    })
    (mkDef {
      keys = "CTRL + ALT + T";
      dsp = execDispatcher (lib.getExe' pkgs.ticktick "ticktick");
      desc = "Open TickTick";
      group = "Applications";
    })
    # Launch through the desktop entry so the themed override from
    # home/olaolu/default.nix (dark-mode env) applies, matching GNOME.
    (mkDef {
      keys = "${mod} + S";
      dsp = execDispatcher "slack";
      desc = "Open Slack";
      group = "Applications";
    })
    (mkDef {
      keys = "ALT + S";
      dsp = execDispatcher (lib.getExe pkgs.spotify);
      desc = "Open Spotify";
      group = "Applications";
    })
    (mkDef {
      keys = "${mod} + D";
      dsp = execDispatcher (lib.getExe' unstable.discord "Discord");
      desc = "Open Discord";
      group = "Applications";
    })
    (mkDef {
      keys = "${mod} + M";
      dsp = execDispatcher (lib.getExe unstable.protonmail-desktop);
      desc = "Open Proton Mail";
      group = "Applications";
    })
    (mkDef {
      keys = "${mod} + SHIFT + M";
      dsp = execDispatcher "${pkgs.mission-center}/bin/missioncenter";
      desc = "Open Mission Center";
      group = "Applications";
    })
    (mkDef {
      keys = "${mod} + N";
      dsp = execDispatcher "${pkgs.nautilus}/bin/nautilus";
      desc = "Open Files";
      group = "Applications";
    })

    # -- Launcher ----------------------------------------------------------
    (mkDef {
      keys = "${mod} + Space";
      dsp = execDispatcher "${vicinaeCommand} open";
      desc = "Open the launcher";
      group = "Launcher";
    })
    (mkDef {
      keys = "ALT + V";
      dsp = execDispatcher "${vicinaeCommand} 'vicinae://launch/clipboard/history?toggle=true'";
      desc = "Open clipboard history";
      group = "Launcher";
    })
    # Opens the shell's own wallpaper picker via IPC (silere.nix's
    # wallpaperCommand feeds the actual apply step; this chord just opens
    # the overlay): a frosted grid over local.hyprland.silere.wallpapersDir
    # ($WALLPAPERS_DIR, default.nix), click an image to apply it, Ctrl+F
    # filters by name, and a Random button inside the picker replaces the
    # old zero-input chord. This used to be a Vicinae script-command
    # deeplink ("random-wallpaper") -- Vicinae's script-command argument
    # types only support a single static text field, never a live
    # directory listing, so a real picker over $WALLPAPERS_DIR was never
    # something Vicinae itself could render. Both former Vicinae wallpaper
    # commands are gone now (wallpaper.nix); the shell's picker replaces
    # them both.
    (mkDef {
      keys = "${mod} + SHIFT + W";
      dsp = execDispatcher "${silereIpc} wallpapers toggle";
      desc = "Open the wallpaper picker";
      group = "Launcher";
    })

    # -- Screen capture ----------------------------------------------------
    (mkDef {
      keys = "F6";
      dsp = execDispatcher "${commands.screenshotScript}/bin/hypr-shell-screenshot area";
      desc = "Screenshot an area";
      group = "Screen capture";
    })
    (mkDef {
      keys = "SHIFT + F6";
      dsp = execDispatcher "${commands.screenshotScript}/bin/hypr-shell-screenshot full";
      desc = "Screenshot the screen";
      group = "Screen capture";
    })
    (mkDef {
      keys = "CTRL + F6";
      dsp = execDispatcher "${commands.screenshotScript}/bin/hypr-shell-screenshot window";
      desc = "Screenshot the focused window";
      group = "Screen capture";
    })
    # Every record chord is a toggle (the script stops a running
    # gpu-screen-recorder before it ever starts a new one), so no chord is
    # spent on a dedicated
    # stop bind anymore -- the slot mod+ALT+R used to burn on "stop" now
    # mirrors CTRL+F6's focused-window mode instead. The bar's recording
    # pill is the other stop path: clicking it runs the same script.
    (mkDef {
      keys = "${mod} + SHIFT + R";
      dsp = execDispatcher "${commands.screenrecordScript}/bin/hypr-shell-record area";
      desc = "Start/stop an area recording";
      group = "Screen capture";
    })
    (mkDef {
      keys = "${mod} + CTRL + R";
      dsp = execDispatcher "${commands.screenrecordScript}/bin/hypr-shell-record full";
      desc = "Start/stop a screen recording";
      group = "Screen capture";
    })
    (mkDef {
      keys = "${mod} + ALT + R";
      dsp = execDispatcher "${commands.screenrecordScript}/bin/hypr-shell-record window";
      desc = "Start/stop a window recording";
      group = "Screen capture";
    })

    # -- Session -----------------------------------------------------------
    (mkDef {
      keys = "${mod} + L";
      dsp = execDispatcher "${pkgs.systemd}/bin/loginctl lock-session";
      desc = "Lock the screen";
      group = "Session";
    })
    # Same hypr-shell-caffeine.service the shell's menu row and mug pill
    # control -- one unit, so chord and UI can never disagree. The script
    # goes through the shell's IPC first, so the chord starts a run with
    # the last chosen preset and the pill lights instantly.
    (mkDef {
      keys = "${mod} + C";
      dsp = execDispatcher "${commands.caffeineScript}/bin/hypr-shell-caffeine toggle";
      desc = "Toggle caffeine";
      group = "Session";
    })
    (mkDef {
      keys = "${mod} + slash";
      dsp = execDispatcher "${silereIpc} keybinds toggle";
      desc = "Show keyboard shortcuts";
      group = "Session";
    })
    # GNOME parity: <Super>v is toggle-message-tray there. Unlike Super+Q
    # this opens/raises only -- the menu IPC has no per-tab toggle -- so
    # Escape closes. Plain V is free: float is Super+SHIFT+V, clipboard
    # history is ALT+V.
    (mkDef {
      keys = "${mod} + V";
      dsp = execDispatcher "${silereIpc} menu show notifications";
      desc = "Show notifications";
      group = "Session";
    })
    # The direct door to the Settings tab that Super+Q deliberately is not
    # (its settings-landing was tried and rolled back -- see its comment
    # below). Same opens/raises-only contract as Super+V above: the menu
    # IPC has no per-tab toggle, so Escape closes.
    (mkDef {
      keys = "${mod} + U";
      dsp = execDispatcher "${silereIpc} menu show settings";
      desc = "Open shell settings";
      group = "Session";
    })
    # GNOME parity: <Super>q is toggle-quick-settings there (see the GNOME
    # profile's keybindings.nix). `menu toggle` is the exact counterpart:
    # it opens the menu on its Home tab and closes it when already open.
    # (Landing on the Settings tab was tried first and rolled back -- the
    # user wants Home.)
    (mkDef {
      keys = "${mod} + Q";
      dsp = execDispatcher "${silereIpc} menu toggle";
      desc = "Toggle the shell menu";
      group = "Session";
    })

    (mkDef {
      keys = "CTRL + ${mod} + O";
      dsp = execDispatcher "${silereIpc} calendar toggle";
      desc = "Toggle the calendar";
      group = "Session";
    })

    # -- Windows -----------------------------------------------------------
    # Vicinae's window switcher replaces the dynamic Alt+Tab binds from the
    # disabled hyprshell module. Unlike hyprshell's hold-and-cycle switcher,
    # this opens Vicinae's searchable window list for explicit selection.
    (mkDef {
      keys = "ALT + Tab";
      dsp = execDispatcher "${vicinaeCommand} 'vicinae://launch/wm/switch-windows'";
      desc = "Switch windows";
      group = "Windows";
    })
    (mkDef {
      keys = "${mod} + SHIFT + Q";
      dsp = "hl.dsp.window.close()";
      desc = "Close the window";
      group = "Windows";
    })
    (mkDef {
      keys = "ALT + F4";
      dsp = "hl.dsp.window.close()";
      desc = "Close the window";
      group = "Windows";
    })
    (mkDef {
      keys = "${mod} + F";
      dsp = "hl.dsp.window.fullscreen()";
      desc = "Toggle fullscreen";
      group = "Windows";
    })
    (mkDef {
      keys = "${mod} + Up";
      dsp = "hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"set\" })";
      desc = "Maximize the window";
      group = "Windows";
    })
    (mkDef {
      keys = "${mod} + Down";
      dsp = "hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"unset\" })";
      desc = "Unmaximize the window";
      group = "Windows";
    })
    (mkDef {
      keys = "ALT + F5";
      dsp = "hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"unset\" })";
      desc = "Unmaximize the window";
      group = "Windows";
      viewer = false;
    })
    (mkDef {
      keys = "${mod} + SHIFT + V";
      dsp = "hl.dsp.window.float()";
      desc = "Toggle floating";
      group = "Windows";
    })
    (mkDef {
      keys = "CTRL + ${mod} + Left";
      dsp = "hl.dsp.window.swap({ direction = \"l\" })";
      desc = "Swap window left";
      group = "Windows";
    })
    (mkDef {
      keys = "CTRL + ${mod} + Right";
      dsp = "hl.dsp.window.swap({ direction = \"r\" })";
      desc = "Swap window right";
      group = "Windows";
    })
    (mkDef {
      keys = "CTRL + ${mod} + Up";
      dsp = "hl.dsp.window.swap({ direction = \"u\" })";
      desc = "Swap window up";
      group = "Windows";
    })
    (mkDef {
      keys = "CTRL + ${mod} + Down";
      dsp = "hl.dsp.window.swap({ direction = \"d\" })";
      desc = "Swap window down";
      group = "Windows";
    })
  ]
  ++ workspaceDefs
  ++ [
    # Super+Left/Right cycles workspaces relative to the current one, and
    # Super+Shift+Left/Right carries the focused window along -- the same
    # chords the GNOME profile uses for move-to-workspace-left/right.
    # `repeating` keeps the workspace cycling while the chord is held.
    (mkDef {
      keys = "${mod} + Right";
      dsp = "hl.dsp.focus({ workspace = \"r+1\" })";
      desc = "Next workspace";
      group = "Workspaces";
      flags.repeating = true;
    })
    (mkDef {
      keys = "${mod} + Left";
      dsp = "hl.dsp.focus({ workspace = \"r-1\" })";
      desc = "Previous workspace";
      group = "Workspaces";
      flags.repeating = true;
    })
    (mkDef {
      keys = "${mod} + SHIFT + Right";
      dsp = "hl.dsp.window.move({ workspace = \"r+1\" })";
      desc = "Move window to next workspace";
      group = "Workspaces";
      flags.repeating = true;
    })
    (mkDef {
      keys = "${mod} + SHIFT + Left";
      dsp = "hl.dsp.window.move({ workspace = \"r-1\" })";
      desc = "Move window to previous workspace";
      group = "Workspaces";
      flags.repeating = true;
    })

    # Scroll through existing workspaces with Super + scroll.
    (mkDef {
      keys = "${mod} + mouse_down";
      dsp = "hl.dsp.focus({ workspace = \"e+1\" })";
      desc = "Next workspace (scroll)";
      group = "Workspaces";
    })
    (mkDef {
      keys = "${mod} + mouse_up";
      dsp = "hl.dsp.focus({ workspace = \"e-1\" })";
      desc = "Previous workspace (scroll)";
      group = "Workspaces";
    })

    # Release binds are useful for "press Super by itself" behavior because
    # they avoid firing before Hyprland knows whether Super is part of a combo.
    (mkDef {
      keys = "${mod} + SUPER_L";
      dsp = execDispatcher "${vicinaeCommand} open";
      desc = "Open the launcher (tap Super)";
      group = "Launcher";
      flags.release = true;
      viewer = false;
    })
    (mkDef {
      keys = "${mod} + SUPER_R";
      dsp = execDispatcher "${vicinaeCommand} open";
      desc = "Open the launcher (tap Super)";
      group = "Launcher";
      flags.release = true;
      viewer = false;
    })

    # Mouse binds keep running while the mouse button is held. Used here so
    # Super+left-drag moves a window and Super+right-drag resizes one.
    (mkDef {
      keys = "${mod} + mouse:272";
      dsp = "hl.dsp.window.drag()";
      desc = "Move window (drag)";
      group = "Windows";
      flags.mouse = true;
    })
    (mkDef {
      keys = "${mod} + mouse:273";
      dsp = "hl.dsp.window.resize()";
      desc = "Resize window (drag)";
      group = "Windows";
      flags.mouse = true;
    })

    # Raise/lower go through the shell like the media keys: a direct wpctl
    # press at 0% or 100% is a PipeWire no-op the shell never sees, so the
    # OSD stayed dark exactly when feedback matters most. The shell applies
    # the same 5% step and 1.0 cap, and keeps running while locked. Mute
    # stays a direct device command below. viewer = false: hardware keys
    # are self-describing.
    (mkDef {
      keys = "XF86AudioRaiseVolume";
      dsp = execDispatcher "${silereIpc} audio raise";
      desc = "Raise the volume";
      group = "Hardware";
      flags = {
        locked = true;
        repeating = true;
      };
      viewer = false;
    })
    (mkDef {
      keys = "XF86AudioLowerVolume";
      dsp = execDispatcher "${silereIpc} audio lower";
      desc = "Lower the volume";
      group = "Hardware";
      flags = {
        locked = true;
        repeating = true;
      };
      viewer = false;
    })
    (mkDef {
      keys = "XF86AudioMute";
      dsp = execDispatcher "${wpctlCommand} set-mute @DEFAULT_AUDIO_SINK@ toggle";
      desc = "Mute the audio";
      group = "Hardware";
      flags.locked = true;
      viewer = false;
    })
    # Same direct-device pattern as sink mute above, aimed at the capture
    # side; the bar's mic chip is the feedback (it swaps to the slashed
    # glyph while a stream holds the source open). The chord exists because
    # not every keyboard emits XF86AudioMicMute, and unlike the hardware
    # key it isn't self-describing, so it stays in the viewer.
    (mkDef {
      keys = "XF86AudioMicMute";
      dsp = execDispatcher "${wpctlCommand} set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
      desc = "Mute the microphone";
      group = "Hardware";
      flags.locked = true;
      viewer = false;
    })
    (mkDef {
      keys = "${mod} + CTRL + M";
      dsp = execDispatcher "${wpctlCommand} set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
      desc = "Mute or unmute the microphone";
      group = "Hardware";
      flags.locked = true;
    })
    # GNOME parity: gnome-settings-daemon services these keys natively, so the
    # GNOME profile never declares them. Routed through the shell's media IPC
    # rather than playerctl so the keys drive the same player the media card
    # and bar control -- including a source pinned with the card's steppers,
    # which playerctld's own last-active pick knows nothing about.
    (mkDef {
      keys = "XF86AudioPlay";
      dsp = execDispatcher "${silereIpc} media playPause";
      desc = "Play or pause media";
      group = "Hardware";
      flags.locked = true;
      viewer = false;
    })
    (mkDef {
      keys = "XF86AudioPause";
      dsp = execDispatcher "${silereIpc} media playPause";
      desc = "Play or pause media";
      group = "Hardware";
      flags.locked = true;
      viewer = false;
    })
    (mkDef {
      keys = "XF86AudioNext";
      dsp = execDispatcher "${silereIpc} media next";
      desc = "Next track";
      group = "Hardware";
      flags.locked = true;
      viewer = false;
    })
    (mkDef {
      keys = "XF86AudioPrev";
      dsp = execDispatcher "${silereIpc} media previous";
      desc = "Previous track";
      group = "Hardware";
      flags.locked = true;
      viewer = false;
    })
    # GNOME parity: org/gnome/settings-daemon/plugins/media-keys binds
    # play/next/previous to F4/<Alt>bracketright/<Alt>bracketleft there
    # (gnome/modules/keybindings.nix). Unlike the XF86Audio* keys above,
    # these aren't self-describing hardware glyphs, so they stay in the
    # viewer.
    (mkDef {
      keys = "F4";
      dsp = execDispatcher "${silereIpc} media playPause";
      desc = "Play or pause media";
      group = "Hardware";
      flags.locked = true;
    })
    (mkDef {
      keys = "ALT + bracketright";
      dsp = execDispatcher "${silereIpc} media next";
      desc = "Next track";
      group = "Hardware";
      flags.locked = true;
    })
    (mkDef {
      keys = "ALT + bracketleft";
      dsp = execDispatcher "${silereIpc} media previous";
      desc = "Previous track";
      group = "Hardware";
      flags.locked = true;
    })
    # Through the shell for the same reason as the volume keys above: a
    # brightnessctl press at 0% or 100% changes nothing the shell can
    # observe, so the OSD never appeared at the rails. Same 5% step.
    (mkDef {
      keys = "XF86MonBrightnessUp";
      dsp = execDispatcher "${silereIpc} brightness raise";
      desc = "Raise the brightness";
      group = "Hardware";
      flags = {
        locked = true;
        repeating = true;
      };
      viewer = false;
    })
    (mkDef {
      keys = "XF86MonBrightnessDown";
      dsp = execDispatcher "${silereIpc} brightness lower";
      desc = "Lower the brightness";
      group = "Hardware";
      flags = {
        locked = true;
        repeating = true;
      };
      viewer = false;
    })
    (mkDef {
      keys = "XF86KbdBrightnessUp";
      dsp = execDispatcher "${brightnessCommand} --device='*::kbd_backlight' set 5%+";
      desc = "Raise the keyboard backlight";
      group = "Hardware";
      flags = {
        locked = true;
        repeating = true;
      };
      viewer = false;
    })
    (mkDef {
      keys = "XF86KbdBrightnessDown";
      dsp = execDispatcher "${brightnessCommand} --device='*::kbd_backlight' set 5%-";
      desc = "Lower the keyboard backlight";
      group = "Hardware";
      flags = {
        locked = true;
        repeating = true;
      };
      viewer = false;
    })
  ]
  # Super+Alt+W (wifi), Super+B (bluetooth), and
  # Super+Escape/XF86PowerOff (session) are intentionally unbound: their
  # old shell targets are gone. They come back once the new silere shell
  # surfaces them. Super+Q (settings) and Super+Shift+W (wallpapers) are
  # bound above.
  ++ lib.optionals enableAsusRogKeybindings [
    (mkDef {
      keys = "XF86Launch1";
      dsp = execDispatcher (lib.getExe' unstable.asusctl "rog-control-center");
      desc = "Open ROG Control Center";
      group = "Hardware";
    })
    (mkDef {
      keys = "F5";
      dsp = execDispatcher "${lib.getExe' unstable.asusctl "asusctl"} profile -n";
      desc = "Cycle the power profile";
      group = "Hardware";
    })
    # The key wearing the airplane glyph on this keyboard, bound as a plain
    # F-key like F4/F5 above. No GNOME counterpart to keep parity with.
    # Pure IPC with no script fallback -- the latch lives in the shell, so
    # with the shell down there is no airplane state to flip.
    (mkDef {
      keys = "F12";
      dsp = execDispatcher "${silereIpc} airplane toggle";
      desc = "Toggle airplane mode";
      group = "Hardware";
    })
  ];

  # Chords the viewer should list that do not have a one-to-one `bindDefs`
  # entry: the workspace number chords collapse from twenty generated binds
  # into two rows, and the swipe is a gesture, not a bind.
  viewerExtras = [
    {
      keys = "${mod} + 1–9, 0";
      desc = "Switch to workspace 1–10";
      group = "Workspaces";
    }
    {
      keys = "${mod} + SHIFT + 1–9, 0";
      desc = "Move window to workspace 1–10";
      group = "Workspaces";
    }
    {
      keys = "3-finger swipe";
      desc = "Switch workspaces (past the end creates one)";
      group = "Workspaces";
    }
  ];

  viewerEntries =
    map (d: {
      inherit (d) keys desc group;
    }) (lib.filter (d: d.viewer) bindDefs)
    ++ viewerExtras;
in
{
  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      bind = map toLuaBind bindDefs;
    };

    # The viewer data the shell's Keybinds service reads (silere.nix points
    # local.hyprland.silere.keybindsFile here). Derived from bindDefs above,
    # so a chord and its documentation can never drift apart.
    xdg.dataFile."silere/keybinds.json".text = builtins.toJSON viewerEntries;

    # Third entry point into the viewer, alongside Super+slash and the qs CLI:
    # a desktop entry makes it launchable from Vicinae's app search ("Keyboard
    # Shortcuts"). Exec is the same IPC call the chord runs -- it toggles the
    # popup in the running shell rather than spawning anything, so the entry
    # is safe to "launch" repeatedly. Lives here, not silere.nix, because the
    # viewer's other artifacts (chord, JSON) are declared in this module.
    xdg.desktopEntries.silere-keybinds = {
      name = "Keyboard Shortcuts";
      comment = "Search the Hyprland and shell keybindings";
      exec = "${silereIpc} keybinds toggle";
      # Vicinae does not resolve these semantic names through the active icon
      # theme, so use the matching Colloid application icon directly.
      icon = "${colloidAppIcons}/preferences-desktop-keyboard-shortcuts.svg";
      terminal = false;
      categories = [
        "Utility"
        "Settings"
      ];
    };

    # Same reasoning as silere-keybinds above, aimed at the wallpaper picker:
    # exists so Vicinae's app search ("Wallpapers") can launch the picker too,
    # not just the Super+Shift+W chord. Exec toggles the picker in the
    # running shell rather than spawning anything, so it is safe to "launch"
    # repeatedly.
    xdg.desktopEntries.silere-wallpapers = {
      name = "Wallpapers";
      comment = "Pick a wallpaper from the shell's frosted grid";
      exec = "${silereIpc} wallpapers toggle";
      icon = "${colloidAppIcons}/preferences-desktop-wallpaper.svg";
      terminal = false;
      categories = [
        "Utility"
        "Settings"
      ];
    };
  };
}
