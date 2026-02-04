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
        "nvidia-l4t-libwayland-egl1" = "sha256-rmcNTjLe6GXujlitMiXS8neLOEeXGIKqjmA9c3CjE/o=";
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

    set -x

    for el in usr/lib/aarch64-linux-gnu/*; do
      if test -L "$el"; then
        rm -v "$el"
      fi
    done
    rm -v usr/lib/aarch64-linux-gnu/*/ld.so.conf

    mkdir -vp $out/{lib,share}
    mv -vt $out/share usr/share/doc
    mv -vt $out/lib usr/lib/aarch64-linux-gnu/*/*

    mkdir -vp $out/share/egl/egl_external_platform.d/
    mv -t $out/share/egl/egl_external_platform.d/ ./usr/share/egl/egl_external_platform.d/nvidia_gbm.json

    (
      cd $out/lib

      # Fixup links we broke
      for lib in tegra-udrm_gbm.so tegra_gbm.so nvidia-drm_gbm.so; do
       ln -fs libnvidia-allocator.so "$lib"
      done

      mkdir -vp ../share/vulkan/icd.d
      mv -v nvidia_icd.json ../share/vulkan/icd.d/nvidia_icd.aarch64.json
      substituteInPlace ../share/vulkan/icd.d/nvidia_icd.aarch64.json \
        --replace-fail "libGLX_nvidia.so.0" "$PWD/libGLX_nvidia.so.0"

      mkdir -vp ../share/glvnd/egl_vendor.d/
      mv -v nvidia.json ../share/glvnd/egl_vendor.d/50_nvidia.json
      substituteInPlace ../share/glvnd/egl_vendor.d/50_nvidia.json \
        --replace-fail "libEGL_nvidia.so.0" "$PWD/libEGL_nvidia.so.0"

      substituteInPlace ../share/egl/egl_external_platform.d/nvidia_gbm.json \
        --replace-fail "libnvidia-egl-gbm.so.1" "$PWD/libnvidia-egl-gbm.so.1"

      # Apparently `runtimeDependencies` only gets added to .so where the
      # autoPatchelfHook changed the .so...
      # Let's make sure any `dlopen`, such as found in `libnvos`, works.
      for lib in *.so*; do
        patchelf --add-rpath "$out/lib" "$lib"
      done
    )

    runHook postInstall
  '';

  # FIXME:
  # - runtimeDependencies doesn't actually work
  # - autoPatchelfHook is missing stuff??
  # - we'll call the autopatchelf bash function ourselves...
  # - so we'll use dontAutoPatchelf...
  # - AFAICT autopatchelf is ignoring our desire to add an rpath...

  runtimeDependencies = [
    (placeholder "out")
  ];

  # Don't strip "unnecessary" rpath values out
  dontPatchELF = true;
  # Also don't even try stripping vendor libraries.
  dontStrip = true;

  meta = {
    licenses = [
      lib.licenses.unfree
    ];
  };
}
