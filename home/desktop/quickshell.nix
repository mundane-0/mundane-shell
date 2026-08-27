# Quickshell — l'interface Mundane Shell (barre flottante + widgets bureau).
#
# Pourquoi Quickshell : QML déclaratif (animations 60fps natives), intégration
# Wayland/Hyprland/Tray de premier ordre, rechargement à chaud des fichiers de
# config JSON — la personnalisation « totale » tient dans deux fichiers.
{ config, lib, pkgs, ... }:
with lib;
{
  home.packages = with pkgs; [
    quickshell
  ];

  # Le shell QML + les deux fichiers de personnalisation (éditables en live).
  xdg.configFile."quickshell/shell.qml".source = ../shell/qml/shell.qml;
  xdg.configFile."quickshell/config.json".source = ../shell/config.json;
  xdg.configFile."quickshell/theme.json".source = ../shell/theme.json;

  # Positions des widgets bureau (glisser-déposer) — état utilisateur.
  # Créé vide ; le QML le remplit aux premiers drags.
  xdg.configFile."quickshell/positions.json".text = builtins.toJSON {
    clockX = 60;
    clockY = 90;
    weatherX = 60;
    weatherY = 280;
    drawX = 60;
    drawY = 470;
  };

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Mundane Shell UI (Quickshell)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/qs";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
