# Mundane Shell

NixOS « béton », ultra-personnalisable : **Hyprland + Niri switchables**, barre
**îlots flottants** Quickshell avec **widgets bureau drag & drop**, thème clair
par défaut, **blur** prononcé, animations **bounce** — le tout piloté par deux
fichiers JSON rechargés à chaud.

---

## ⚡ Démarrage rapide

### VM QEMU/KVM (test)

```bash
# Disque virtuel + ISO NixOS minimal + firmware UEFI
qemu-img create -f qcow2 mundane.qcow2 60G
qemu-system-x86_64 \
  -enable-kvm -machine q35 -cpu host -smp 6 -m 5G \
  -drive file=mundane.qcow2,if=virtio,format=qcow2 \
  -cdrom nixos-minimal-*.iso \
  -bios /usr/share/ovmf/OVMF.fd \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -device qemu-xhci -device usb-kbd -device usb-tablet
```

Dans l'ISO : `sudo -i`, puis :

```bash
git clone https://github.com/mundane-0/mundane-shell
cd mundane-shell && sudo ./install.sh
```

### PC physique (Ryzen 5600X / RX 6600)

Boot sur l'ISO NixOS en **UEFI**, puis :

```bash
sudo -i
git clone https://github.com/mundane-0/mundane-shell
cd mundane-shell && sudo ./install.sh
```

Après redémarrage : `sudo nixos-rebuild switch --flake /etc/nixos#pc`.

---

## 🏗 Architecture du flake

```
mundane-shell/
├── flake.nix                 # Points d'entrée : hosts `vm` et `pc`
├── install.sh                # Installateur interactif (voir ci-dessous)
├── hosts/
│   ├── vm/                   # VM QEMU/KVM
│   │   ├── default.nix       #   options mundane.* par défaut
│   │   ├── overrides.nix     #   ⬅ écrit par install.sh (hostname, user…)
│   │   └── hardware-configuration.nix  # ⬅ régénéré par install.sh
│   └── pc/                   # PC physique (même principe)
├── modules/                  # Modules NixOS (côté système)
│   ├── settings.nix          # API d'options `mundane.*` (toute la config)
│   ├── system/               # boot, fs/snapper, réseau, audio, users, nix
│   ├── hardware/             # amd.nix, qemu.nix, gaming.nix (manettes…)
│   ├── desktop/              # base graphique, hyprland.nix, niri.nix
│   └── apps/                 # apps système + gaming (Steam, Lutris…)
└── home/                     # Home-Manager (côté utilisateur)
    ├── common.nix            # zsh, git, outils CLI
    ├── desktop/              # gtk, kitty, fuzzel, clipse, swww,
    │                         # hyprland.nix, niri.nix, quickshell.nix
    ├── apps/                 # spicetify (Spotify customisé)
    └── shell/
        ├── qml/shell.qml     # ⬅ L'INTERFACE Quickshell complète
        ├── config.json       # ⬅ personnalisation runtime (modules, position…)
        └── theme.json        # ⬅ personnalisation runtime (couleurs, police)
```

**Principes** : chaque fichier = un sujet ; aucun réglage codé en dur (tout
passe par `mundane.*` ou les JSON runtime) ; Home-Manager est intégré au
module NixOS → **une seule génération atomique** : le rollback NixOS restaure
aussi la config home.

---

## 🛠 install.sh — ce qu'il fait

1. **Détecte** VM/physique (`systemd-detect-virt`), liste les disques, la RAM.
2. **Demande** (interactif, secret masqué + double saisie) : hostname, user,
   mot de passe, clavier, timezone, session par défaut, autologin.
3. **WiFi** : scan interactif (`nmcli` ou `iwctl`), passphrase jamais passée en
   argument de processus.
4. **Snapshot de sécurité AVANT formatage** : si le disque contient déjà des
   subvolumes `@`/`@home`, ils sont photographiés en lecture seule
   (`@preinstall-<date>`) — rollback possible même après réinstallation.
