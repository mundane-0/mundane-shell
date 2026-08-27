# Réglages Nix : flakes activés, optimisation du store, GC automatique.
{ config, lib, ... }:
with lib;
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    # Substituents par défaut, plus la cache officielle.
    substituters = [
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  # Le GC ne touche qu'aux générations de +7 jours : les rollbacks restent possibles.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  nixpkgs.config.allowUnfree = true;
}
