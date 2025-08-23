{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.ollama
  ];
services.ollama = {
  enable = true;
};
services.open-webui.enable = true;
}
