{
  description = "Mundane Shell — NixOS béton, ultra-personnalisable (Hyprland + Niri, Quickshell)";

  inputs = {
    # Canal suivi : unstable (flake.lock figé => reproductible tant qu'on ne
    # met pas à jour le lock). Passer sur nixos-XX.YY est un simple changement
    # d'URL si plus de stabilité est voulue.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      spicetify-nix,
      ...
    }:
    let
      system = "x86_64-linux";

      mkHost =
        name: path:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            # Permet aux modules de référencer le flake (ex: versionner la
            # config quickshell depuis self) sans chemin relatif fragile.
            mundane-self = self;
            # Paquets spicetify-nix (thèmes/extensions), redonnés à Home-Manager.
            spicePkgs = spicetify-nix.legacyPackages.${system};
          };
          modules = [
            path
            home-manager.nixosModules.home-manager
            spicetify-nix.homeManagerModules.default
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        # Tests QEMU/KVM : nixos-rebuild switch --flake .#vm
        vm = mkHost "vm" ./hosts/vm;
        # Machine physique (Ryzen 5600X / RX 6600) : --flake .#pc
        pc = mkHost "pc" ./hosts/pc;
      };
    };
}
