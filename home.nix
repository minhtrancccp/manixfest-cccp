{
  lib,

  admin,
  hostPlatform,

  flakeDefaultPackage,
  genericMapAttrs,
  quickGenAttrs,
  quickMapAttrs,

  inputs,
  ...
}:
{
  home-manager = {
    backupFileExtension = "hm-bak"; # quick dotfiles fix
    sharedModules = lib.attrValues {
      inherit (inputs.nix-index-database.hmModules) nix-index;
      inherit (inputs.plasma-manager.homeManagerModules) plasma-manager;
      inherit (inputs.xhmm.homeManagerModules.console) program-variables;
    };
    useGlobalPkgs = true;
    useUserPackages = true;

    extraSpecialArgs = {
      inherit
        admin
        hostPlatform

        flakeDefaultPackage
        genericMapAttrs
        quickGenAttrs
        quickMapAttrs

        inputs
        ;
    };

    users.${admin} = import ./${admin}.nix;
  };
}
