# Help is available in the configuration.nix(5) man page and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  lib,
  pkgs,

  admin,
  hostName,
  hostPlatform,

  flakeDefaultPackage,
  quickGenAttrs,
  quickMapAttrs,

  inputs,
  ...
}:
let
  inherit (lib)
    attrsets
    modules
    strings
    trivial
    ;
in
{
  _module.args.libS = # https://nixos-and-flakes.thiscute.world/nixos-with-flakes/nixos-flake-and-module-system#pass-non-default-parameters-to-submodules
    inputs.nuschtos-nixos-modules.lib { inherit lib config; }; # https://github.com/NuschtOS/nixos-modules

  boot = {
    kernelModules = [ "kvm-intel" ];
    kernelParams = [
      "zswap.enabled=1" # https://discourse.nixos.org/t/working-zswap-configuration-different-from-zram/47804
    ];

    kernelPackages = pkgs.linuxPackages_latest;

    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
    ];

    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.enable = true;
  };

  disko.devices.disk.main = {
    device = "/dev/nvme0n1";
    type = "disk";

    content.type = "gpt";
    content.partitions = {
      ESP = # https://wiki.archlinux.org/title/EFI_system_partition
        {
          size = "260M";
          type = "EF00";

          content = {
            format = "vfat";
            mountOptions = [ "umask=0077" ];
            mountpoint = "/boot";
            type = "filesystem";
          };
        };

      root.size = "100%";
      root.content = {
        extraArgs = [ "-f" ];
        type = "btrfs";

        subvolumes = attrsets.genAttrs [ "/coding" "/home" "/nix" "/root" ] (mountpoint: {
          mountOptions = [
            "compress=zstd"
            "noatime"
          ];
          mountpoint = if mountpoint == "/root" then "/" else mountpoint;
        });
      };

      swap.start = "-32G"; # use 24588939264 bytes or 23 GiB if swap size = 1.5 x `free -b` memory
      swap.content = {
        discardPolicy = "both";
        resumeDevice = true;
        type = "swap";
      };
    };
  };

  environment = {
    etc.nixos.source = ./.;

    plasma6.excludePackages = lib.attrValues { inherit (pkgs.kdePackages) kate; }; # https://github.com/NixOS/nixpkgs/blob/b6eaf97c6960d97350c584de1b6dcff03c9daf42/nixos/modules/services/desktop-managers/plasma6.nix#L157-L180
  };

  fonts.enableDefaultPackages = true;
  fonts.packages = lib.attrValues { inherit (pkgs.nerd-fonts) iosevka-term-slab; };

  hardware = {
    enableRedistributableFirmware = true;

    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;

    cpu.intel.updateMicrocode = config.hardware.enableRedistributableFirmware;
  };

  i18n = {
    defaultLocale = "en_GB.UTF-8"; # https://wiki.archlinux.org/title/Locale
    supportedLocales = [ "all" ];

    inputMethod = {
      enable = true;
      type = "ibus";

      # ibus.engines = flakeDefaultPackage inputs.ibus-bamboo;
      # ibus.engines = with pkgs.ibus-engines; [ bamboo ];
    };
  };

  networking = {
    inherit hostName;

    networkmanager.enable = true;
  };

  nix = # https://github.com/NuschtOS/nixos-modules/blob/f8b6e1d4ea6c9c958b27445c70434b00e8d7f520/modules/nix.nix
    {
      deleteChannels = true;
      diffSystem = true;
      extraOptions = "!include ${config.sops.secrets.nix_cccp_pat.path}";

      channel.enable = false;

      settings = modules.mkMerge [
        {
          connect-timeout = 20;
          # max-jobs = 6; # https://nix.dev/manual/nix/development/advanced-topics/cores-vs-jobs.html
        }

        (quickMapAttrs true {
          inherit (config.nix.settings) auto-optimise-store builders-use-substitutes use-xdg-base-directories;
        })

        (attrsets.mapAttrs' (name: attrsets.nameValuePair "extra-${name}") {
          experimental-features = [
            "flakes"
            "nix-command"
            "no-url-literals"
            "pipe-operators" # https://discourse.nixos.org/t/lix-mismatch-in-feature-name-compared-to-nix/59879
          ];
          substituters = [
            "https://cache.thalheim.io" # https://github.com/Mic92/sops-nix/blob/787afce414bcce803b605c510b60bf43c11f4b55/flake.nix#L5-L8
            "https://crane.cachix.org" # https://github.com/ipetkov/crane/blob/70947c1908108c0c551ddfd73d4f750ff2ea67cd/flake.nix#L6-L9
            "https://nix-community.cachix.org"
          ];
          trusted-public-keys = [
            "cache.thalheim.io-1:R7msbosLEZKrxk/lKxf9BTjOOH7Ax3H0Qj0/6wiHOgc="
            "crane.cachix.org-1:8Scfpmn9w+hGdXH/Q9tTLiYAE/2dnJYRJP7kl80GuRk="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];
          trusted-users = [ "@wheel" ];
        })
      ];
    };

  nixCats.enable = true;
  nixCats.packageNames = [ "nixCats" ];

  nixpkgs = {
    inherit hostPlatform;

    overlays =
      /*
        https://nixos-and-flakes.thiscute.world/nixpkgs/overlays
        https://wiki.nixos.org/wiki/Overlays
      */
      [
        # inputs.firefox-addons-nix.overlays.default
        # (final: prev: { firefox-addons-custom = import inputs.firefox-addons-custom { inherit (prev) fetchurl lib stdenv; }; }) # https://gitlab.com/rycee/nur-expressions/-/issues/244#note_2314527761

        inputs.firefox-addons-custom.overlays.default
      ];

    config.allowUnfreePredicate =
      /*
        https://github.com/NixOS/nixpkgs/blob/1e5b653dff12029333a6546c11e108ede13052eb/pkgs/stdenv/generic/check-meta.nix#L114
        https://stackoverflow.com/questions/77585228/how-to-allow-unfree-packages-in-nix-for-each-situation-nixos-nix-nix-wit
        https://unix.stackexchange.com/questions/720902/how-to-use-packages-directly-in-allowunfreepredicate
      */
      pkg:
      {
        inherit (pkgs)
          cloudflare-warp
          steam
          stremio
          unrar
          ;
        inherit (pkgs.firefox-addons) betterttv tunnelbear-vpn-firefox;
      }
      |> lib.attrNames
      |> lib.concatStringsSep "|"
      |> (patterns: "(${patterns}).*")
      |> trivial.flip lib.match (
        pkg |> strings.getName
        # |> strings.removePrefix "firefox-addon-" # https://github.com/petrkozorezov/firefox-addons-nix/blob/71bfc87b45935f56730d7f0043adcd1944621a6e/flake.nix#L10
      )
      |> lib.isList;
  };

  powerManagement.enable = true;

  programs = modules.mkMerge [
    {
      # unneeded default programs
      command-not-found.enable = false;
      nano.enable = false;

      bash.blesh.enable = true;

      mtr.package = pkgs.mtr-gui;

      nh = {
        package = flakeDefaultPackage inputs.nh;

        flake = "/coding/nix/manixfest-cccp";

        clean.enable = true;
      };

      steam.dedicatedServer.openFirewall = true;
      steam.remotePlay.openFirewall = true;
    }

    (quickMapAttrs { enable = true; } {
      inherit (config.programs)
        adb
        kdeconnect
        mtr
        nh
        partition-manager
        steam
        ;
    })
  ];

  security = {
    # pam.services."kwallet-${admin}".kwallet = {
    #   enable = true;
    #   package = pkgs.kdePackages.kwallet-pam;
    #   forceRun = true;
    # };

    rtkit.enable = true;

    sudo-rs.enable = true; # https://github.com/trifectatechfoundation/sudo-rs#differences-from-original-sudo
  };

  services = modules.mkMerge [
    {
      desktopManager.plasma6.enable = true;

      displayManager.sddm.enable = true;
      displayManager.sddm.wayland.enable = true;

      # https://github.com/NixOS/nixpkgs/pull/391845/files#diff-baa8a52e693ad2787690e2e16f2780581b75da71a6764869aeb1fb00f013dee3
      geoclue2.geoProviderUrl = "https://api.beacondb.net/v1/geolocate";
      geoclue2.submissionUrl = "https://api.beacondb.net/v2/geosubmit";

      kanata.keyboards.${hostName}.configFile = ./auxiliary/${hostName}.kbd;

      pipewire = # https://wiki.archlinux.org/title/PipeWire
        {
          alsa.enable = true;
          alsa.support32Bit = true;

          jack.enable = true;

          pulse.enable = true;
        };
    }

    (quickMapAttrs { enable = true; } {
      inherit (config.services)
        cloudflare-warp
        earlyoom # https://old.reddit.com/r/NixOS/comments/10o0sdp/computer_hangs_when_all_ram_is_used/
        fwupd
        geoclue2
        kanata
        pipewire
        printing
        ;
    })
  ];

  sops = {
    defaultSopsFile = ./auxiliary/secrets.yaml;

    gnupg.home = config.home-manager.users.${admin}.programs.gpg.homedir;

    secrets =
      config.sops.defaultSopsFile
      |> strings.fileContents
      |> lib.match "(.*)\nsops:\n.*"
      |> lib.head
      |> strings.splitString "\n"
      |> lib.concatMap (e: e |> lib.match "(.*): ENC\\[.*]" |> trivial.defaultTo [ ])
      |> quickGenAttrs {
        group = config.users.groups.keys.name;
        mode = "0440";
      };
  };

  systemd.enableStrictShellChecks = true;

  system.rebuild.enableNg = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${admin} = {
    description = "Minh";
    extraGroups = [
      "keys" # https://github.com/Mic92/sops-nix#set-secret-permissionowner-and-allow-services-to-access-it
      "networkmanager"
      "root" # https://wiki.archlinux.org/title/Users_and_groups#System_groups
      "uinput" # https://github.com/jtroo/kanata/blob/f153fd0c549befada4f0c544b8e5bba4c2d010ad/docs/setup-linux.md
      "wheel"
    ];
    isNormalUser = true;
  };

  xdg.portal.enable = true;

  ### lcm
  # https://nix-community.github.io/nix-on-droid/nix-on-droid-options.html

  system.stateVersion = trivial.release;

  time.timeZone = "Asia/Bangkok";
}
