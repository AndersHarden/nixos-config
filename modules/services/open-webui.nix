{ config, pkgs, lib, ... }:
{
  services.open-webui = {
    enable = true;
    host = "127.0.0.1"; # eller "0.0.0.0" om du vill nå den från andra enheter
    port = 8080;
    environment = {
      ENABLE_UPLOADS = "true";
      UPLOAD_DIR = "/var/lib/open-webui/uploads";
      ENABLE_RAG = "false";   # 🚀 stänger av vektorindexering
    };
  };
}
