# Applications du quotidien (navigateurs, IDE, comms, utilitaires).
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.mundane;
in
{
  config = mkIf cfg.apps.enable {
    # Flatpak pour Zen Browser (pas dans nixpkgs) + apps système
    environment.systemPackages =
      with pkgs;
      [
        # IDE / éditeurs
        vscodium
        zed-editor

        # Communication
        discord-canary

        # Sécurité & transfert
        keepassxc
        localsend

        # Multimédia
        obs-studio

        # Fichiers
        nautilus
        file-roller
        flatpak
      ]
      ++ optionals cfg.apps.spicetify [
        # Spotify est géré par Home-Manager (spicetify), on garde ça côté user.
      ];

    # Flatpak : remote flathub + installation Zen Browser au premier login
    flatpak = {
      enable = true;
      remoteAdd = {
        flathub = {
          url = "https://flathub.org/repo/flathub.flatpakrepo";
          fromSource = false;
          system = true;
        };
      };
      # L'app Zen sera installée via systemd user service (home/flatpak-setup.nix)
    };
  };
}
