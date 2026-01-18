# Plats: modules/desktop/media-creation.nix

# Signaturen tar INTE emot 'inputs'
{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ # 'with pkgs;' gör att vi kan skriva 'unstable' istället för 'pkgs.unstable'
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
    unstable.opencode

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