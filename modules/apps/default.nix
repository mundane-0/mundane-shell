# Applications du quotidien (navigateurs, IDE, comms, utilitaires).
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.mundane;
in
{
  config = mkIf cfg.apps.enable {
    environment.systemPackages =
      with pkgs;
      [
        # Navigateur
        zen-browser

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
      ]
      ++ optionals cfg.apps.spicetify [
        # Spotify est géré par Home-Manager (spicetify), on garde ça côté user.
      ];

    # Zen par défaut pour tout le web (déclaré côté Home-Manager).
  };
}
