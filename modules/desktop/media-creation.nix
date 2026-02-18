# Plats: modules/desktop/media-creation.nix

{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # 3D
#    unstable.blender
    freecad
    openscad
    meshlab
    cloudcompare
    f3d

    # raster
    gimp-with-plugins
    krita

    # Vektor
    inkscape-with-extensions
    inkscape-extensions.inkstitch

    # GIS
    qgis

    # Ljud
    openai-whisper
    atomicparsley
    whisper-ctranslate2

    # AI
    lmstudio
    # opencode is handled in workstation host directly

    # Development
    unstable.nodejs_24

    # Projektledning
    # unstable.anytype

    # pdf
    papers

    # markdown
    glow
  ];
}