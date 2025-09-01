{ pkgs, ... }:
{
  # Enable AMD GPU support
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.opengl.driSupport = true;
  hardware.graphics.enable = true;
  hardware.opengl.driSupport32Bit = true;
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
    unstable.blender-hip
  ];
}