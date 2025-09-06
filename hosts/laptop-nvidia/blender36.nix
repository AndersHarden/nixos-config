{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "blender-3.6-lts";
  version = "3.6.18";  # sista LTS-versionen

  src = pkgs.fetchurl {
    url = "https://download.blender.org/release/Blender3.6/blender-3.6.18.tar.xz";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    # kör `nix-prefetch-url --unpack URL` för att få korrekt hash
  };

  nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config pkgs.git pkgs.python3 pkgs.boost ];
  buildInputs = [
    pkgs.gcc
    pkgs.mesa
    pkgs.libGL
    pkgs.libX11
    pkgs.libXi
    pkgs.libXxf86vm
    pkgs.libXrandr
    pkgs.libXcursor
    pkgs.libXinerama
    pkgs.libXrender
    pkgs.libXcomposite
    pkgs.libXfixes
    pkgs.freetype
    pkgs.fontconfig
    pkgs.openssl
    pkgs.ffmpeg
    pkgs.openal
    pkgs.python3
    pkgs.ninja
  ];

  # Kör byggsystemet för Blender
  # Notera: Blender 3.6 använder CMake, vi kan köra normal build
  cmakeFlags = [
    "-DWITH_CYCLES_CUDA_BINARIES=ON"
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp -r * $out/
  '';

  meta = with pkgs.lib; {
    description = "Blender 3.6 LTS built against current system Mesa/NVIDIA";
    license = licenses.gpl3;
    maintainers = [ maintainers.anders ]; # byt ut om du vill
  };
}
