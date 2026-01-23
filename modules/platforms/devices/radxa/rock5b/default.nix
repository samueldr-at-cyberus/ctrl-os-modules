{ lib, ... }:
{
  nixpkgs.hostPlatform = "aarch64-linux";

  boot.initrd.availableKernelModules =
    builtins.trace "WARNING: THIS MODULE IS A STUB FOR TESTING PURPOSES!"
    [
    # TODO
  ];
}
