# Environnement CLI commun (shell, git, outils modernes).
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    fzf
    eza
    bat
    zoxide
    starship
    playerctl # widget musique de la barre Quickshell
  ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "eza -la --icons";
      ls = "eza --icons";
      cat = "bat";
      update = "sudo nixos-rebuild switch --flake /etc/nixos#";
      rollback = "sudo nixos-rebuild switch --rollback";
      snappers = "sudo snapper list";
    };
    zoxide.enable = true;
    # Le flake courant dans l'historique du prompt.
    initContent = ''
      eval "$(starship init zsh)"
    '';
  };

  programs.git = {
    enable = true;
    userName = "Mundane";
    userEmail = "mundane@users.noreply.github.com";
    extraConfig.init.defaultBranch = "main";
  };

  programs.fzf.enable = true;
  programs.bat.enable = true;

  home.stateVersion = "25.05";
}
