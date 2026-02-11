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

    boot.kernelPackages =
      # OOT modules support up to 6.12
      # XXX still does not work *as-is* with OOT modules.
      # [   27.079679] [drm:nv_drm_master_set [nvidia_drm]] *ERROR* [nvidia-drm] [GPU ID 0x00020000] Failed to grab modeset ownership
      # I suspect it's `simpledrm` related.
      pkgs.linuxPackages_6_12

      # Vendor kernel
      #pkgs.nvidia-jetson-orin-nano-super.nvidia-l4t-kernelPackages
    ;

    boot.extraModulePackages = lib.mkMerge [
      (lib.mkIf cfg.enableOotModules [
        (config.boot.kernelPackages.callPackage ./nvidia-oot { })
      ])
    ];

    boot.blacklistedKernelModules = [
      # FIXME: figure out ***why*** vendor blacklists it.
      # Source: nvidia-l4t-init_36.4.4-20250616085344_arm64:etc/modprobe.d/denylist-tpm-ftpm-tee.conf
      #"tpm_ftpm_tee"
      # XXX was it blacklisting this that made the device unreliable to boot once past "switch root"?
      # Probably not...

      # Prevent upstream audio drivers from being loaded.
      "snd_soc_tegra_audio_graph_card"

      # This is blacklisted so it doesn't get auto-loaded.
      # The `tegra_drm` module will load it as needed.
      "nvidia_drm"
    ];

    boot.kernelModules = [
      "tegra_drm"
      # This *cannot* be loaded with `tegra_drm` or else it breaks.
      # "nvidia_drm"
    ];

    boot.extraModprobeConfig = lib.mkMerge [
      # Without `modeset`, the X11 driver will fail to work.
      # This is the vendor-suggested configuration.
      "options nvidia_drm modeset=1 fbdev=1"
    ];

    users.groups = {
      # Mostly to shut up udev rules
      #
      #     /etc/udev/rules.d/99-tegra-devices.rules:00 Unknown group 'debug', ignoring.
      debug = { };
    };

    services.xserver = {
      # Use the `nvidia` driver for `tegra` kernel driver matches.
      config = ''
        Section "OutputClass" 
          Identifier "nvidia" 
          MatchDriver "tegra" 
          Driver "nvidia"
        EndSection 
      '';

      # Vendor applies those "optimizations".
      moduleSection = ''
        Disable "dri"
        SubSection "extmod"
          Option "omit xfree86-dga"
        EndSubSection
      '';

      # NOTE: videoDrivers cannot be used.
      # Enabling `"nvidia"` within it uses the non-l4t NVIDIA driver.
      drivers = lib.mkForce (lib.singleton {
        name = "nvidia";
        modules = [ pkgs.nvidia-jetson-orin-nano-super.nvidia-l4t ];
        display = true;
        deviceSection = /*
          # Those are added by the NixOS module.
          Identifier "Tegra0"
          Driver "nvidia"
        */ ''
          Option "AllowEmptyInitialConfiguration" "true"
        '';
      });

      displayManager.xserverArgs = [
        "-logverbose 6"
      ];
    };

    boot.kernelPatches = [
      {
        name = "nvidia-disable-simpledrm";
        patch = null;
        structuredExtraConfig = {
          # Vendor assumes this configuration is used.
          FB_SIMPLE = lib.kernel.yes;
          DRM_SIMPLEDRM = lib.mkForce lib.kernel.no;
        };
      }
    ];

    # We can add the packages to the overlay even without enabling the
    # *configuration* for the proprietary packages.
    nixpkgs.overlays = [
      (
        final: super:
        {
          nvidia-jetson-orin-nano-super = {
            nvidia-oot = config.boot.kernelPackages.callPackage ./nvidia-oot { };
            nvidia-l4t = final.callPackage ./nvidia-l4t { };
            nvidia-l4t-firmware = final.callPackage ./nvidia-l4t-firmware {
              inherit
                (final.nvidia-jetson-orin-nano-super)
                nvidia-l4t
              ;
            };

            nvidia-l4t-kernel =
              final.buildLinux {
                version = "5.15.185.rel-36_eng_2026-01-04";
                # Tag jetson_36.5 for 36.5.0
                modDirVersion = "5.15.185";
                src = final.fetchFromGitLab {
                  owner = "nvidia";
                  repo = "nv-tegra/3rdparty/canonical/linux-jammy";
                  rev = "rel-36_eng_2026-01-04";
                  hash = "sha256-Xr2lscaMEwKNn8IA2CCM4NzR6jNVsqeiaxp9onuTxsI=";
                };
                structuredExtraConfig = {
                  # Driver build is broken from backport of new drivers.
                  # ../drivers/media/pci/intel/ipu6/../ipu-dma.c:53:17: error: implicit declaration of function 'clflush_cache_range'; did you mean 'flush_cache_range'? [-Werror=implicit-function-declaration]
                  VIDEO_INTEL_IPU6 = lib.kernel.no;

                  # Vendor assumes this configuration is used.
                  FB_SIMPLE = lib.kernel.yes;
                  DRM_SIMPLEDRM = lib.mkForce lib.kernel.no;

                  ARCH_TEGRA = lib.kernel.yes;
                  # Minify build
                  ARCH_ACTIONS = lib.kernel.no;
                  ARCH_SUNXI = lib.kernel.no;
                  SUN8I_DE2_CCU = lib.mkForce (lib.kernel.option lib.kernel.no);
                  ARCH_ALPINE = lib.kernel.no;
                  ARCH_APPLE = lib.kernel.no;
                  ARCH_BCM2835 = lib.kernel.no;
                  ARCH_BCM4908 = lib.kernel.no;
                  DRM_VC4 = lib.mkForce lib.kernel.no;
                  DRM_VC4_HDMI_CEC = lib.mkForce (lib.kernel.option lib.kernel.no);
                  ARCH_BCM_IPROC = lib.kernel.no;
                  ARCH_BERLIN = lib.kernel.no;
                  ARCH_BRCMSTB = lib.kernel.no;
                  ARCH_EXYNOS = lib.kernel.no;
                  ARCH_K3 = lib.kernel.no;
                  ARCH_LAYERSCAPE = lib.kernel.no;
                  ARCH_LG1K = lib.kernel.no;
                  ARCH_HISI = lib.kernel.no;
                  ARCH_KEEMBAY = lib.kernel.no;
                  ARCH_MEDIATEK = lib.kernel.no;
                  NET_VENDOR_MEDIATEK = lib.mkForce (lib.kernel.option lib.kernel.no);
                  ARCH_MESON = lib.kernel.no;
                  ARCH_MVEBU = lib.kernel.no;
                  ARCH_MXC = lib.kernel.no;
                  ARCH_QCOM = lib.kernel.no;
                  ARCH_RENESAS = lib.kernel.no;
                  ARCH_ROCKCHIP = lib.kernel.no;
                  ARCH_S32 = lib.kernel.no;
                  ARCH_SEATTLE = lib.kernel.no;
                  ARCH_INTEL_SOCFPGA = lib.kernel.no;
                  ARCH_SYNQUACER = lib.kernel.no;
                  ARCH_SPRD = lib.kernel.no;
                  ARCH_THUNDER = lib.kernel.no;
                  ARCH_THUNDER2 = lib.kernel.no;
                  ARCH_UNIPHIER = lib.kernel.no;
                  ARCH_VEXPRESS = lib.kernel.no;
                  ARCH_VISCONTI = lib.kernel.no;
                  ARCH_XGENE = lib.kernel.no;
                  ARCH_ZYNQMP = lib.kernel.no;

                  # Fallout from disabling some architectures...
                  FSL_MC_UAPI_SUPPORT = lib.mkForce (lib.kernel.option lib.kernel.no);

                  # Other stuff
                  DRM_AMD_ACP = lib.mkForce (lib.kernel.option lib.kernel.no);
                  DRM_AMD_DC_HDCP = lib.mkForce (lib.kernel.option lib.kernel.no);
                  DRM_AMD_DC_SI = lib.mkForce (lib.kernel.option lib.kernel.no);
                  DRM_AMDGPU_CIK = lib.mkForce (lib.kernel.option lib.kernel.no);
                  DRM_AMDGPU = lib.mkForce (lib.kernel.option lib.kernel.no);
                  DRM_AMDGPU_SI = lib.mkForce (lib.kernel.option lib.kernel.no);
                  DRM_AMDGPU_USERPTR = lib.mkForce (lib.kernel.option lib.kernel.no);
                  DRM_RADEON = lib.mkForce (lib.kernel.option lib.kernel.no);
                  HSA_AMD = lib.mkForce (lib.kernel.option lib.kernel.no);
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
      "glvnd/egl_vendor.d".source = "/run/opengl-driver/share/glvnd/egl_vendor.d";
    };
    # FIXME: mkif
    services.udev.packages = [
      pkgs.nvidia-jetson-orin-nano-super.nvidia-l4t
    ];
    # FIXME: mkif
    hardware.firmware = lib.mkAfter [
      pkgs.nvidia-jetson-orin-nano-super.nvidia-l4t-firmware
    ];
    # With *at least the vendor kernel*, it looks like xz firmware aren't used 
    # /run/current-system/firmware/nvidia/ga10b/gpmu_ucode_next_prod_image.bin.xz
    # [    0.000000] gk20a 17000000.gpu: Direct firmware load for ga10b/gpmu_ucode_next_prod_image.bin failed with error -2
    # [    0.000000] gk20a 17000000.gpu: Direct firmware load for tegra23x/gpmu_ucode_next_prod_image.bin failed with error -2
    #
    # This might be why:
    #
    #     /etc/nixos $ zcat /proc/config.gz |  grep -i fw.loader | sort -u
    #     # CONFIG_FW_LOADER_COMPRESS_XZ is not set
    #     CONFIG_FW_LOADER_COMPRESS=y
    #     # CONFIG_FW_LOADER_COMPRESS_ZSTD is not set
    #     CONFIG_FW_LOADER_PAGED_BUF=y
    #     # CONFIG_FW_LOADER_USER_HELPER_FALLBACK is not set
    #     CONFIG_FW_LOADER_USER_HELPER=y
    #     CONFIG_FW_LOADER=y
    #
    hardware.firmwareCompression = "none";

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
