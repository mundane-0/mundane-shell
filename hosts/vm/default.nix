# Host VM QEMU/KVM — 6 vCPU, 5 Go RAM, disque virtuel /dev/vda.
# L'installateur régénère hardware-configuration.nix à chaque install.
{ config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./overrides.nix
    (import ../../modules)
  ];

  mundane = {
    machine = "vm";
    hostname = "mundane-vm";
    defaultSession = "hyprland";
    autoLogin = true; # itération rapide sur la VM de test
  };

  # Le swap de la VM est géré par zram (modules/hardware/qemu.nix).

  # QEMU : BIOS OVMF/UEFI attendu (l'installateur le vérifie).
  system.stateVersion = "26.05";
}
