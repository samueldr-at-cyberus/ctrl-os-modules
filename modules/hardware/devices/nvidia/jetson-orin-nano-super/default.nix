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
      # Reminder device enablement modules should not set the unfree software option.
      # The module *must* fail with the unfree software error.
      # The user must make the informed decision about enabling unfree software.
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
      # FIXME: mkif ?
      (lib.mkIf true [
        pkgs.nvidia-jetson-orin-nano-super.nvidia-open-gpu-kernel-modules
      ])
    ];


    boot.blacklistedKernelModules = [
      # FIXME: figure out ***why*** vendor blacklists it.
      # Source: nvidia-l4t-init_36.4.4-20250616085344_arm64:etc/modprobe.d/denylist-tpm-ftpm-tee.conf
      # "tpm_ftpm_tee"
      # XXX was it blacklisting this that made the device unreliable to boot once past "switch root"?

      # Prevent upstream audio drivers from being loaded.
      "snd_soc_tegra_audio_graph_card"

      # XXX when using proprietary drivers
      "tegra_drm"
    ];

    # We can add the packages to the overlay even without enabling the
    # *configuration* for the proprietary packags.
    nixpkgs.overlays = [
      (
        final: super:
        {
          nvidia-jetson-orin-nano-super = {
            nvidia-open-gpu-kernel-modules =
              config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs(oldAttrs: {
                buildInputs = (oldAttrs.buildInputs or []) ++ [
                  final.nvidia-jetson-orin-nano-super.nvidia-oot
                ];
              })
            ;
            nvidia-oot = config.boot.kernelPackages.callPackage ./nvidia-oot { };
            nvidia-l4t = final.callPackage ./nvidia-l4t { };
            nvidia-l4t-firmware = final.callPackage ./nvidia-l4t-firmware { };

            nvidia-l4t-kernel =
              final.buildLinux {
                version = "5.15.185.rel-36_eng_2026-01-04";
                modDirVersion = "5.15.185";
                src = final.fetchFromGitLab {
                  owner = "nvidia";
                  repo = "nv-tegra/3rdparty/canonical/linux-jammy";
                  rev = "rel-36_eng_2026-01-04";
                  hash = "sha256-Xr2lscaMEwKNn8IA2CCM4NzR6jNVsqeiaxp9onuTxsI=";
                };
              }
            ;
            nvidia-l4t-kernelPackages =
              final.linuxPackagesFor
              final.nvidia-jetson-orin-nano-super.nvidia-l4t-kernel
            ;
          };
        }
      )
    ];

    # FIXME: mkif
    environment.etc = {
      "egl/egl_external_platform.d".source = "/run/opengl-driver/share/egl/egl_external_platform.d/";
    };
    # FIXME: mkif
    services.udev.packages = [
      pkgs.nvidia-jetson-orin-nano-super.nvidia-l4t
    ];
    # FIXME: mkif
    hardware.firmware = [
      pkgs.nvidia-jetson-orin-nano-super.nvidia-l4t-firmware
    ];
    boot.kernelParams = [
      # Prevent simple-framebuffer from picking-up the framebuffer.
      # FIXME: this could be breaking the proprietary drivers?
      # FIXME: This doesn't work anyway on DT platforms.
      "initcall_blacklist=sysfb_init"
    ];


    hardware.graphics.extraPackages = lib.mkMerge [
      (lib.mkIf cfg.enableProprietaryLibraries [
        pkgs.nvidia-jetson-orin-nano-super.nvidia-l4t
      ])
    ];
  };
}
