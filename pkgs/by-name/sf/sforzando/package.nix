{
  lib,
  stdenv,
  fetchurl,
  unzip,
  dpkg,
  makeWrapper,
  autoPatchelfHook,
  alsa-lib,
  libpulseaudio,
  libx11,
  gtkmm3,
  glibmm,
  gtk3,
  libsigcxx,
  glib,
  pango,
  cairo,
  fontconfig,
  zlib,
  libpng,
  curl,
  libxcb-util,
  libxcb,
  libxkbcommon,
  libredirect,
}:

let
  version = "1.982";
  srcs = {
    x86_64-linux = fetchurl {
      url = "https://sforzando.s3.us-east-1.amazonaws.com/LINUX_plogue-sforzando_${version}_x86_64.zip";
      hash = "sha256-7ms1T9N1/50M4wgZaD9E07cSof5P9Tx35E3wNtqCqQA=";
    };
    aarch64-linux = fetchurl {
      url = "https://sforzando.s3.us-east-1.amazonaws.com/LINUX_plogue-sforzando_${version}_aarch64.zip";
      hash = "sha256-vwBWjTcx81xQ1ILldkrRsBr3Z//zSqhRpGtoLJSyy0A=";
    };
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "sforzando";
  inherit version;

  arch = if stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64";

  src =
    srcs.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  nativeBuildInputs = [
    unzip
    dpkg
    makeWrapper
    autoPatchelfHook
  ];

  buildInputs = [
    alsa-lib
    libpulseaudio
    libx11
    gtkmm3
    glibmm
    gtk3
    libsigcxx
    glib
    pango
    cairo
    fontconfig
    zlib
    libpng
    curl
    libxcb-util
    libxcb
    libxkbcommon
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/Plogue
    mkdir -p $out/lib/vst3
    mkdir -p $out/lib/clap
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/256x256/apps
    mkdir -p $out/share/doc/sforzando

    # Extract all deb packages from the unzipped source
    for deb in ../LINUX_plogue-sforzando_${finalAttrs.version}_${finalAttrs.arch}/*.deb; do
      dpkg -x "$deb" .
    done

    # Copy files to $out
    cp -r opt/Plogue/* $out/opt/Plogue/
    cp -r usr/lib/vst3/* $out/lib/vst3/
    cp -r usr/lib/clap/* $out/lib/clap/
    cp -r usr/share/applications/* $out/share/applications/
    cp -r usr/share/icons/hicolor/* $out/share/icons/hicolor/
    cp -r usr/share/doc/* $out/share/doc/sforzando/

    # Fix paths in .config files
    substituteInPlace $out/opt/Plogue/Aria/.config \
      --replace-fail "/opt/Plogue" "$out/opt/Plogue"
    substituteInPlace $out/opt/Plogue/sforzando/.config \
      --replace-fail "/opt/Plogue" "$out/opt/Plogue"
    substituteInPlace $out/opt/Plogue/TableWarp2/.config \
      --replace-fail "/opt/Plogue" "$out/opt/Plogue"

    # Fix path in desktop file
    substituteInPlace $out/share/applications/plogue-sforzando.desktop \
      --replace-fail "/opt/Plogue/sforzando/sforzando" "$out/bin/sforzando"

    # Wrap the standalone executable to use libredirect to redirect /opt/Plogue
    mkdir -p $out/bin
    makeWrapper $out/opt/Plogue/sforzando/sforzando $out/bin/sforzando \
      --set LD_PRELOAD "${libredirect}/lib/libredirect.so" \
      --set NIX_REDIRECTS "/opt/Plogue=$out/opt/Plogue"

    runHook postInstall
  '';

  meta = {
    description = "Free, highly SFZ 2.0 compliant sample player";
    homepage = "https://www.plogue.com/products/sforzando.html";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ eymeric ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "sforzando";
  };
})
