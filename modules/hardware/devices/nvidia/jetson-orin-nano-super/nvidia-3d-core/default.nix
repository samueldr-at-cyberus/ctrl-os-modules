{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, dpkg

, nvidia-core
, libxext
, libX11
}:

# Listing found here:
#   - https://repo.download.nvidia.com/jetson/

stdenv.mkDerivation (finalAttrs: {
  pname = "nvidia-l4t-3d-core";
  version = "36.4.7-20250918154033";

  src = fetchurl {
    url = "https://repo.download.nvidia.com/jetson/t234/pool/main/n/${finalAttrs.pname}/${finalAttrs.pname}_${finalAttrs.version}_arm64.deb";
    hash = "sha256-uOebamU6vOuzrCHIDdGejR5cTBIQIz0D3TQM0/GoTFs=";
  };

  unpackPhase = ''
    runHook postUnpack

    dpkg -x "$src" ./

    runHook postUnpack
  '';

  buildInputs = [
    # Dependencies being patchelf'd
    stdenv.cc.cc
    nvidia-core
    libxext
    libX11
  ];

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
    mv -vt $out/lib usr/lib/aarch64-linux-gnu/*/* usr/lib/xorg/modules/extensions/libglxserver_nvidia.so

    runHook postInstall
  '';

  meta = {
    licenses = [
      lib.licenses.unfree
    ];
  };
})
