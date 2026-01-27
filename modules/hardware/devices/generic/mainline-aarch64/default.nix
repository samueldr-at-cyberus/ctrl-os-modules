{ config, lib, ... }:

let
  cfg = config.ctrl-os.hardware.devices.generic-mainline-aarch64;
in
{
  config = lib.mkIf cfg.enable {
    nixpkgs.hostPlatform = "aarch64-linux";
  };
}
