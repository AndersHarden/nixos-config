# Plats: modules/desktop/media-creation.nix

{ config, pkgs, ... }:

let
  cloudcompareMcp = pkgs.callPackage ../../packages/cloudcompare-mcp { };
  meshlabMcp = pkgs.callPackage ../../packages/meshlab-mcp { };
in
{
  environment.systemPackages = with pkgs; [
    # 3D
#    unstable.blender
    freecad
    openscad
    meshlab
    meshlabMcp
    cloudcompare
    cloudcompareMcp
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