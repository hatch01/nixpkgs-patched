{
  lib,
  stdenv,
  fetchurl,
  unzip,
  dpkg,
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
  zenity,
  patchelf,
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

  __structuredAttrs = true;
  strictDeps = true;

  nativeBuildInputs = [
    unzip
    dpkg
    autoPatchelfHook
    patchelf
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

    # Compile the redirection library
    mkdir -p $out/lib
    cp ${./sforzando_redirect.cpp} sforzando_redirect.cpp
    substituteInPlace sforzando_redirect.cpp \
      --replace-fail "@out@" "$out" \
      --replace-fail "@zenity@" "${zenity}" \
      --replace-fail "@kdialog@" "/var/empty" \
      --replace-fail "@yad@" "/var/empty"

    cat <<EOF > version.map
GLIBC_2.2.5 {
    global:
        open;
        open64;
        fopen;
        fopen64;
        access;
        __xstat;
        __xstat64;
        stat;
        lstat;
        __lxstat;
        __lxstat64;
};

GLIBCXX_3.4 {
    global:
        _ZNSt13basic_filebufIcSt11char_traitsIcEE4openEPKcSt13_Ios_Openmode;
};

GLIBCXX_3.4.26 {
    global:
        _ZNSt10filesystem6statusERKNS_7__cxx114pathE;
        _ZNSt10filesystem18create_directoriesERKNS_7__cxx114pathE;
        _ZNSt10filesystem7__cxx1128recursive_directory_iteratorC1ERKNS0_4pathENS_17directory_optionsEPSt10error_code;
};
EOF

    $CXX -shared -fPIC -O2 -std=c++17 sforzando_redirect.cpp -o $out/lib/libsforzando_redirect.so -ldl -Wl,--version-script=version.map

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

    # Apply redirection library to all ELF binaries except itself
    find $out -type f | while read -r file; do
      if [ "$(basename "$file")" != "libsforzando_redirect.so" ] && patchelf --print-needed "$file" >/dev/null 2>&1; then
        echo "Applying redirection to ELF binary: $file"
        patchelf --add-rpath "$out/lib" --add-needed libsforzando_redirect.so "$file"
      fi
    done

    # Create standard bin directory with symlink
    mkdir -p $out/bin
    ln -s $out/opt/Plogue/sforzando/sforzando $out/bin/sforzando

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
