# Spotify + Spicetify (thème clair Catppuccin Latte).
# `spicePkgs` est fourni par le flake (extraSpecialArgs), `mundane` aussi.
{
  config,
  mundane,
  spicePkgs,
  ...
}:
{
  programs.spicetify = {
    enable = mundane.apps.spicetify;
    theme = spicePkgs.themes.catppuccin;
    colorScheme = "latte";

    enabledExtensions = with spicePkgs.extensions; [
      adblock
      fullAppDisplay
      hidePodcasts
    ];
  };
}
