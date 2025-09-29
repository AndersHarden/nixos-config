{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    python313
    python313Packages.pip
    python313Packages.numpy
    python313Packages.librosa
    python313Packages.pydub
    python313Packages.openai-whisper
  ];

}
