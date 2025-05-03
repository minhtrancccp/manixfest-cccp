{
  description = "desktop configuration";

  inputs =
    /*
      https://discourse.nixos.org/t/why-cant-i-use-let-variables-in-flake-nix-inputs/39929
      https://old.reddit.com/r/NixOS/comments/176ygv0/question_regarding_flake_inputs_why_do_they_have/
      https://old.reddit.com/r/NixOS/comments/1hhizxa/how_to_correctly_use_inputsfollows/
    */
    {
      atuin.url = "github:atuinsh/atuin";
      codeberg-cli.url = "https://codeberg.org/aviac/codeberg-cli/archive/HEAD.tar.gz";
      disko.url = "github:nix-community/disko";
      envfs.url = "github:mic92/envfs"; # https://old.reddit.com/r/NixOS/comments/1g1kbvu/shebang/
      firefox-addons-custom.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      # firefox-addons-nix.url = "github:petrkozorezov/firefox-addons-nix"; # https://github.com/piroor/copy-selected-tabs-to-clipboard/issues/58
      flake-firefox-nightly.url = "github:nix-community/flake-firefox-nightly";
      handlr-regex.url = "github:anomalocaridid/handlr-regex";
      home-manager.url = "github:nix-community/home-manager";
      ibus-bamboo.url = "github:bambooengine/ibus-bamboo";
      nh.url = "github:viperml/nh";
      nix-converter.url = "github:theobori/nix-converter";
      nix-index-database.url = "github:nix-community/nix-index-database";
      nix-inspect.url = "github:bluskript/nix-inspect";
      nix-tree.url = "github:utdemir/nix-tree";
      nixCats-cccp.url = "path:/coding/nix/nixCats-cccp";
      # nixcord.url = "github:kaylorben/nixcord";
      nixfmt.url = "github:nixos/nixfmt";
      nuschtos-nixos-modules.url = "github:nuschtos/nixos-modules";
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # https://old.reddit.com/r/NixOS/comments/1bo8l1f/how_to_obtain_most_recent_cached_version_of/
      nixpkgs-review.url = "github:mic92/nixpkgs-review";
      pay-respects.url = "github:iffse/pay-respects";
      plasma-manager.url = "github:nix-community/plasma-manager";
      ripgrep-all.url = "github:phiresky/ripgrep-all";
      sops-nix.url = "github:mic92/sops-nix";
      statix.url = "github:oppiliappan/statix";
      xdg-ninja.url = "github:b3nj5m1n/xdg-ninja";
      yazi.url = "github:sxyazi/yazi";
    };

  outputs =
    inputs@{
      disko,
      envfs,
      home-manager,
      nixCats-cccp,
      nixfmt,
      nuschtos-nixos-modules,
      nixpkgs,
      sops-nix,
      ...
    }:
    let
      inherit (nixpkgs) lib; # https://discourse.nixos.org/t/access-lib-in-flake-before-pkgs-is-available/37957
      inherit (lib) trivial;

      hostPlatform = "x86_64-linux";
      hostName = "laptop-cccp";

      flakeDefaultPackage = flake: flake.packages.${hostPlatform}.default;
      genericMapAttrs = func: func |> trivial.const |> lib.mapAttrs;
      quickMapAttrs = value: value |> trivial.const |> genericMapAttrs;
    in
    {
      formatter.${hostPlatform} = flakeDefaultPackage nixfmt;

      nixosConfigurations.${hostName} = lib.nixosSystem {
        modules =
          [
            envfs.nixosModules.envfs
            nuschtos-nixos-modules.nixosModules.nix

            ./configuration.nix
            ./home.nix
          ]
          ++ lib.map (flake: flake.nixosModules.default) [
            disko
            home-manager
            nixCats-cccp
            sops-nix
          ];

        specialArgs = {
          inherit
            hostName
            hostPlatform

            flakeDefaultPackage
            genericMapAttrs
            quickMapAttrs

            inputs
            ;

          admin = "usercccp";

          quickGenAttrs = value: value |> trivial.const |> trivial.flip lib.attrsets.genAttrs;
        };
      };
    };
}
