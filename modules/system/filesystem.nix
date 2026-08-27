# Filesystem & snapshots.
#
# Stratégie « rollback béton » à deux niveaux :
#  1. Génations NixOS   -> sélectionnables directement dans systemd-boot.
#  2. Snapshots BTRFS   -> snapper (timeline + pré/post rebuild), rollback
#     via `snapper rollback` (ou depuis un live-USB). Inactif si EXT4.
{ config, lib, pkgs, ... }:
with lib;
let
  isBtrfs = (config.fileSystems."/".fsType or "") == "btrfs";
in
{
  # Support BTRFS même si la cible est EXT4 (migration facile, rollback possible).
  boot.supportedFilesystems = [ "btrfs" "ext4" "vfat" "swap" ];

  # Vérification d'intégrité mensuelle du filesystem BTRFS.
  services.btrfs.autoScrub = {
    enable = mkDefault isBtrfs;
    interval = "monthly";
  };

  services.snapper = mkIf isBtrfs {
    enable = mkDefault true;
    snapshotInterval = "hourly";
    cleanupInterval = "1d";
    configs = {
      root = {
        SUBVOLUME = "/";
        TIMELINE_CREATE = true;
        TIMELINE_LIMIT_HOURLY = 5;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 0;
        TIMELINE_LIMIT_MONTHLY = 0;
        TIMELINE_LIMIT_YEARLY = 0;
        NUMBER_LIMIT = 10;
      };
      home = {
        SUBVOLUME = "/home";
        TIMELINE_CREATE = true;
        TIMELINE_LIMIT_HOURLY = 5;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 0;
        TIMELINE_LIMIT_MONTHLY = 0;
        TIMELINE_LIMIT_YEARLY = 0;
        NUMBER_LIMIT = 10;
      };
    };
  };

  # Montage des volumes amovibles (clés USB, disques externes) via udiskie/nautilus.
  services.udisks2.enable = mkDefault true;

  environment.systemPackages = with pkgs; [
    btrfs-progs
    snapper
    dosfstools
    e2fsprogs
    util-linux
  ];
}
