# Gaming au niveau système : Steam, Wine/Bottles, Lutris, Heroic.
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.mundane;
in
{
  config = mkIf cfg.apps.gaming {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = false; # à activer volontairement
      dedicatedServer.openFirewall = false;
      gamescopeSession.enable = true; # session "Steam (Gamescope)" dans SDDM
      extraCompatPackages = with pkgs; [ proton-ge-bin ];
    };

    environment.systemPackages = with pkgs; [
      heroic # Epic/GOG/Amazon
      lutris
      bottles # runners Windows/Wine
      wineWowPackages.stable
      winetricks
      gamescope
      mangohud # overlay perf (F12)
      mangojuice # interface graphique de mangoconf
      protontricks
    ];

    # Améliorations habituelles des perfs de jeu sur nvidia… non pertinent en
    # AMD, mais l'option GPU reste utile (vram, mesas).
    environment.sessionVariables = {
      # Pipeline de shaders plus rapide via l'attribut GPU AMD.
      RADV_PERFTEST = "gpl";
      MANGOHUD = "1";
    };

    # Gamemode est configuré dans modules/hardware/gaming.nix (manettes etc.).
  };
}
