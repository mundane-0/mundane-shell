# Niri — compositeur Wayland scrollable (2e session, sélectionnable dans SDDM).
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.mundane;
in
{
  config = mkIf cfg.enableNiri {
    programs.niri.enable = true;

    # Niri est 100% Wayland : les apps X11 (certains jeux, Discord…) passent
    # par xwayland-satellite, lancé au démarrage dans la config home.
    environment.systemPackages = with pkgs; [
      xwayland-satellite
      alacritty # terminal de secours indépendant de la config kitty
    ];

    # Portail compatible niri pour le screencast (PipeWire).
    xdg.portal.extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
    ];
  };
}
