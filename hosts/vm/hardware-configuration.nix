# Placeholder — REMPLACÉ automatiquement par `nixos-generate-config`
# lors de l'exécution de install.sh (montages par LABEL, indépendants du
# nom de disque vda/sda/nvme0n1 => c'est aussi ça qui tue le bug VM).
{ config, lib, pkgs, modulesPath, ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/MUNDANE";
    fsType = "btrfs";
    options = [ "subvol=@" "noatime" "compress=zstd:3" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/MUNDANE";
    fsType = "btrfs";
    options = [ "subvol=@home" "noatime" "compress=zstd:3" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/MUNDANE";
    fsType = "btrfs";
    options = [ "subvol=@nix" "noatime" "compress=zstd:3" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  swapDevices = [ { device = "/dev/disk/by-label/SWAP"; } ];

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
