# GPU AMD RX 6600 + CPU Ryzen 5 5600X.
# Actif uniquement sur mundane.machine == "pc".
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.mundane;
in
{
  config = mkIf (cfg.machine == "pc") {
    # Mesa/RADV couvrent OpenGL + Vulkan ; le 32-bit sert à Steam/Proton.
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libva
        libva-utils
      ];
    };

    services.xserver.videoDrivers = mkDefault [ "amdgpu" ];

    # Accélération vidéo du navigateur / OBS.
    environment.variables = {
      VDPAU_DRIVER = "radeonsi";
      LIBVA_DRIVER_NAME = "radeonsi";
    };

    # Gouverneur CPU AMD (schedutil + amd_pstate).
    boot.kernelParams = [ "amd_pstate=active" ];
    powerManagement.cpuFreqGovernor = mkDefault "schedutil";

    hardware.enableRedistributableFirmware = true;
  };
}
