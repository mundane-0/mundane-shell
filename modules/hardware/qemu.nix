# Invité QEMU/KVM — actif uniquement sur mundane.machine == "vm".
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.mundane;
in
{
  config = mkIf (cfg.machine == "vm") {
    services.qemuGuest.enable = true;
    services.spice-vdagentd.enable = true; # clipboard/partage si display SPICE

    # Virtio est déjà utilisé par la détection matériel (hardware-configuration
    # généré par l'installateur) ; on force juste le minimum stable.
    boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "virtio_blk" ];
    boot.extraModulePackages = [ ];

    # La VM n'a pas de GPU dédié : pas de pilote propriétaire, KMS standard.
    services.xserver.videoDrivers = mkForce [ ];

    # Zram pour compenser les 5 Go de RAM de la VM de dev.
    zramSwap = {
      enable = true;
      memoryPercent = 50;
    };
  };
}
