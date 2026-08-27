# Hyprland — côté utilisateur : animations bounce, blur, îlots, keybinds.
# Tout est éditable : c'est du Nix, chaque valeur est une préférence.
# `mundane` arrive via home-manager.extraSpecialArgs (voir modules/system/users.nix).
{ mundane, lib, ... }:
with lib;
let
  cfg = mundane;
in
{
  wayland.windowManager.hyprland = mkIf cfg.enableHyprland {
    enable = true;

    settings = {
      # Variables à modifier en priorité pour personnaliser.
      "$mod" = "SUPER";
      "$term" = "kitty";
      "$launcher" = "fuzzel";
      "$clip" = "kitty --class clipse -e clipse";

      # Résolution/gamma par écran : « ,preferred,auto,1 » s'adapte à tout.
      # Pour l'écran 200 Hz, décommenter/ajuster dans extraConfig plus bas.
      monitor = [ ",preferred,auto,1" ];

      input = {
        kb_layout = cfg.keyboardLayout;
        follow_mouse = 1;
        touchpad.natural_scroll = true;
      };

      general = {
        gaps_in = 8;
        gaps_out = 16;
        border_size = 2;
        "col.active_border" = "rgba(6c8cffcc) rgba(9a5cb4cc) 45deg";
        "col.inactive_border" = "rgba(1c1f2622)";
        layout = "dwindle";
        resize_on_border = true;
      };

      # Coins ronds + blur prononcé : la signature « Mundane ».
      decoration = {
        rounding = 24;
        active_opacity = 1.0;
        inactive_opacity = 0.96;
        blur = {
          enabled = true;
          size = 8;
          passes = 3;
          new_optimizations = true;
          ignore_opacity = true;
          xray = false;
          vibrancy = 0.2;
        };
        shadow = {
          enabled = true;
          range = 24;
          render_power = 3;
          color = "rgba(1C1F2640)";
        };
      };

      # Animations avec rebond (courbes d'overshoot).
      animations = {
        enabled = true;
        bezier = [
          "fluent, 0.1, 0.9, 0.2, 1.08"
          "fluentBounce, 0.18, 0.9, 0.24, 1.22"
          "fluentOut, 0.3, -0.3, 0.1, 1"
          "liner, 1, 1, 1, 1"
        ];
        animation = [
          "windowsIn, 1, 6, fluentBounce, popin 72%"
          "windowsOut, 1, 5, fluentOut, slide"
          "windowsMove, 1, 6, fluent, slide"
          "workspaces, 1, 7, fluentBounce, slidevert"
          "fadeLayersIn, 1, 4, fluent"
          "fadeLayersOut, 1, 3, fluent"
        ];
      };

      misc = {
        vrr = 1; # FreeSync (utile pour l'écran 200 Hz)
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
        mouse_move_enables_dpms = true;
      };

      # —— Keybinds demandés ——
      bind =
        [
          "$mod, X, killactive"
          "$mod, Z, exec, $term"
          "$mod, Return, exec, $term"
          "$mod, R, exec, $launcher"
          "$mod, V, exec, $clip"
        ]
        ++ (map (i: "$mod, ${toString i}, workspace, ${toString i}") (range 1 9))
        ++ (map (i: "$mod SHIFT, ${toString i}, movetoworkspace, ${toString i}") (range 1 9));

      # Super + molette : changer de workspace.
      bindel = [
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
      ];

      # Super + clic : déplacer ; Super + clic droit : redimensionner.
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      windowrule = [
        "float, class:^(clipse)$"
        "size 800 600, class:^(clipse)$"
        "float, class:^(pavucontrol)$"
      ];
    };

    extraConfig = ''
      # Double écran 1080p dont un 200 Hz — ajustez les noms de sorties
      # (voir `hyprctl monitors`) :
      # monitor = DP-1, 1920x1080@200, 0x0, 1
      # monitor = HDMI-A-1, 1920x1080@60, 1920x0, 1
    '';
  };
}
