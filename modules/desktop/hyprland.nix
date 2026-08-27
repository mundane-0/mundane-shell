# Hyprland — compositeur Wayland principal (animations, blur, flottant).
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.mundane;
in
{
  config = mkIf cfg.enableHyprland {
    programs.hyprland = {
      enable = true;
      withUWSM = false; # démarrage classique, plus simple à scripter
      xwayland.enable = true;
    };

    # Portail spécifique Hyprland (partage d'écran, screencast OBS).
    xdg.portal.extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
    ];

    environment.systemPackages = with pkgs; [
      hyprpaper # secours si swww indisponible
      hyprshot # captures d'écran
    ];
  };
}
