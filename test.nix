{ pkgs ? import <nixpkgs> {} }:

pkgs.appendOverlays([
  (
  final: super:
  {
    nvidia-oot = final.linuxPackages.callPackage modules/hardware/devices/nvidia/jetson-orin-nano-super/nvidia-oot/default.nix {};
  }
  )
])
