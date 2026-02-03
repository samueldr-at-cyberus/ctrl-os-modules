{ config, lib, pkgs, ... }:

let
  cfg = config.ctrl-os.hardware.devices.nvidia-jetson-orin-nano-super;
in
{
  options = {
    ctrl-os.hardware.devices.nvidia-jetson-orin-nano-super = {
      enableOotModules = lib.mkEnableOption "the NVIDIA Out-Of-Tree kernel modules" // {
        default = true;
      };
      enableProprietaryLibraries = lib.mkEnableOption "the NVIDIA graphical and ML drivers" // {
        default = true;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.hostPlatform = "aarch64-linux";

    boot.initrd.availableKernelModules = [
      # Enable PCIe support at boot time
      "phy_tegra194_p2u"
      "pcie_tegra194"
      # Enable USB support for USB Boot
      "xhci-tegra"
      "phy-tegra-xusb"
    ];

    boot.extraModulePackages = lib.mkMerge [
      (lib.mkIf cfg.enableOotModules [
        (config.boot.kernelPackages.callPackage ./nvidia-oot { })
      ])
    ];

    # We can add the packages to the overlay even without enabling the
    # *configuration* for the proprietary packags.
    nixpkgs.overlays = [
      (
        final: super:
        {
          nvidia-jetson-orin-nano-super = {
            nvidia-l4t = final.callPackage ./nvidia-l4t { };
            nvidia-core = final.callPackage ./nvidia-core { };
            nvidia-3d-core = final.callPackage ./nvidia-3d-core {
              # FIXME: use a scope?
              inherit (final.nvidia-jetson-orin-nano-super)
                nvidia-core
              ;
            };
          };
        }
      )
    ];

    hardware.graphics.extraPackages = lib.mkMerge [
      (lib.mkIf cfg.enableProprietaryLibraries [
        pkgs.nvidia-jetson-orin-nano-super.nvidia-3d-core
      ])
    ];
  };
}
