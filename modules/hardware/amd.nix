{ pkgs, ... }:
{
  # Enable AMD GPU support
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  # Enable AMD ROCm support
  systemd.tmpfiles.rules = 
  let
    rocmEnv = pkgs.symlinkJoin {
      name = "rocm-combined";
      paths = with pkgs.rocmPackages; [
        rocblas
        hipblas
        clr
      ];
    };
  in [
    "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
  ];

  # AMD specific packages
  environment.systemPackages = with pkgs; [ 
    (unstable.blender.override {
      rocmSupport = true;
    })
  ];
}