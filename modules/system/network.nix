# Réseau : NetworkManager partout (Ethernet + WiFi), mDNS, pare-feu raisonnable.
{ config, lib, ... }:
with lib;
{
  networking = {
    networkmanager = {
      enable = mkDefault true;
      wifi.powersave = mkDefault false; # stabilité avant économie d'énergie
    };
    useDHCP = mkDefault false;
    # NM gère tout ; interfaces gérées explicitement :
    interfaces = mkDefault { };
    firewall = {
      enable = mkDefault true;
      allowedTCPPorts = [ ]; # à ouvrir au cas par cas (Steam In-Home etc.)
      allowedUDPPorts = [ ];
    };
  };

  # Résolution DNS moderne (systemd-resolved) — robuste avec les VPN.
  services.resolved.enable = mkDefault true;

  # LocalSend (transfert de fichiers) utilise mDNS.
  services.avahi = {
    enable = mkDefault true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Accès distant de secours (désactivable d'un coup d'option).
  services.openssh = {
    enable = mkDefault false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  networking.hostName = mkDefault config.mundane.hostname;
}
