# Sécurité de base : sudo, polkit, image kernel protégée.
{ config, lib, pkgs, ... }:
with lib;
{
  security = {
    polkit.enable = true;
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
    protectKernelImage = true;
  };

  # Outils système utiles au quotidien.
  environment.systemPackages = with pkgs; [
    neovim
    git
    curl
    wget
    ripgrep
    fd
    btop
    usbutils
    pciutils
  ];
}
