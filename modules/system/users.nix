# Utilisateur principal + branchement Home-Manager.
#
# Le mot de passe n'est PAS dans Nix (mutableUsers=true) : l'installateur le
# pose via chpasswd après nixos-install, et les rebuilds n'y touchent jamais.
{ config, lib, ... }:
with lib;
let
  cfg = config.mundane;
in
{
  users.mutableUsers = true;

  users.users.${cfg.username} = {
    isNormalUser = true;
    description = "Mundane";
    extraGroups = [
      "wheel" # sudo
      "networkmanager"
      "video"
      "input" # manettes / outils wayland
      "audio"
    ];
    shell = "/run/current-system/sw/bin/zsh";
    packages = [ ];
  };

  programs.zsh.enable = true;

  # Home-Manager : intégré au module NixOS => une seule génération atomique,
  # le rollback NixOS restaure AUSSI la config home. C'est le cœur de la
  # stabilité « béton ».
  home-manager.users.${cfg.username} = {
    imports = [ (import ../../home) ];
  };

  # Contexte Mundane passé aux modules Home-Manager (args `mundane`,
  # `spicePkgs` — identifiants nus, pas config.mundane).
  home-manager.extraSpecialArgs = {
    mundane = cfg;
    inherit spicePkgs;
  };
}
