{ lib
, stdenv
, fetchurl
, dpkg
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "nvidia-l4t-firmware";
  version = "36.4.7-20250918154033";

  src = fetchurl {
    url = "https://repo.download.nvidia.com/jetson/t234/pool/main/n/${finalAttrs.pname}/${finalAttrs.pname}_${finalAttrs.version}_arm64.deb";
    hash = "sha256-ONxahbRRmmuh/yeSrh4Auqu/EuG3Q4ua79zkJNoVSss=";
  };
  unpackPhase = ''
    runHook preUnpack

    printf '\n:: Extracting package %q\n' "${finalAttrs.pname}"
    dpkg -x "$src" ./

    runHook postUnpack
  '';

  nativeBuildInputs = [
    dpkg
  ];

  installPhase = ''
    runHook preInstall

    # Drop misc. BSP-provided firmware.
    (
      cd lib/firmware
      rm -rfv brcm* rtl* nv-{BT,WIFI}-Version
    )

    mkdir -vp $out/lib
    mv -vt $out/lib lib/firmware

    runHook postInstall
  '';

  dontPatchELF = true;
  dontStrip = true;

  meta = {
    licenses = [
      lib.licenses.unfree
    ];
  };
})
