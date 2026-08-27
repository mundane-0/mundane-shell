# Home-Manager — Flatpak apps (Zen Browser).
{
  config,
  pkgs,
  ...
}:
{
  programs.flatpak = {
    enable = true;
  };

  flatpak = {
    remoteAdd = {
      flathub = {
        url = "https://flathub.org/repo/flathub.flatpakrepo";
        fromSource = false;
      };
    };
    packages = with pkgs.flatpak; [
      "app.zen_browser.zen" # Zen Browser
    ];
  };
}