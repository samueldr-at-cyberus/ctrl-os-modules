{ pkgs ? import <nixpkgs> {} }:

let
  hack =
    import modules/hardware/devices/nvidia/jetson-orin-nano-super/default.nix {
      config = {};
      inherit (pkgs) lib;
      pkgs = {};
    }
  ;
in
  pkgs.appendOverlays
  hack
  .config.content.nixpkgs.overlays
