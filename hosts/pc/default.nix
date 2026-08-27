# Host PC physique — Ryzen 5 5600X, RX 6600, 16 Go RAM,
# double écran 1080p (dont un 200 Hz), clavier 60%, casque USB, manette Xbox.
{ config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./overrides.nix
  ] ++ (import ../../modules);

  mundane = {
    machine = "pc";
    hostname = "mundane-pc";
    defaultSession = "hyprland";
    autoLogin = false;
  };

  # 16 Go + swap partition posée par l'installateur (recouvrement/hibernation).
  zramSwap.enable = false;

  system.stateVersion = "26.05";
}
