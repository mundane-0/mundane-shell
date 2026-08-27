# Base graphique commune à Hyprland et Niri : SDDM (Wayland), portails,
# polkit, polices, thème clair. Aucune logique liée à un compositeur ici.
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.mundane;
in
{
  config = {
    # —— Polices : Inter (UI) + Nerd Font (symboles de la barre) + emoji ——
    fonts = {
      packages = with pkgs; [
        inter
        nerd-fonts.caskaydia-cove
        nerd-fonts.symbols-only
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
      ];
      fontconfig = {
        enable = true;
        defaultFonts = {
          sansSerif = [ "Inter" "Noto Sans" ];
          monospace = [ "CaskaydiaCove Nerd Font" ];
          emoji = [ "Noto Color Emoji" ];
        };
      };
    };

    # —— Écran de connexion : SDDM Wayland, sessions Hyprland + Niri listées ——
    services.displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
        theme = mkDefault "breeze";
      };
      # La session par défaut : source unique = mundane.defaultSession.
      # (priorité normale pour battre le mkDefault du module nixpkgs niri ;
      #  surchargeable par mkForce dans hosts/*/overrides.nix)
      defaultSession = "${cfg.defaultSession}";

      # Auto-login (options unifiées, relogin retiré dans nixpkgs récent)
      autoLogin = mkIf cfg.autoLogin {
        enable = true;
        user = cfg.username;
      };
    };

    # —— Portails XDG (screensharing, ouverture de fichiers, OBS) ——
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk # sélecteur de fichiers
      ];
      # Sélection explicite selon la session : évite les conflits quand
      # plusieurs portails sont installés (Hyprland + niri cohabitant).
      config = {
        common.default = [ "gtk" ];
      } // optionalAttrs cfg.enableHyprland {
        "Hyprland".default = [
          "hyprland"
          "gtk"
        ];
      } // optionalAttrs cfg.enableNiri {
        "niri".default = [
          "gnome"
          "gtk"
        ];
      };
    };

    # —— Divers indispensables du bureau Wayland ——
    programs.dconf.enable = true;
    services.gvfs.enable = true; # monte USB/MTP dans nautilus
    services.dbus.enable = true;

    environment.systemPackages = with pkgs; [
      # Agent d'authentification graphique (Hyprland ET Niri)
      hyprpolkitagent
      # Fond d'écran (daemon + img)
      swww
      # Outils Wayland
      wl-clipboard
      grim
      slurp
    ];
  };
}
