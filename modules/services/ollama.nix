{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.ollama
  ];
services.ollama = {
  enable = true;
};
}
