# Thème GTK/Qt clair — cohérent avec la barre Quickshell (thème.json).
{ config, lib, ... }:
with lib;
{
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita";
      package = null;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice"; # curseur blanc/clair
      package = null;
    };
    iconTheme = {
      name = "Papirus-Light";
      package = null;
    };
    font = {
      name = "Inter";
      size = 11;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = false;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = false;
    };
  };

  # Paquets requis par les thèmes ci-dessus.
  home.packages = with pkgs; [
    bibata-cursors
    papirus-icon-theme
  ];

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita";
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-light";
      cursor-theme = "Bibata-Modern-Ice";
      icon-theme = "Papirus-Light";
      font-name = "Inter 11";
    };
  };
}
