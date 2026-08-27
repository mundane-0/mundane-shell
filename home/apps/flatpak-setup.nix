# Home-Manager — Flatpak user setup (Zen Browser installé au premier login).
{ config, lib, pkgs, ... }:
with lib;
{
  # Installer Zen Browser via flatpak au premier login utilisateur
  systemd.user.services.zen-browser-flatpak-install = {
    Unit = {
      Description = "Install Zen Browser via Flatpak";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionPathExists = "!%h/.var/app/app.zen_browser.zen";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.flatpak}/bin/flatpak install --user -y flathub app.zen_browser.zen";
      Environment = "FLATPAK_USER_DIR=%h/.local/share/flatpak";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Mettre à jour flatpak au login (optionnel, silencieux)
  systemd.user.services.flatpak-update = {
    Unit = {
      Description = "Update Flatpak apps";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.flatpak}/bin/flatpak update --user -y";
      Environment = "FLATPAK_USER_DIR=%h/.local/share/flatpak";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}