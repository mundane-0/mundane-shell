# Localisation FR (heure, clavier, console) — tout est surchargé par mundane.*.
{ config, lib, ... }:
with lib;
let
  cfg = config.mundane;
in
{
  time.timeZone = cfg.timezone;

  i18n.defaultLocale = cfg.locale;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = cfg.locale;
    LC_IDENTIFICATION = cfg.locale;
    LC_MEASUREMENT = cfg.locale;
    LC_MONETARY = cfg.locale;
    LC_NAME = cfg.locale;
    LC_NUMERIC = cfg.locale;
    LC_PAPER = cfg.locale;
    LC_TELEPHONE = cfg.locale;
    LC_TIME = cfg.locale;
  };

  # Clavier physique + console TTY.
  services.xserver.xkb.layout = cfg.keyboardLayout;
  console.keyMap = mkDefault "fr";
}
