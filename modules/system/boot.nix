# Boot : systemd-boot (UEFI). Chaque `nixos-rebuild switch` crée une
# génération démarrable => rollback immédiat depuis le menu du bootloader,
# indépendamment des snapshots BTRFS.
{ config, lib, ... }:
with lib;
{
  boot.loader = {
    efi.canTouchEfiVariables = mkDefault true;
    systemd-boot = {
      enable = mkDefault true;
      configurationLimit = mkDefault 10; # 10 générations restaurables au boot
      editor = false; # pas d'édition de cmdline sans mot de passe
    };
  };

  # Nettoyage des vieilles générations pour éviter que /boot ne déborde.
  boot.loader.systemd-boot.memtest86.enable = mkDefault false;

  # Garde-fou : si l'utilisateur installe en BIOS/Legacy (rare), systemd-boot
  # ne s'applique pas — l'installateur refuse déjà ce cas en amont.
  boot.loader.grub.enable = mkDefault false;
}
