let
  # NOTE: This is not exposed in the arguments for this callPackage-pattern
  #       package, as it wouldn't work in overriding as expected.
  #       This version is used for `fetchurl` and for the `mkDerivation` later.
  version = "36.4.7-20250918154033";
in
{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, dpkg

, expat
, libxext
, libX11
, libdrm
, libgbm
, libffi

,
  # `srcs` is exposed in `passthru` to allow easily overriding `srcs`.
  #
  #     let p = linuxPackages.nvidia-l4t; in
  #     p.override {
  #        srcs = p.srcs // {
  #          linux-nv-oot = builtins.fetchGit .../linux-nv-oot;
  #        };
  #     })
  srcs ?
    let
      # These packages were identified by comparing the x86_64 proprietary
      # driver library names, and matching those found in the BSP.
      # Then, packags that were dependencies added as needed.
      packages = {
        "nvidia-l4t-core" = "sha256-MtaXaH25dmuQwCFlXcSeYlWOfIQ6UoZ8hXM8NGryg+E=";
        "nvidia-l4t-3d-core" = "sha256-uOebamU6vOuzrCHIDdGejR5cTBIQIz0D3TQM0/GoTFs=";
        "nvidia-l4t-gbm" = "sha256-fz6z48Hzf6tzV4TbSB4lkLXdhFiLjkX3S+ia+atbS8A=";

        # egl-wayland
        "nvidia-l4t-wayland" = "sha256-EY/21rNnF2SyuX+B5u15IFsV2Ct4euLc6qH3x1h7R8w=";
        # Dep for `nvidia-l4t-wayland`
        "nvidia-l4t-libwayland-client0" = "sha256-ZEu0d2Ylj5fWjH7QvF9BSMGC6CZmGlezuKF7f2Gql/M=";
        # Dep for `nvidia-l4t-wayland`
        "nvidia-l4t-libwayland-server0" = "sha256-tbL7bYdsEMwAQ+ltk2niVBpqtGPLP3YUlhXDl7elSM4=";
        # vksc-core
        "nvidia-l4t-vulkan-sc" = "sha256-EjdA84U1P6/dya2fjfbPEP5XQyO8pnoLIfb433wQ52s=";

        # libnvcuvid
        #"nvidia-l4t-multimedia" = "";
        # libcuda
        "nvidia-l4t-cuda" = "sha256-CaFTxuYZ+hrSuiEw/4HJBjDXrHkSb5t3ZcqEFELPyL4=";
        # Deps for cuda
        "nvidia-l4t-nvsci" = "sha256-+X4RMGKlA0FuEVTGGnnoQSe8Kjh4M975C4AoyxxNFE8=";
        # libnvidia-ml
        "nvidia-l4t-nvml" = "sha256-+fRq0H/aIiKaAab/C/njF70U9QmFF7xywLdqXGBfxfA=";
      };
    in
    builtins.mapAttrs (
      package: hash:
      fetchurl{
        url = "https://repo.download.nvidia.com/jetson/t234/pool/main/n/${package}/${package}_${version}_arm64.deb";
        inherit hash;
      }
    ) packages,
}:




# Listing found here:
#   - https://repo.download.nvidia.com/jetson/

stdenv.mkDerivation {
  pname = "nvidia-l4t";
  inherit version;

  unpackPhase = ''
    runHook preUnpack

    ${lib.concatStringsSep "\n" (
      # We can extract all packages at once, as they shouldn't conflict with eachother.
      # This way we don't need to bother with juggling all those directory structures,
      # it's already in the form of the installed system.
      lib.mapAttrsToList (name: src: ''
        printf '\n:: Extracting package %q\n' "${name}"
        dpkg -x "${src}" ./
      '') srcs
    )}

    runHook postUnpack
  '';


  buildInputs = [
    # Dependencies being patchelf'd
    stdenv.cc.cc
    expat
    libxext
    libX11
    libdrm
    libgbm
    libffi
  ];

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libEGL.so.1"
  ];

  installPhase = ''
    runHook preInstall

    for el in usr/lib/aarch64-linux-gnu/*; do
      if test -L "$el"; then
        rm -v "$el"
      fi
    done
    rm -v usr/lib/aarch64-linux-gnu/*/ld.so.conf

    mkdir -vp $out/{lib,share}
    mv -vt $out/share usr/share/doc
    mv -vt $out/lib usr/lib/aarch64-linux-gnu/*/*

    # Fixup links we broke
    (cd $out/lib
      for lib in tegra-udrm_gbm.so tegra_gbm.so nvidia-drm_gbm.so; do
       ln -fs libnvidia-allocator.so "$lib"
      done
    )

    runHook postInstall
  '';

  meta = {
    licenses = [
      lib.licenses.unfree
    ];
  };
}

/*

ERROR: noBrokenSymlinks: the symlink .../lib/tegra-udrm_gbm.so points to a missing target: /nix/store/xd18hs3yk542rbd6axp567xzwsn5naqd-nvidia-l4t-36.4.7-20250918154033/nvidia/libnvidia-allocator.so
ERROR: noBrokenSymlinks: the symlink .../lib/tegra_gbm.so points to a missing target: /nix/store/xd18hs3yk542rbd6axp567xzwsn5naqd-nvidia-l4t-36.4.7-20250918154033/nvidia/libnvidia-allocator.so
ERROR: noBrokenSymlinks: the symlink .../lib/nvidia-drm_gbm.so points to a missing target: /nix/store/xd18hs3yk542rbd6axp567xzwsn5naqd-nvidia-l4t-36.4.7-20250918154033/nvidia/libnvidia-allocator.so


error: auto-patchelf could not satisfy dependency libwayland-client.so.0 wanted by /nix/store/k76zs80pj84jln60dar1yfpm88gdwacm-nvidia-l4t-36.4.7-20250918154033/lib/libnvidia-egl-wayland.so.1.1.11
error: auto-patchelf could not satisfy dependency libwayland-server.so.0 wanted by /nix/store/k76zs80pj84jln60dar1yfpm88gdwacm-nvidia-l4t-36.4.7-20250918154033/lib/libnvidia-egl-wayland.so.1.1.11

*/

