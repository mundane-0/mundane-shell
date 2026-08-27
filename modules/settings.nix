# Options Mundane Shell — l'API de personnalisation du système.
#
# Tout ce qui est configurable se règle ici (ou dans les hosts), rien n'est
# hardcodé dans les modules. La config « runtime » (barre, widgets, couleurs)
# vit quant à elle dans ~/.config/quickshell/{config,theme}.json côté Home-Manager.
{ config, lib, ... }:

{
  options.mundane = with lib; {
    username = mkOption {
      type = types.str;
      default = "mundane";
      description = "Utilisateur principal (créé par l'installateur, mot de passe posé au post-install).";
    };

    machine = mkOption {
      type = types.enum [ "vm" "pc" ];
      default = "vm";
      description = "Profile matériel : vm (QEMU/KVM) ou pc (Ryzen 5600X / RX 6600).";
    };

    hostname = mkOption {
      type = types.str;
      default = "mundane";
      description = "Nom de la machine (posé par l'installateur).";
    };

    keyboardLayout = mkOption {
      type = types.str;
      default = "fr";
      description = "Disposition clavier (clavier 60% -> fr par défaut).";
    };

    timezone = mkOption {
      type = types.str;
      default = "Europe/Paris";
    };

    locale = mkOption {
      type = types.str;
      default = "fr_FR.UTF-8";
    };

    defaultSession = mkOption {
      type = types.enum [ "hyprland" "niri" ];
      default = "hyprland";
      description = "Session proposée par défaut à l'écran de connexion (l'autre reste sélectionnable).";
    };

    enableHyprland = mkOption {
      type = types.bool;
      default = true;
      description = "Installer Hyprland et l'exposer dans SDDM.";
    };

    enableNiri = mkOption {
      type = types.bool;
      default = true;
      description = "Installer Niri et l'exposer dans SDDM.";
    };

    autoLogin = mkOption {
      type = types.bool;
      default = false;
      description = "Connexion automatique dans la session par défaut (pratique sur la VM de test).";
    };

    apps = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Active l'ensemble des applications (navigateur, IDE, comms, sécurité…).";
      };
      gaming = mkOption {
        type = types.bool;
        default = true;
        description = "Steam, Heroic, Lutris, Bottles, gamemode, manettes.";
      };
      spicetify = mkOption {
        type = types.bool;
        default = true;
        description = "Spotify + Spicetify (thème clair Latte).";
      };
    };
  };
}
