# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
# Based off: https://github.com/Misterio77/nix-starter-configs/blob/main/minimal/home-manager/home.nix
{
  hostConfig,
  config,
  pkgs,
  unstable,
  ...
}:
let
  # Using a literal value here because it aligns with the path. Making it variable doesn't make sense
  username = "olaolu";
  home = "/home/${username}";
  visual = "nvim";
  dev = "${config.xdg.userDirs.desktop}/${config.local.fsLayout.devDirname}";

  # Keep this override launcher-scoped. Exporting GTK_THEME as a session
  # variable would force the theme on every GTK application.
  gtkThemeEnv = "${pkgs.lib.getExe' pkgs.coreutils "env"} GTK_THEME=Adwaita:dark";

  # Preserve each package's upstream desktop metadata and patch only selected
  # lines. Home Manager merges home.packages into one profile, so hiPrio makes
  # this small derivation win the filename collision with the original entry.
  # The original application package must still be listed in home.packages.
  overrideDesktopEntry =
    {
      package,
      desktopFile,
      replacements,
    }:
    pkgs.lib.hiPrio (
      # `--replace-fail` stops the build when upstream changes an expected
      # source line, instead of silently dropping the override.
      pkgs.runCommand "${desktopFile}-override" { } ''
        install -Dm644 \
          "${package}/share/applications/${desktopFile}" \
          "$out/share/applications/${desktopFile}"
        ${pkgs.lib.concatMapStringsSep "\n" (replacement: ''
          substituteInPlace "$out/share/applications/${desktopFile}" \
            --replace-fail ${pkgs.lib.escapeShellArg replacement.from} \
            ${pkgs.lib.escapeShellArg replacement.to}
        '') replacements}
      ''
    );

  enteAuthDesktopEntry = overrideDesktopEntry {
    package = pkgs.ente-auth;
    desktopFile = "io.ente.auth.desktop";
    replacements = [
      {
        from = "Exec=enteauth";
        to = "Exec=${gtkThemeEnv} enteauth";
      }
    ];
  };

  # code.desktop contains the main launcher and the New Empty Window action.
  # The separate code-url-handler.desktop entry does not need this GTK override.
  vscodeDesktopEntry = overrideDesktopEntry {
    package = unstable.vscode;
    desktopFile = "code.desktop";
    replacements = [
      {
        from = "Exec=code %F";
        to = "Exec=${gtkThemeEnv} code %F";
      }
      # Desktop actions have independent Exec lines.
      {
        from = "Exec=code --new-window %F";
        to = "Exec=${gtkThemeEnv} code --new-window %F";
      }
    ];
  };

  protonMailDesktopEntry = overrideDesktopEntry {
    package = unstable.protonmail-desktop;
    desktopFile = "proton-mail.desktop";
    replacements = [
      {
        from = "Exec=proton-mail %U";
        to = "Exec=${gtkThemeEnv} proton-mail %U";
      }
      # Proton Mail registers this protocol at startup. Declaring it here keeps
      # xdg-settings from replacing the profile-linked entry with a local copy that is unmanaged by home-manager.
      {
        from = "MimeType=x-scheme-handler/mailto;";
        to = "MimeType=x-scheme-handler/proton-inbox;x-scheme-handler/mailto;";
      }
    ];
  };

  slackDesktopEntry = overrideDesktopEntry {
    package = pkgs.slack;
    desktopFile = "slack.desktop";
    replacements = [
      {
        from = "Exec=${pkgs.lib.getExe' pkgs.slack "slack"} -s %U";
        to = "Exec=${gtkThemeEnv} ${pkgs.lib.getExe' pkgs.slack "slack"} -s %U";
      }
    ];
  };

