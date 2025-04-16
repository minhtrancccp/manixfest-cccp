{
  lib,

  admin,
  hostPlatform,

  enableMapAttrs,
  flakeDefaultPackage,
  quickGenAttrs,
  quickMapAttrs,

  inputs,
  ...
}:
{
  home-manager = {
    backupFileExtension = "hm-bak"; # quick dotfiles fix
    useGlobalPkgs = true;
    useUserPackages = true;

    sharedModules = lib.attrValues {
      inherit (inputs.nix-index-database.hmModules) nix-index;
      inherit (inputs.plasma-manager.homeManagerModules) plasma-manager;
      inherit (inputs.xhmm.homeManagerModules.console) program-variables;
    };

    extraSpecialArgs = {
      inherit
        admin
        hostPlatform

        enableMapAttrs
        flakeDefaultPackage
        quickGenAttrs
        quickMapAttrs

        inputs
        ;
    };

    users.${admin} = import ./${admin}.nix;
  };
}
