{ self, pkgs }:

let
  inherit (pkgs) lib;
  inherit (pkgs.stdenv.hostPlatform) system;

  # Evaluate a NixOS configuration without relying on the Flakes entrypoint.
  evalConfig =
    { system ? null, ... }@config:
    (import (pkgs.path + "/nixos/lib/eval-config.nix"))
    (config // {
      inherit system;
    })
  ;

  # Borrow an arbitrary NixOS eval for evaluating the final `options` with
  # our `platforms` module imported.
  inherit
    (evalConfig {
      modules = [ self.nixosModules.platform ];
      # The system does not matter, we only need to evaluate up to the options.
      inherit (pkgs.stdenv.hostPlatform) system;
    })
    options
  ;

  platforms =
    # Get the platform option
    options.ctrl-os.platform
      # Unwrap the nullOr
      .type.functor.payload
      # Dig into the `enum`
      .elemType.functor.payload
      # And get the values
      .values
  ;

  evaluate =
    platform:
    { modules ? []
    , config ? {}
    , output ? [ "system" "build" "toplevel" ]
    }:

    let
      eval =
        evalConfig {
          modules = modules ++ [
            (
              { config, ... }:
              {
                imports = [
                  self.nixosModules.platform
                  self.nixosModules.developer
                ];

                ctrl-os.developer.enable = true;
                ctrl-os.platform = platform;
                nixpkgs.hostPlatform = "aarch64-linux";
                nixpkgs.buildPlatform = system;
                system.stateVersion = "25.11";
                system.nixos.tags = [
                  (
                    if config.nixpkgs.hostPlatform.system == config.nixpkgs.buildPlatform.system
                    then "native"
                    else "cross-from-${config.nixpkgs.buildPlatform.system}"
                  )
                ];
              }
            )
            config
          ];
        }
      ;
    in
    (
      lib.getAttrFromPath
      output
      eval.config
    ) // { inherit eval; }
  ;
  evaluateInstaller =
    platform:
    path:
    let
      installer = evaluate platform {
        config =
          { modulesPath, ... }:
          {
            imports = [
              "${modulesPath}/installer/${path}"
            ];
          }
        ;
      };
      inherit (installer.eval.config.system) build;
    in
      (
        build.isoImage
        or build.sdImage
        or (builtins.throw "Unable to guess the artifact type for installer path ${builtins.toJSON path}")
      ) // { inherit (installer) eval; }
  ;
in
{
  platforms.installers =
    lib.listToAttrs
    (
      lib.map
      (
        platform:
        let mkInstaller = evaluateInstaller platform; in
        {
          name = platform;
          value =
            {
              iso = mkInstaller "cd-dvd/installation-cd-minimal.nix";
              sd-image-new-kernel = mkInstaller "sd-card/sd-image-aarch64-new-kernel-no-zfs-installer.nix";
            }
          ;
        }
      )
      platforms
    )
  ;
}