in
{
  # You can import other home-manager modules here
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModule

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
    ../../modules/home-manager/atuin.nix
    ../../modules/home-manager/bat.nix
    ../../modules/home-manager/bottom.nix
    ../../modules/home-manager/deja-dup.nix
    ../../modules/home-manager/delta.nix
    ../../modules/home-manager/desktop.nix
    ../../modules/home-manager/direnv.nix
    ../../modules/home-manager/dotfiles.nix
    ../../modules/home-manager/fs-layout.nix
    ../../modules/home-manager/fontconfig.nix
    ../../modules/home-manager/fzf.nix
    ../../modules/home-manager/gh.nix
    ../../modules/home-manager/git.nix
    ../../modules/home-manager/gpg.nix
    ../../modules/home-manager/hardware-interface.nix
    ../../modules/home-manager/lazygit.nix
    ../../modules/home-manager/lsd.nix
    ../../modules/home-manager/neovim.nix
    ../../modules/home-manager/obs-studio.nix
    ../../modules/home-manager/ssh.nix
    ../../modules/home-manager/vscode.nix
    ../../modules/home-manager/yazi.nix
    ../../modules/home-manager/zsh.nix
  ];

  nixpkgs = {
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  home = {
    inherit username;
    homeDirectory = home;
    sessionVariables = {
      VISUAL = visual;
      EDITOR = visual;
      DEV = dev;
      GIT_PAGER = "delta";
      COMPOSE_BAKE = "true";
      NIX_FLAKE_PATH = hostConfig.nixosConfigPath;
    };
  };

  # Add stuff for your user as you see fit:
  # Doing this mean home-manager will be the one to manage your configuration for the program in question
  home.packages = with pkgs; [
    # Packages from stable channel
    acpi
    atool

    # Video player: GTK frontend over mpv, replacing VLC. The Hyprland
    # profile's xdg.mimeApps video defaults point at its desktop entry.
    celluloid
    cmake
    claude-code # From https://github.com/sadjow/claude-code-nix
    codex # From https://github.com/sadjow/codex-cli-nix

    dconf2nix
    unstable.defuddle
    duf

    ente-auth
    enteAuthDesktopEntry
    expect

    fish
    fdupes

    gapless
    gcc
    glmark2
    gnumake
    gnome-text-editor
    google-chrome

    haskellPackages.threadscope
    haskellPackages.implicit-hie
    haskellPackages.ghc-events
    (callPackage ../../pkgs/hacker-laws-cli { })

    libappindicator
    libpq
    libwebp
    localsend

    meson
    # Celluloid brings its own mpv as the playback backend; this copy is for
    # direct `mpv` use from a terminal.
    mpv

    nmap
    nixfmt
    nitch
    nvtopPackages.full
    # Add amd on an amd device

    openssl
    ookla-speedtest

    pandoc
    playerctl
    pgcli
    protobuf
    proton-vpn
    powertop

    racket

    service-wrapper
    slack
    slackDesktopEntry
    spotify

    texliveFull
    ticktick # GNOME keybind <Control><Alt>t launches this
    typescript
    typst

    wirelesstools
    wl-clipboard
    woff2

    z3

    # Packages from unstable channel
    unstable.cabal-install
    unstable.cabal2nix
    unstable.cheat # Creating an overlay would involve more effort than I am willing to expend

    unstable.discord
    unstable.devbox

    unstable.fastfetch
    unstable.fd
    unstable.fend
    unstable.ffmpeg-full
    unstable.ffmpegthumbnailer
    unstable.fx

    unstable.gdu
    unstable.go

    unstable.httpie

    unstable.imagemagick
    unstable.impression
    unstable.inxi
    unstable.python3Packages.ipython

    unstable.jql
    unstable.just
    unstable.just-lsp

    unstable.kitty

    unstable.libdrm
    unstable.lazydocker
    unstable.libgcc
    unstable.libva
    unstable.libva-utils
    unstable.lld
    lm_sensors
    unstable.lsof

    unstable.navi
    unstable.ncdu
    unstable.nil # For nix ide plugin
    unstable.nixd # For nix ide plugin
    (callPackage ../../pkgs/notebooklm-mcp-cli { })
    unstable.noti

    unstable.obsidian
    unstable.openai-whisper
    unstable.opencode

    unstable.pavucontrol
    unstable.pciutils
    unstable.perl
    unstable.procs
    unstable.protonmail-desktop
    protonMailDesktopEntry
    unstable.proton-vpn-cli
    # withPackages wraps python3 so these libraries are importable by the interpreter.
    # Again we are installing pynvim and dnspython this way because they are libraries not standalone executables.
    # Yes there are individual entries for them in nixpkgs but they wouldn't be useful when specified in that way
    (unstable.python3.withPackages (ps: [
      ps.pynvim
      ps.dnspython
    ]))

    unstable.rainfrog
    unstable.rip2
    unstable.ripgrep
    unstable.ripgrep-all
    unstable.rlwrap

    unstable.sad
    unstable.sd
    unstable.shellcheck
    unstable.shfmt
    unstable.socat
    unstable.stack
    # stack2nix is marked broken in nixpkgs; use cabal2nix for simple
    # package expression generation, or haskell.nix for Stack/Stackage fidelity.
    # unstable.stack2nix
    unstable.starship

    unstable.tealdeer
    unstable.termdown
    unstable.tinyxxd
    unstable.tre-command

    unstable.uv

    vscodeDesktopEntry

    unstable.w3m
    unstable.webp-pixbuf-loader
    unstable.witr
    unstable.wireshark

    unstable.yt-dlp

    unstable.zoxide
  ];

  services.flatpak = {
    enable = true;
    packages = [
      "im.riot.Riot"
      "org.gnome.DejaDup"
      "io.m51.Gelly"
      "it.mijorus.gearlever"
      "com.bilingify.readest"
      "com.bitwarden.desktop"
      "com.github.tchx84.Flatseal"
      "io.github.flattool.Warehouse"
    ];
    update.auto = {
      enable = true;
      onCalendar = "Fri 10:00";
    };
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # Manage standard XDG dirs with HM, and create them if they don't exist. Also supports non-standard dirs via the `extra` option.
  # This sets the following env variables by default:
  #   XDG_CONFIG_HOME = ~/.config
  #   XDG_DATA_HOME   = ~/.local/share
  #   XDG_STATE_HOME  = ~/.local/state
  #   XDG_CACHE_HOME  = ~/.cache
  # We access them using config.xdg.configHome, config.xdg.dataHome, etc. in the rest of our config.
  xdg = {
    enable = true;

    userDirs = {
      enable = true;
      createDirectories = true;
      # The Desktop, Documents, Videos, Pictures xdg dirs have the right defaults: https://github.com/nix-community/home-manager/blob/a89686d115e970e200eb2caa7603f3673050e00c/modules/misc/xdg-user-dirs.nix#L178
    };
  };

  # Enable dotfiles. Must be done first so symlinks can be created for those configurations that depend on them
  local.dotfiles = {
    enable = true;
    dotsPath = "${config.xdg.userDirs.desktop}/${hostConfig.dotfilesRelativePath}";
  };

  local.atuin.enable = true;
  local.bat.enable = true;
  local.bottom.enable = true;
  local.dejaDup.enable = true;
  local.delta.enable = true;
  local.direnv.enable = true;
  local.fzf.enable = true;
  local.gh.enable = true;
  local.git.enable = true;
  local.gpg.enable = true;
  local.lazygit.enable = true;
  local.lsd.enable = true;
  local.neovim.enable = true;
  local.obsStudio.enable = true;
  local.ssh.enable = true;
  local.yazi.enable = true;

  local.fsLayout.devDirname = hostConfig.devDirname;

  # Enable and configure zsh with OMZ and our custom module
  local.zsh = {
    enable = true;
    zshrcConfigPath = "${home}/.zshrc.nix.zsh";
    # Keep shell history OUT of the dotfiles git tree — it can contain secrets,
    # and atuin already handles cross-machine history. Lives under XDG data.
    histFilePath = "${config.xdg.dataHome}/zsh/.zsh_history";
  };

  local.desktop.profile = hostConfig.desktopProfile;
  local.theme.preset = "catppuccin-mocha";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "26.05";
}
