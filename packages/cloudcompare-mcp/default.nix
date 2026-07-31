{ cloudcompare, fetchFromGitHub, python313, writeShellApplication }:
let
  src = fetchFromGitHub {
    owner = "yufeioptimal";
    repo = "cloudcompare-mcp";
    rev = "22b5232fd14e8ca02105aa47dcac40ad248a705c";
    hash = "sha256-xeAy0OEc18kOCEobmOImEL7hg+VDMxGgbIGufUrCSOs=";
  };
  pythonEnv = python313.withPackages (ps: with ps; [
    mcp
    numpy
    matplotlib
    laspy
    lazrs
    plyfile
  ]);
in
writeShellApplication {
  name = "cloudcompare-mcp";
  runtimeInputs = [ pythonEnv ];
  text = ''
    export CLOUDCOMPARE_MCP_SOURCE="${src}/src"
    export CLOUDCOMPARE_VERSION="${cloudcompare.version}"
    exec ${pythonEnv}/bin/python ${./server.py} "$@"
  '';
}
