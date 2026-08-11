# Plats: modules/desktop/hyprland-home.nix
# Delad NixOS-modul som sätter upp Home Manager Hyprland Lua-konfig
# Tar emot host-specifik hyprlandHostConfig och kombinerar med bas-konfig.
{ hyprlandHostConfig }:
{ pkgs, config, lib, ... }:

let
  hyprlandBaseConfig = import ./hyprland-base-lua.nix;

  fullLuaConfig = hyprlandBaseConfig + hyprlandHostConfig;

  # Build-time Lua syntax validation using loadfile (reliable parsing)
  hyprlandLuaConfigFile = builtins.toFile "hyprland.lua" fullLuaConfig;
  validateLuaConfig = pkgs.runCommandLocal "check-hyprland-lua-syntax" {
    nativeBuildInputs = [ pkgs.lua ];
  } ''
    cat > check.lua << 'EOF'
    local ok, err = loadfile("${hyprlandLuaConfigFile}")
    if not ok then
      io.stderr:write("--- Lua syntax error ---\n")
      io.stderr:write(err .. "\n")
      io.stderr:write("------------------------\n")
      os.exit(1)
    end
    EOF
    ${pkgs.lua}/bin/lua check.lua 2>&1 || {
      echo "----------------------------------------"
      echo "ERROR: Hyprland Lua config syntax check failed!"
      echo "----------------------------------------"
      cat ${hyprlandLuaConfigFile}
      echo "----------------------------------------"
      exit 1
    }
    echo "Hyprland Lua config syntax OK"
    touch $out
  '';
in
{
  imports = [
    ./hyprland-base.nix
  ];

  # Force Lua config validation to run at build time
  system.extraDependencies = [ validateLuaConfig ];

  # Skriv hyprland.lua via Home Manager direkt
  home-manager.users.anders = { pkgs, lib, ... }: {
    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";
      settings = { };
      systemd = {
        enable = true;
        variables = [ "--all" ];
      };
      extraConfig = fullLuaConfig;
    };

    # Activation check: verifiera Lua-syntax vid home-manager switch
    home.activation.checkHyprlandConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
      CONF="$HOME/.config/hypr/hyprland.lua"
      if [ -f "$CONF" ]; then
        ${pkgs.lua}/bin/luac -p "$CONF" 2>/dev/null || {
          echo "ERROR: Hyprland Lua config validation failed at activation"
          echo "Check the generated file at $CONF"
          echo "----------------------------------------"
          cat "$CONF"
          echo "----------------------------------------"
          exit 1
        }
      fi
    '';
  };
}
