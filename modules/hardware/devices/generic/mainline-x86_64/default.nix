{ config, lib, ... }:

let
  cfg = config.ctrl-os.hardware.devices.generic-mainline-x86_64;
in
{
  config = lib.mkIf cfg.enable {
    nixpkgs.hostPlatform = "x86_64-linux";
  };
}
