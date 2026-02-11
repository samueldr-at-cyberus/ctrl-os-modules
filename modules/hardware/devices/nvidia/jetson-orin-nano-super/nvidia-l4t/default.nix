let
  # NOTE: This is not exposed in the arguments for this callPackage-pattern
  #       package, as it wouldn't work in overriding as expected.
  #       This version is used for `fetchurl` and for the `mkDerivation` later.
  # NOTE: This needs to be updated and match with the compatible `nv-oot` version.
  version = "36.4.4-20250616085344";
in
{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, dpkg

, coreutils
, expat
, libxext
, libX11
, libGL
, libdrm
, libgbm
, libffi
, dbus

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
        "36.4.4-20250616085344" = {
          "nvidia-l4t-core" = "sha256-BJdWB9Eh3WeanwJpOdXBJt2eaCu7prccAZQiEuvCsJA=";
          "nvidia-l4t-3d-core" = "sha256-EkQPDv+H/yKQZyb9rWHYeiaBv4rOnYJLiyCODujf28w=";
          "nvidia-l4t-gbm" = "sha256-VszXZ56OJrfo6ufcIR2zAXO54Pgfrxo7Mfb0xTXdZKk=";

          # egl-wayland
          "nvidia-l4t-wayland" = "sha256-cXEnnC0nwCOYAhWR6/pBVS+FkotVF0MsnALyxkViUUw=";
          "nvidia-l4t-libwayland-egl1" = "sha256-uRJRVIF9nUDBFx89hPfETlAD1+G/zHjr95xQephMbRs=";
          # Dep for `nvidia-l4t-wayland`
          "nvidia-l4t-libwayland-client0" = "sha256-7r4FvQAxGORnQ9uBCE5X8EtKlfGj9Ln2mu/Vam6yQ1U=";
          # Dep for `nvidia-l4t-wayland`
          "nvidia-l4t-libwayland-server0" = "sha256-rCPc8rK4OxivTsH4LTWlvJ+AE+0dcEKM1lll7qYsUIk=";
          # vksc-core
          "nvidia-l4t-vulkan-sc" = "sha256-f3F2Sl8vHqmJ9XtybcZjAMA7vq8ZWtQDyryOJPSu4uU=";

          # libnvcuvid
          #"nvidia-l4t-multimedia" = "";
          # libcuda
          "nvidia-l4t-cuda" = "sha256-t7y51bbBA0exxNBc0lQO3F5p9DjZvSSf/wDFNve+oMs=";
          # Deps for cuda
          "nvidia-l4t-nvsci" = "sha256-PtdvksmTO+m1LpBf4MtoPps4QCgts67Ada9U8+e7wCQ=";
          # libnvidia-ml
          "nvidia-l4t-nvml" = "sha256-u+lJ/wwnkiHhMnqwAAa1BeShzU/UbTD4ATTJDWK68Dw=";

          # Configuration files that end-up being required
          "nvidia-l4t-init" = "sha256-FlylFyV8xP+JoXr+g/bZ4E34Yw9Vg38GSfeS3MrvwVY=";
        };
        "36.4.7-20250918154033" = {
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

          # Configuration files that end-up being required
          "nvidia-l4t-init" = "sha256-am/ede7X+URfzYysbSOtUO/J5shM46V3TwaVXzTsL44=";
        };
      };
    in
    builtins.mapAttrs (
      package: hash:
      fetchurl rec {
        name = "${package}_${version}_arm64.deb";
        url = "https://repo.download.nvidia.com/jetson/t234/pool/main/n/${package}/${name}";
        inherit hash;
      }
    ) packages.${version},
}:




# Listing found here:
#   - https://repo.download.nvidia.com/jetson/

stdenv.mkDerivation (finalAttrs: {
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

  # These dependencies are patchelf'd with the autoPatchelfHook.
  # Their runpaths are also being added unconditionally for `dlopen()` reasons.
  runtimeDependencies = [
    stdenv.cc.cc
    expat
    libxext
    libX11
    libGL
    libdrm
    libgbm
    libffi
    # Used at runtime by `libnvidia-*glcore.so`...
    dbus.lib
  ];

  buildInputs =
    # Dependencies being patchelf'd, to satisfy autoPatchelfHook
    finalAttrs.runtimeDependencies
  ;

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
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
    mv -vt $out/lib usr/lib/xorg

    mkdir -vp $out/share/egl/egl_external_platform.d/
    mv -t $out/share/egl/egl_external_platform.d/ usr/share/egl/egl_external_platform.d/nvidia_gbm.json

    mkdir -vp "$out/lib/udev/rules.d"
    mv -t $out/lib/udev/rules.d etc/udev/rules.d/99-tegra-devices.rules
    substituteInPlace $out/lib/udev/rules.d/99-tegra-devices.rules \
      --replace-fail "/bin/mknod" "${lib.getExe' coreutils "mknod"}"

    (
      set -x

      cd $out/lib

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

      mkdir -p gbm
      # Fixup libnvidia-allocator links we broke
      for lib in tegra-udrm_gbm.so tegra_gbm.so nvidia-drm_gbm.so; do
        mv -t gbm "$lib"
        ln -fs ../libnvidia-allocator.so "gbm/$lib"
      done
    )

    runHook postInstall

    # Work around autoPatchelfHook idiosyncrasy...
    # We are not handling the whole patching ourselves since we want to rely
    # on the autoPatchelfHook "missing dependencies" support.
    fixupNvidiaL4T() {
      (
        set -x
        cd $out/lib

        rpath="$(
          # Add "self" to the rpath
          printf "${placeholder "out"}/lib"
          # And all runtimeDependencies
          printf ":%s" ''${runtimeDependencies[@]/%//lib}
        )"

        # Apparently `runtimeDependencies` and `appendRunPaths` are only
        # effective for .so where the autoPatchelfHook changed the .so...
        # Let's make sure any `dlopen`, such as found in `libnvos`, works.
        for lib in $(find -type f -name '*.so*'); do
          patchelf --add-rpath "$rpath" "$lib"
        done
      )
    }

    # This needs to run *after* the autoPatchelfHook...
    # This is why we're adding this "late".
    printf "Adding fixupNvidiaL4T hook\n"
    postFixupHooks+=( fixupNvidiaL4T )
  '';

  # Don't strip "unnecessary" rpath values out
  dontPatchELF = true;
  # Also don't even try stripping vendor libraries.
  dontStrip = true;

  meta = {
    licenses = [
      lib.licenses.unfree
    ];
  };
})
