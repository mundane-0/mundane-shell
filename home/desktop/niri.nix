# Niri — côté utilisateur : config.kdl (keybinds identiques à Hyprland,
# animations à ressort « bounce », bordures claires, xwayland-satellite).
{ mundane, lib, ... }:
with lib;
let
  cfg = mundane;
in
{
  # Config écrite uniquement si Niri est actif — sinon on garde le KDL par défaut.
  xdg.configFile."niri/config.kdl" = mkIf cfg.enableNiri {
    enable = true;
    text = ''
      // Mundane Shell — configuration Niri (tout est modifiable).
      input {
          keyboard {
              layout "${cfg.keyboardLayout}"
          }
      }

      // Sorties — exemple double écran (niri msg outputs pour les noms) :
      // output "DP-1" {
      //     mode "1920x1080@200"
      // }

      layout {
          border {
              enable true
              width 2
              active-color "#6C8CFF"
              inactive-color "#1C1F2622"
          }
          focus-ring {
              enable false
          }
          struts {
              left 16
              right 16
              top 12
              bottom 12
          }
      }

      animations {
          // Rebond : damping-ratio < 1 = oscillation.
          window-open {
              spring damping-ratio=0.55 stiffness=420 epsilon=0.0001
          }
          window-close {
              spring damping-ratio=0.7 stiffness=300 epsilon=0.0001
          }
          window-movement {
              spring damping-ratio=0.62 stiffness=520 epsilon=0.0001
          }
          window-resize {
              spring damping-ratio=0.7 stiffness=500 epsilon=0.0001
          }
          horizontal-view-movement {
              spring damping-ratio=0.6 stiffness=480 epsilon=0.0001
          }
      }

      // Applications X11 (jeux, anciens clients) via satellite.
      spawn-at-startup "xwayland-satellite"
      environment {
          DISPLAY ":0"
      }

      window-rule {
          match app-id="clipse"
          open-floating true
      }

      screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

      binds {
          Mod+X { close-window; }
          Mod+Z { spawn "kitty"; }
          Mod+Return { spawn "kitty"; }
          Mod+R { spawn "fuzzel"; }
          Mod+V { spawn "kitty" "--class" "clipse" "-e" "clipse"; }

          Mod+1 { focus-workspace 1; }
          Mod+2 { focus-workspace 2; }
          Mod+3 { focus-workspace 3; }
          Mod+4 { focus-workspace 4; }
          Mod+5 { focus-workspace 5; }
          Mod+6 { focus-workspace 6; }
          Mod+7 { focus-workspace 7; }
          Mod+8 { focus-workspace 8; }
          Mod+9 { focus-workspace 9; }

          Mod+Shift+1 { move-column-to-workspace 1; }
          Mod+Shift+2 { move-column-to-workspace 2; }
          Mod+Shift+3 { move-column-to-workspace 3; }
          Mod+Shift+4 { move-column-to-workspace 4; }
          Mod+Shift+5 { move-column-to-workspace 5; }
          Mod+Shift+6 { move-column-to-workspace 6; }
          Mod+Shift+7 { move-column-to-workspace 7; }
          Mod+Shift+8 { move-column-to-workspace 8; }
          Mod+Shift+9 { move-column-to-workspace 9; }

          // Super + molette : naviguer dans les workspaces.
          Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
          Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }
      }
    '';
  };
}
