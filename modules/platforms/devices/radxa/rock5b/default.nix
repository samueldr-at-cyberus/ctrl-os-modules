{ config, lib, ... }:
let
  platform = config.ctrl-os.platform;
in
{
  config = lib.mkIf (platform == "radxa-rock5b") {

    nixpkgs.hostPlatform = "aarch64-linux";

    boot.initrd.availableKernelModules =
      builtins.trace "WARNING: THIS MODULE IS A STUB FOR TESTING PURPOSES!"
      [
      # TODO
    ];
  };
}
