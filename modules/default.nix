# Point d'entrée des modules Mundane Shell.
# Ordre volontairement plat et lisible : chaque fichier = un sujet.
# (Attrset : un module importé comme chemin DOIT retourner un attrset.)
{
  imports = [
    ./settings.nix

    ./system/boot.nix
    ./system/filesystem.nix
    ./system/network.nix
    ./system/audio.nix
    ./system/locale.nix
    ./system/users.nix
    ./system/nix.nix
    ./system/security.nix

    ./hardware/qemu.nix
    ./hardware/amd.nix
    ./hardware/gaming.nix

    ./desktop/default.nix
    ./desktop/hyprland.nix
    ./desktop/niri.nix

    ./apps/default.nix
    ./apps/gaming.nix
  ];
}
