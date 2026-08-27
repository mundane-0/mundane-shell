# Outils bureau communs : terminal kitty, launcher fuzzel, presse-papier
# clipse (daemon), fond d'écran swww. Thème clair cohérent partout.
{ config, lib, pkgs, ... }:
with lib;
{
  # —— Terminal : kitty (Super+Z / Super+Entrée) ——
  programs.kitty = {
    enable = true;
    font = {
      name = "CaskaydiaCove Nerd Font";
      size = 11;
    };
    settings = {
      background_opacity = "0.92";
      confirm_os_window_close = 0;
      cursor_shape = "beam";
      scrollback_lines = 10000;
      enable_audio_bell = false;
      window_padding_width = 12;
      # Thème clair (aligné sur ~/.config/quickshell/theme.json)
      foreground = "#1C1F26";
      background = "#F5F7FA";
      color0 = "#1C1F26";
      color7 = "#5C6370";
      color8 = "#989CA6";
      color15 = "#1C1F26";
      color1 = "#CC4444";
      color2 = "#3C8056";
      color3 = "#B0811E";
      color4 = "#4C6FBF";
      color5 = "#9A5CB4";
      color6 = "#3F8CA6";
    };
  };

  # —— Launcher : fuzzel (Super+R) ——
  xdg.configFile."fuzzel/fuzzel.ini".text = ''
    # Launcher clair — tout est modifiable ici (couleurs, police, position…)
    font=Inter:size=12
    terminal=kitty -e
    width=36
    lines=14
    layer=overlay
    icon-theme=Papirus-Light
    prompt="➜  "

    [colors]
    background=f4f6f9f0
    text=1c1f26ff
    match=4c6fbfff
    selection=d6e0f8ff
    selection-text=1c1f26ff
    border=1c1f2633
  '';

  # —— Presse-papier : clipse (Super+V) ——
  systemd.user.services.clipse-daemon = {
    Unit = {
      Description = "Clipboard history daemon (clipse)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.clipse}/bin/clipse -daemon";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # —— Fond d'écran : swww (daemon + image), modifiable en remplaçant le fichier ——
  xdg.dataFile."backgrounds/mundane.png".source = ./wallpaper.png;

  systemd.user.services.swww-daemon = {
    Unit = {
      Description = "Wayland wallpaper daemon (swww)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.swww}/bin/swww-daemon";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.swww-image = {
    Unit = {
      Description = "Apply Mundane wallpaper";
      PartOf = [ "graphical-session.target" ];
      After = [ "swww-daemon.service" ];
      Requires = [ "swww-daemon.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.swww}/bin/swww img %h/.local/share/backgrounds/mundane.png --transition-type grow --transition-pos center";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.packages = with pkgs; [
    clipse
  ];
}
