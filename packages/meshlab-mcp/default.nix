{ python313, writeShellApplication }:
let
  pythonEnv = python313.withPackages (ps: with ps; [ mcp pymeshlab ]);
in
writeShellApplication {
  name = "meshlab-mcp";
  runtimeInputs = [ pythonEnv ];
  text = ''
    exec ${pythonEnv}/bin/python ${./.}/server.py "$@"
  '';
}
