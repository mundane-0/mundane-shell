# Placeholder — REMPLACÉ automatiquement par `nixos-generate-config`
# lors de l'exécution de install.sh sur la machine physique.
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
    "nvme"
    "ahci"
    "xhci_pci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
