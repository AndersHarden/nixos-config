{ config, pkgs, ... }:
{
  services = {
      syncthing = {
          enable = true;
          group = "users";
          user = "anders";
          dataDir = "/home/anders/Documents";    # Default folder for new synced folders
          configDir = "/home/anders/.config/syncthing";   # Folder for Syncthing's settings and keys
      };
  };}
