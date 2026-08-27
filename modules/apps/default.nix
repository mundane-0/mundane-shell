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

    # Flatpak : Zen Browser (installé user-side via flatpak, voir home/apps)
    # Navigation par défaut configurée via Home-Manager (xdg.mimeDefaults).
  };
}
