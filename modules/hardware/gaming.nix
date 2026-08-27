# Périphériques & infrastructure gaming : manette Xbox (dongle/USB), Steam hardware.
{ config, lib, ... }:
with lib;
let
  cfg = config.mundane;
in
{
  config = mkIf cfg.apps.gaming {
    # Manette Xbox sans fil (dongle officiel) ; le fil USB passe par xpad (noyau).
    hardware.xone.enable = true;
    boot.extraModulePackages = [
      config.boot.kernelPackages.xpad-noone
    ];

    # Règles udev Steam Controller / VR.
    hardware.steam-hardware.enable = true;

    # Gamemode : optimisation CPU/GPU pendant les jeux.
    programs.gamemode = {
      enable = true;
      settings = {
        general.renice = 10;
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
        };
      };
    };
  };
}
