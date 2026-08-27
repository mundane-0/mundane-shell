# Audio : PipeWire (low-latency) pour le casque USB et la capture OBS.
{ config, lib, pkgs, ... }:
with lib;
{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # audio des jeux Steam 32 bits
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # PAS de services.pulseaudio/alsa en parallèle.
  hardware.pulseaudio.enable = mkForce false;

  environment.systemPackages = with pkgs; [
    pavucontrol
    pwvucontrol
    alsa-utils
    helvum # patchbay JACK/PipeWire (usage avancé)
  ];
}
