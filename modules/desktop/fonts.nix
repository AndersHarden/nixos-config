{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    jetbrains-mono
  ];

  # Fonts
  fonts.fontDir.enable = true;
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
    font-awesome
  ];

}
