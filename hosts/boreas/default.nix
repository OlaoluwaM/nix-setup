# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
# Based off: https://github.com/Misterio77/nix-starter-configs/blob/main/minimal/nixos/configuration.nix
# Host: Asus ROG Zephyrus M16 (2023)
{
  config,
  unstable,
  hostConfig,
  pkgs,
  ...
}:
let
  inherit (hostConfig)
    username
    userFullName
    ;

  waitForStatusNotifier = pkgs.writeShellApplication {
    name = "wait-for-status-notifier";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = builtins.readFile ./scripts/wait-for-status-notifier.sh;
  };

in
{
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/custom-firewall-config.nix
  ];

  nixpkgs = {
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = {
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Opinionated: disable global registry
      flake-registry = "";
      # Vicinae is built from its own flake input, which Hydra never builds;
      # upstream publishes binaries to this cachix instead. Without it every
      # `nix flake update vicinae` costs a local Qt compile.
      extra-substituters = [ "https://vicinae.cachix.org" ];
      extra-trusted-public-keys = [
        "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
      ];
    };
    # Opinionated: disable channels
    channel.enable = false;
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable memtest
  boot.loader.systemd-boot.memtest86.enable = true;

  # Use latest kernel.
  # Temporarily pinning to 7.1 because the nvidia drivers (which as of now is NVIDIA 595.71.05) is not compatible with pkgs.linuxPackages_latest (kernel 7.2)
  # Downgraded to LTS. 7_1 has been removed from upstream so we're going down to LTS cause of nvidia drivers
  boot.kernelPackages = pkgs.linuxPackages;

  # Literal value because of the directory path. This is under the "boreas" host so making it variable doesn't make sense
  networking.hostName = "boreas";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  local.desktop.profile = hostConfig.desktopProfile;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  services.flatpak.enable = true;

  # NOTE: You can configure your system-wide user settings (groups, etc), add more users as needed.
  users.users = {
    # You can add more user entries here if you want to. They'll all follow the same schema as "olaolu"
    ${username} = {
      # You can set an initial password for your user.
      # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
      # Be sure to change it (using passwd) after rebooting!
      # initialPassword = "correcthorsebatterystaple";
      isNormalUser = true;
      description = userFullName;
      openssh.authorizedKeys.keys = [
        # Add your SSH public key(s) here, if you plan on using SSH to connect
      ];
      # NOTE: Be sure to add any other groups you need (such as networkmanager, audio, docker, etc)
      extraGroups = [
        "wheel"
        "networkmanager"
        "docker"
        "libvirtd"
      ];
      shell = pkgs.zsh;
    };
  };

  # Install Firefox
  programs.firefox.enable = true;

  # Install ZSH
  programs.zsh.enable = true;

  # Allow unpatched dynamically linked Linux executables to use nix-ld. The "NixOS cannot run dynamically linked executables intended for generic linux environments out of the box" issue is more or less resolved by enabling this.
  programs.nix-ld.enable = true;

  # Enable docker with CDI support for the NVIDIA container toolkit.
  virtualisation.docker = {
    enable = true;
    daemon.settings.features = {
      cdi = true;
    };
  };

  # Setup docker with nvidia & nvidia-container-toolkit.
  hardware.nvidia-container-toolkit = {
    enable = true;
  };

  # Use nvidia proprietary drivers
  hardware.nvidia = {
    open = false;
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
    # Enable nvidia-powerd service for improved GPU power consumption
    dynamicBoost.enable = true;
  };

  # VAAPI encode for screen recording (gpu-screen-recorder's KMS capture
  # needs a real hardware encoder on the Intel iGPU render node, not just
  # decode). The pinned nixos-hardware profile for this laptop
  # (asus-zephyrus-gu603h -> common/cpu/intel -> gpu/intel) already threads
  # intel-media-driver into hardware.graphics.extraPackages by default, but
  # that's an implicit fact a future reader would have to trace through
  # three upstream modules to find. Declare it here too, next to the rest of
  # this host's GPU config -- extraPackages is a list-type option, so this
  # merges additively instead of becoming a second source of truth.
  #
  # This must NOT replace the driver set globally: nvidia-vaapi-driver stays
  # in extraPackages (it's decode-only) so NVDEC decode remains available as
  # a per-invocation opt-in (LIBVA_DRIVER_NAME=nvidia <app>). Firefox NVDEC
  # was deliberately dropped as a goal (2026-08-23): it needed the session-wide
  # LIBVA override plus a disabled RDD sandbox, and iGPU decode through
  # intel-media-driver lets the dGPU sleep instead.
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  # gpu-screen-recorder's KMS capture path (used by the Hyprland profile's
  # screen-record script instead of a portal) shells out to a gsr-kms-server
  # helper that needs CAP_SYS_ADMIN to read the DRM/KMS state -- something a
  # plain unprivileged binary can't have. This NixOS module is what actually
  # grants that: it installs the package and wraps gsr-kms-server through
  # security.wrappers with the capability set, instead of running the whole
  # recorder as root or prompting for sudo on every recording. A
  # home-manager-only install of the package could not create that wrapper
  # (security.wrappers is NixOS-level), so this has to live here, not in the
  # Hyprland home-manager profile.
  programs.gpu-screen-recorder.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is installed by default.
    wget
    curl
  ];

  # Enable virt-manager
  programs.virt-manager.enable = true;
  virtualisation.libvirtd.enable = true;

  environment = {
    # Necessary as described here: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.enableCompletion
    pathsToLink = [ "/share/zsh" ];
    # https://discourse.nixos.org/t/how-to-add-a-dir-to-my-systems-or-users-path/19488
    localBinInPath = true;
  };

  # supergfxctl is deprecated; asusctl/asusd now owns ASUS firmware controls. Force this
  # off because older nixpkgs asusd modules may still enable supergfxd by default.
  # see: https://github.com/NixOS/nixpkgs/pull/517986
  services.supergfxd.enable = false;

  # asusd owns the ASUS platform profile and its linked CPU EPP. Running a
  # second profile daemon would let both services write the same state.
  services.power-profiles-daemon.enable = false;

  # asusd probes ASUS firmware that does not exist inside the QEMU dry-run
  # guest. Skip the unit cleanly there instead of letting it restart-loop.
  systemd.services.asusd.unitConfig.ConditionVirtualization = false;

  # Start one tray process in either supported desktop session. GNOME starts
  # graphical-session.target, while the Home Manager Hyprland profile starts
  # hyprland-session.target after importing its Wayland environment. Both tray
  # hosts can register after their session target starts, and rog-control-center
  # does not retry tray setup. Wait for the shared StatusNotifier service so a
  # startup race cannot leave the app running without its icon.
  systemd.user.services.rog-control-center = {
    description = "ROG Control Center";
    wantedBy = [
      "graphical-session.target"
      "hyprland-session.target"
    ];
    partOf = [
      "graphical-session.target"
      "hyprland-session.target"
    ];
    after = [
      "graphical-session.target"
      "hyprland-session.target"
    ];

    serviceConfig = {
      ExecStartPre = "${waitForStatusNotifier}/bin/wait-for-status-notifier";
      ExecStart = "${config.services.asusd.package}/bin/rog-control-center --autostart --background";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # Setup asusctl and rog-control-center (https://asus-linux.org/guides/nixos/)
  services = {
    asusd = {
      enable = true;
      package = unstable.asusctl;

      # Hardware defaults captured from this GU604VI. Custom curves stay
      # disabled, so the embedded controller keeps automatic fan control.
      fanCurvesConfig.source = ./asusd/fan_curves.ron;

      # Product ID 19b6 is the GU604VI keyboard Aura controller.
      auraConfigs."19b6".source = ./asusd/aura_19b6.ron;

      asusdConfig.source = ./asusd/asusd.ron;
    };
  };

  # Preserve the battery-percentage behavior from the old Fedora tuned scripts.
  # This service owns the custom policy and uses asusctl to ask asusd to apply
  # it. asusd's built-in AC/battery switching remains disabled above. The timer
  # catches threshold crossings while discharging, and the udev rule provides
  # immediate AC plug/unplug response.
  systemd.services.battery-profile-threshold =
    let
      # asusd.service is condition-skipped in the VM; a wanted unit that
      # doesn't start doesn't block this one.
      serviceUnitDependencies = [
        "asusd.service"
      ];
    in
    {
      description = "Select ASUS platform profile based on battery threshold";

      # Start asusd with this unit and order profile application after its
      # startup. The weak dependency still lets a battery-less VM exit cleanly
      # when asusd is skipped by its virtualization condition.
      after = serviceUnitDependencies;
      wants = serviceUnitDependencies;

      path = [
        pkgs.coreutils
        config.services.asusd.package
        pkgs.systemd
      ];

      serviceConfig = {
        Type = "oneshot";
      };

      script = builtins.readFile ./scripts/battery-profile-threshold.sh;
    };

  systemd.timers.battery-profile-threshold = {
    description = "Periodically select power profile from battery threshold";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "3min";
      Unit = "battery-profile-threshold.service";
    };
  };

  # Instant edge response for AC plug/unplug: the timer alone would leave up to
  # a 3-minute lag after a power-source change. Kicking the same idempotent
  # oneshot from udev cannot conflict with the timer — both runs compute the
  # target from the current battery state, and a second run exits early once
  # the profile already matches. RUN+= (not SYSTEMD_WANTS) because the adapter
  # device never disappears; plug/unplug is a "change" uevent on it, which
  # SYSTEMD_WANTS would only honor once. --no-block keeps the udev event
  # handler from waiting on the service.
  #
  # A VM guest typically has no Mains power_supply device, so the rule simply
  # never fires there.
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ACTION=="change", ATTR{type}=="Mains", RUN+="${pkgs.systemd}/bin/systemctl start --no-block battery-profile-threshold.service"
  '';

  # This setups a SSH server. Very important if you're setting up a headless system.
  # Feel free to remove if you don't need it.
  #services.openssh = {
  #  enable = true;
  #  settings = {
  # Opinionated: forbid root login through SSH.
  #    PermitRootLogin = "no";
  # Opinionated: use keys only.
  # Remove if you want to SSH using passwords
  #     PasswordAuthentication = false;
  #   };
  # };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "26.05";
}
