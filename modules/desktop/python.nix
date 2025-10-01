{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    python313
  ] ++ (with python313Packages; [
    pip
    numpy
    librosa
    pydub
    openai-whisper
    torch
  ]);

}