5. **Partitionne — le fix définitif du bug `vda`** :
   - effacement **binaire** des 64 premiers et derniers Mo (tue toute GPT/MBR
     résiduelle et les superblocs — cause n°1 des erreurs sgdisk sur vda) ;
   - **double `sgdisk --zap-all`** (le second s'exécute sur un disque propre) ;
   - partitions alignées secteur 2048 (ESP 1G, SWAP, ROOT, labels GPT) ;
   - **re-scan kernel complet** : `partprobe` + `partx -u` + `udevadm settle`
     + **attente active** des nodes `/dev/vda*` avant tout mkfs ;
   - **swap activé avec 5 tentatives** (le fameux bug « GPT/Swap » sur vda).
6. **Formate** : BTRFS (recommandé : `@`, `@home`, `@nix` + snapper) ou EXT4.
7. **Récupère le flake** (copie locale si présent, sinon `git clone`).
8. **Régénère `hardware-configuration.nix`** depuis la vraie machine (UUIDs
   par label — plus aucun `vda`/`sda` codé en dur) et écrit `overrides.nix`.
9. **`nixos-install --flake .#vm|pc`** puis pose le mot de passe utilisateur
   dans le chroot (jamais stocké en clair dans Nix).

### Rollback « béton » (3 niveaux)

| Niveau | Quand | Comment |
|---|---|---|
| Génération NixOS | un switch a cassé | menu **systemd-boot** au boot → génération précédente |
| Snapshot snapper | fichiers/@,@home | `sudo snapper list` → `sudo snapper rollback <n>` |
| Pré-install | réinstallation ratée | subvolume `@preinstall-<date>` conservé sur le disque |

---

## 🎨 Stack UI : pourquoi Quickshell (+ QML) ?

**Choix : Quickshell (Qt6/QML)**, embarqué comme simple service utilisateur.

- **QML déclaratif** : animations 60 fps, blur, transparence et coins ronds
  natifs — exactement le style « îlots » (iNiR/macOS) demandé, sans hacks.
- **Intégrations de premier ordre** : layer-shell Wayland (barre sur les 4
  bords), tray système natif, IPC **Hyprland** natif (workspaces live) et
  Niri via IPC — les deux compositeurs partagent la même interface.
- **Rechargement à chaud des JSON** (`FileView` + `JsonAdapter`) : la
  personnalisation totale se fait dans `config.json` / `theme.json`, **sans
  rebuild NixOS et sans redémarrer le shell**.
- **À la différence de Waybar/Eww** : pas de DSL ou de CSS à recoller, du
  vrai QML extensible ; **à la différence d'Ags/JS** : pas de daemon GJS
  instable, Quickshell est packagé et maintenu dans nixpkgs.

### Ce que contient `shell.qml`

- **Barre îlots** positionnable sur les 4 bords (`"barPosition"`), avec
  modules : workspaces (Hyprland natif / Niri IPC), horloge, météo (wttr.in),
  CPU/RAM, musique (playerctl), tray, bouton launcher.
- **Widgets bureau drag & drop** : horloge, météo, **mini-app de dessin**
  (5 couleurs + gomme) — positions **sauvegardées automatiquement** dans
  `positions.json`, layer `bottom` (sous les fenêtres).

### Personnaliser sans toucher au code

```jsonc
// ~/.config/quickshell/config.json
{ "barPosition": "bottom", "showWeather": true, "weatherCity": "Lyon",
  "widgetDraw": true, "barRadius": 30 }
```

```jsonc
// ~/.config/quickshell/theme.json
{ "bg": "#F4F6F9", "accent": "#6C8CFF", "fontFamily": "Inter" }
```

Sauvegardez → l'interface se met à jour instantanément.

---

## ⌨️ Keybinds (identiques sous Hyprland et Niri)

| Raccourci | Action |
|---|---|
| `Super+X` | fermer la fenêtre |
| `Super+Z` / `Super+Entrée` | terminal (kitty) |
| `Super+R` | launcher (fuzzel) |
| `Super+V` | historique presse-papier (clipse) |
| `Super+Molette` | workspaces |
| `Super+1..9` / `Super+Shift+1..9` | aller à / déplacer vers workspace |
| `Super+clic` / `Super+clic droit` | déplacer / redimensionner |

Tout est modifiable dans `home/desktop/hyprland.nix` et `home/desktop/niri.nix`.

## 📦 Apps incluses

Zen Browser · VSCodium · Zed · Steam (+ Gamescope, Proton-GE) · Heroic ·
Lutris · Bottles · Discord Canary · OBS · Spotify+Spicetify (Latte) ·
KeePassXC · LocalSend · manette Xbox (xone/xpad).

---

## 🔀 Stratégie Git

- `main` = **stable** : n'y arrivent que des commits évalués
  (`nix eval .#nixosConfigurations.pc.config.system.build.toplevel`).
- Petits commits atomiques (un module = un commit) plutôt que des PR
  monolithiques — c'est la cause des conflits « complexes ».
- Expérimentations sur des branches courtes `feat/…`, merge rapide ou abandon.
- Mise à jour machine : `cd /etc/nixos && git pull && sudo nixos-rebuild switch --flake .#vm`.

## 🧪 Personnalisation système (Nix)

Toutes les options se règlent dans `hosts/<hôte>/overrides.nix` :

```nix
{ ... }: {
  mundane.hostname = "mundane-pc";
  mundane.defaultSession = "niri";   # ou "hyprland"
  mundane.apps.gaming = false;       # couper tout le volet gaming
  mundane.enableNiri = false;        # retirer Niri de SDDM
}
```
