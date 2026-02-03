{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, dpkg
, expat
}:




# Listing found here:
#   - https://repo.download.nvidia.com/jetson/

stdenv.mkDerivation (finalAttrs: {
  pname = "nvidia-l4t-core";
  version = "36.4.7-20250918154033";

  src = fetchurl {
    url = "https://repo.download.nvidia.com/jetson/t234/pool/main/n/${finalAttrs.pname}/${finalAttrs.pname}_${finalAttrs.version}_arm64.deb";
    hash = "sha256-MtaXaH25dmuQwCFlXcSeYlWOfIQ6UoZ8hXM8NGryg+E=";
  };

  unpackPhase = ''
    runHook postUnpack

    dpkg -x "$src" ./

    runHook postUnpack
  '';

  buildInputs = [
    # Dependencies being patchelf'd
    stdenv.cc.cc
    expat


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

    runHook postInstall
  '';

  meta = {
    licenses = [
      lib.licenses.unfree
    ];
  };
})
