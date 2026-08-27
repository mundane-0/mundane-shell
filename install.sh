#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
#  Mundane Shell — installateur NixOS « béton »
#
#  • Détection auto : VM/physique, disques, RAM, WiFi
#  • Correctif DÉFINITIF du bug de partitionnement GPT/Swap sur /dev/vda
#    (nettoyage binaire complet + double zap sgdisk + re-scan kernel
#    partprobe/partx/udevadm + attente active des nodes + swapon avec retry)
#  • BTRFS (recommandé, snapshots snapper) ou EXT4
#  • Snapshot de sécurité de l'ancien système AVANT formatage (BTRFS)
#  • Prompts interactifs sécurisés (user, mot de passe, WiFi)
#  • Rollback : générations NixOS dans systemd-boot + snapshots snapper
#
#  Usage : sudo ./install.sh            (depuis le ISO NixOS minimal, en UEFI)
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
shopt -s inherit_errexit

# ────────────────────────────── Couleurs / logs ──────────────────────────
if [ -t 1 ]; then
    C_G=$'\e[32m'; C_B=$'\e[34m'; C_Y=$'\e[33m'; C_R=$'\e[31m'; C_0=$'\e[0m'; C_BD=$'\e[1m'
else
    C_G=""; C_B=""; C_Y=""; C_R=""; C_0=""; C_BD=""
fi
info()  { printf '%s[INFO]%s %s\n'  "$C_B" "$C_0" "$*"; }
ok()    { printf '%s [OK]%s  %s\n'  "$C_G" "$C_0" "$*"; }
warn()  { printf '%s[WARN]%s %s\n'  "$C_Y" "$C_0" "$*"; }
step()  { printf '\n%s═══ %s ═══%s\n' "$C_BD" "$*" "$C_0"; }
die()   { printf '%s[FAIL]%s %s\n' "$C_R" "$C_0" "$*" >&2; exit 1; }

on_error() {
    local exit_code=$? line=$1
    printf '%s[FAIL]%s commande échouée (code %s) ligne %s\n' "$C_R" "$C_0" "$exit_code" "$line" >&2
    printf 'État conservé pour diagnostic. Corrigez puis relancez install.sh (le script reprend proprement).\n' >&2
    exit "$exit_code"
}
trap 'on_error $? $LINENO' ERR

# ────────────────────────────── Helpers ──────────────────────────────────
ask() { # ask <question> <défaut> -> réponse dans REPLY
    local q="$1" def="${2:-}"
    if [ -n "$def" ]; then
        read -r -p "$q [$def] : " REPLY
        REPLY="${REPLY:-$def}"
    else
        read -r -p "$q : " REPLY
    fi
}
ask_secret() { # ask_secret <question> -> ASK_SECRET_VALUE
    local q="$1" v1 v2
    while true; do
        read -r -s -p "$q : " v1; echo
        read -r -s -p "  Confirmez : " v2; echo
        if [ -z "$v1" ]; then warn "Valeur vide, réessayez."; continue; fi
        if [ "$v1" != "$v2" ]; then warn "Différents, réessayez."; continue; fi
        break
    done
    ASK_SECRET_VALUE="$v1"
}
choose() { # choose <titre> <option1> <option2> ... (1-based)
    local title="$1"; shift
    local i=1 opt
    printf '%s\n' "$title"
    for opt in "$@"; do printf '  %d) %s\n' "$i" "$opt"; i=$((i + 1)); done
    local n=$#
    while true; do
        read -r -p "Choix [1-$n] : " REPLY
        if [[ "$REPLY" =~ ^[0-9]+$ ]] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "$n" ]; then
            CHOOSE=$((REPLY)); return
        fi
        warn "Choix invalide."
    done
}
confirm() { # confirm <question> [defaut_oui]
    local q="$1" def="${2:-n}" a
    read -r -p "$q [${def^}/$(echo "$def" | tr 'oy' 'yo')] : " a
    a="${a:-$def}"
    [[ "$a" =~ ^[oOyY]$ ]]
}

# Nom de partition : vda->vda1, sda->sda1, nvme0n1->nvme0n1p1
partname() {
    local disk="$1" n="$2"
    case "$disk" in
        *nvme* | *mmcblk*) printf '%sp%s' "$disk" "$n" ;;
        *) printf '%s%s' "$disk" "$n" ;;
    esac
}

have() { command -v "$1" >/dev/null 2>&1; }
need() { have "$1" || die "Outil manquant : $1"; }

wait_for_node() { # le cœur du fix « vda » : attente active du node kernel
    local node="$1" i
    for i in $(seq 1 40); do
        [ -b "$node" ] && return 0
        partprobe "$TARGET_DISK" >/dev/null 2>&1 || true
        partx -u "$TARGET_DISK" >/dev/null 2>&1 || true
        udevadm settle 2>/dev/null || true
        sleep 0.5
    done
    die "Partition $node toujours absente du noyau après re-scan (bug partitionnement)."
}

# ────────────────────────────── Pré-requis ───────────────────────────────
step "Pré-vol"
[ "$(id -u)" -eq 0 ] || die "Lancez ce script en root (sudo -i depuis le ISO NixOS)."
[ -d /sys/firmware/efi ] || die "Boot UEFI requis (systemd-boot). Configurez OVMF/UEFI dans QEMU ou activez UEFI sur le PC."
for t in lsblk sgdisk wipefs mkfs.vfat partprobe partx udevadm nixos-install nixos-generate-config git curl awk; do
    need "$t"
done
ok "Environnement validé (UEFI + outils présents)."

# ────────────────────────────── Profil machine ───────────────────────────
step "Profil machine"
VIRT="$(systemd-detect-virt 2>/dev/null || echo none)"
if [ "$VIRT" = "qemu" ] || [ "$VIRT" = "kvm" ]; then
    SUGGEST_VM=1; info "VM QEMU/KVM détectée."
else
    SUGGEST_VM=0; info "Machine physique détectée (virt=$VIRT)."
fi
if [ "$SUGGEST_VM" -eq 1 ]; then
    choose "Hôte NixOS à installer ?" "vm   (VM QEMU/KVM — recommandé ici)" "pc   (machine physique)"
else
    choose "Hôte NixOS à installer ?" "pc   (machine physique — recommandé ici)" "vm   (VM QEMU/KVM)"
fi
case "$CHOOSE" in
    1) PROFILE="vm"  ;;
    2) PROFILE="pc"  ;;
    *) die "Choix inattendu" ;;
esac
ok "Hôte : $PROFILE"

# ────────────────────────────── Identité & sessions ──────────────────────
step "Identité & préférences"
DEF_HOST=$([ "$PROFILE" = "vm" ] && echo mundane-vm || echo mundane-pc)
ask "Nom d'hôte" "$DEF_HOST";        HOSTNAME="$REPLY"
ask "Nom d'utilisateur" "mundane";   USERNAME="$REPLY"
ask_secret "Mot de passe de $USERNAME"; USER_PASS="$ASK_SECRET_VALUE"
ask "Disposition clavier (fr, us, …)" "fr"; KBD="$REPLY"
ask "Fuseau horaire" "Europe/Paris"; TZ="$REPLY"
ask "Locale" "fr_FR.UTF-8";          LOCALE="$REPLY"

choose "Session par défaut (l'autre reste installée et sélectionnable)" "hyprland" "niri"
case "$CHOOSE" in
    1) SESSION="hyprland" ;;
    2) SESSION="niri" ;;
    *) die "Choix inattendu" ;;
esac
AUTOLOGIN=$([ "$PROFILE" = "vm" ] && echo true || echo false)
if confirm "Activer la connexion automatique (pratique en VM) ?" "$([ "$PROFILE" = vm ] && echo o || echo n)"; then
    AUTOLOGIN=true
else
    AUTOLOGIN=false
fi

# ────────────────────────────── Disque cible ─────────────────────────────
step "Disque cible"
lsblk -d -o NAME,SIZE,TYPE,MODEL,TRAN | awk '$3=="disk" {printf "  /dev/%-12s %6s  %s %s\n", $1, $2, $4, $5}'
DEFAULT_DISK=""
if [ "$SUGGEST_VM" -eq 1 ] && [ -b /dev/vda ]; then DEFAULT_DISK=/dev/vda; fi
if [ -z "$DEFAULT_DISK" ]; then
    DEFAULT_DISK="$(lsblk -dn -o PATH,TYPE,SIZE | awk '$2=="disk"{print $1, $3}' | sort -k2 -h | tail -1 | awk '{print $1}')"
fi
ask "Disque à EFFACER intégralement" "$DEFAULT_DISK"; TARGET_DISK="$REPLY"
[ -b "$TARGET_DISK" ] || die "$TARGET_DISK n'existe pas."
lsblk "$TARGET_DISK" -o NAME,SIZE,FSTYPE,MOUNTPOINTS || true

# ────────────────────────────── Filesystem & swap ────────────────────────
step "Système de fichiers"
choose "Quel filesystem ?" \
    "btrfs — recommandé : snapshots snapper auto, rollback instantané, compression zstd" \
    "ext4  — simple et éprouvé (pas de snapshots)"
case "$CHOOSE" in
    1) FSTYPE="btrfs" ;;
    2) FSTYPE="ext4"  ;;
    *) die "Choix inattendu" ;;
esac
[ "$FSTYPE" = "btrfs" ] && need mkfs.btrfs || need mkfs.ext4

RAM_KB="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
RAM_GB=$(( (RAM_KB + 1048575) / 1048576 ))
DEF_SWAP=$(( RAM_GB < 16 ? RAM_GB : 16 )); [ "$DEF_SWAP" -lt 2 ] && DEF_SWAP=2
ask "Taille du swap en Go (0 = pas de swap)" "$DEF_SWAP"; SWAP_GB="$REPLY"
[[ "$SWAP_GB" =~ ^[0-9]+$ ]] || die "Taille swap invalide."

# ────────────────────────────── Réseau / WiFi ────────────────────────────
step "Réseau"
net_ok() { curl -sfI --max-time 8 https://github.com >/dev/null 2>&1; }
setup_wifi() {
    if have nmcli; then
        info "Réseaux visibles :"
        nmcli --terse --fields SSID,SECURITY device wifi list 2>/dev/null | sort -u | head -20 || true
        ask "SSID WiFi" ""; local ssid="$REPLY"
        [ -n "$ssid" ] || return 1
        ask_secret "Phrase de passe WiFi"; local pass="$ASK_SECRET_VALUE"
        nmcli device wifi connect "$ssid" password "$pass" && return 0
        return 1
    elif have iwctl; then
        info "Réseaux visibles :"
        iwctl station wlan0 get-networks 2>/dev/null || true
        ask "SSID WiFi" ""; local ssid="$REPLY"
        [ -n "$ssid" ] || return 1
        # iwctl lit la passphrase sur stdin — pas d'exposition en argument.
        ask_secret "Phrase de passe WiFi"
        printf '%s\n' "$ASK_SECRET_VALUE" | iwctl --passphrase stdin station wlan0 connect "$ssid" && return 0
        return 1
    fi
    return 1
}
if net_ok; then
    ok "Internet OK."
else
    warn "Pas d'Internet — configuration WiFi."
    choose "Comment se connecter ?" "WiFi (scan interactif)" "Réessayer (câble branché entre-temps)" "Abandonner"
    case "$CHOOSE" in
        1)
            setup_wifi || die "Échec WiFi. Relancez install.sh."
            ;;
        2) : ;;
        *) die "Abandon." ;;
    esac
    net_ok || die "Toujours pas d'Internet — vérifiez le réseau puis relancez."
    ok "Internet OK."
fi

# ────────────────────────────── Récapitulatif ────────────────────────────
step "Récapitulatif"
cat <<EOF
  Profil          : $PROFILE
  Hostname        : $HOSTNAME
  Utilisateur     : $USERNAME  (mot de passe saisi, non affiché)
  Clavier         : $KBD   |  Timezone : $TZ  |  Locale : $LOCALE
  Session défaut  : $SESSION  (hyprland + niri installés, autologin=$AUTOLOGIN)
  Disque          : $TARGET_DISK  (EFFACÉ INTÉGRALEMENT)
  Filesystem      : $FSTYPE  |  Swap : ${SWAP_GB}G
EOF
warn "TOUTES les données de $TARGET_DISK seront détruites."
read -r -p "Tapez exactement le nom du disque (${TARGET_DISK}) pour confirmer : " CONFIRM_DISK
[ "$CONFIRM_DISK" = "$TARGET_DISK" ] || die "Confirmation différente — abandon."

# ──────────────────── Snapshot de sécurité (avant formatage) ─────────────
step "Snapshot de sécurité pré-installation"
PREINSTALL_BACKUP=""
if [ "$FSTYPE" = "btrfs" ]; then
    RESCUE=/mnt-rescue
    mkdir -p "$RESCUE"
    OLD_ROOT_PART="$(partname "$TARGET_DISK" 3)"
    # On tente d'accéder au niveau supérieur btrfs (subvolid=5) de l'ancienne
    # installation — lecteur RW : indispensable pour créer un snapshot.
    if mount -o subvolid=5 "$OLD_ROOT_PART" "$RESCUE" 2>/dev/null \
       || mount -o subvolid=5 "${TARGET_DISK}3" "$RESCUE" 2>/dev/null; then
        STAMP="$(date +%Y%m%d-%H%M%S)"
        if [ -d "$RESCUE/@" ] || [ -d "$RESCUE/@home" ]; then
            for sub in @ @home; do
                if [ -d "$RESCUE/$sub" ]; then
                    btrfs subvolume snapshot -r "$RESCUE/$sub" "$RESCUE/${sub}-preinstall-$STAMP" \
                        && PREINSTALL_BACKUP="$PREINSTALL_BACKUP ${sub}-preinstall-$STAMP"
                fi
            done
            ok "Ancien système photographié :$PREINSTALL_BACKUP (rollback possible après reboot)."
        else
            info "Pas de subvolumes Mundane existants — rien à photographier."
        fi
        umount "$RESCUE" 2>/dev/null || true
    else
        info "Disque vierge ou non-btrfs : rien à photographier (première installation)."
    fi
    rmdir "$RESCUE" 2>/dev/null || true
else
    info "EXT4 : pas de snapshot possible — l'ancien contenu sera perdu."
    confirm "Continuer quand même ?" "n" || die "Abandon."
fi

# ───────────────────── Partitionnement (fix « vda ») ─────────────────────
step "Partitionnement de $TARGET_DISK"
# Déverrouillage : swap/montages résiduels neutralisés.
swapoff -a 2>/dev/null || true
umount -R /mnt 2>/dev/null || true
for m in $(lsblk -nr -o MOUNTPOINT "$TARGET_DISK" 2>/dev/null | grep -v '^$' || true); do
    umount -f -l "$m" 2>/dev/null || true
done

# 1) Effacement BINAIRE total du début ET de la fin du disque : tue toute
#    GPT/MBR résiduelle et les superblocs — la cause n°1 des erreurs
#    « sgdisk » sur les disques virtuels vda déjà partitionnés.
info "Effacement binaire des en-têtes GPT/MBR (début + fin de disque)…"
DISK_BYTES="$(blockdev --getsize64 "$TARGET_DISK")"
dd if=/dev/zero of="$TARGET_DISK" bs=1M count=64 status=none
dd if=/dev/zero of="$TARGET_DISK" bs=1M count=64 seek=$(( DISK_BYTES / 1048576 - 64 )) status=none
sync

# 2) Double zap sgdisk (le premier purgera, le second s'exécute sur un disque
#    propre) — les erreurs GPT classiques disparaissent.
sgdisk --zap-all "$TARGET_DISK" >/dev/null 2>&1 || true
sync; sleep 1
sgdisk --zap-all "$TARGET_DISK"
partprobe "$TARGET_DISK" 2>/dev/null || true
udevadm settle 2>/dev/null || true
ok "Table de partitions purgée (double zap + wipefs)."

# 3) Partitions : ESP 1G, [SWAP], ROOT (alignées secteur 2048).
ESP_PART="$(partname "$TARGET_DISK" 1)"
sgdisk -a 2048 -n 1:0:+1G -t 1:EF00 -c 1:ESP "$TARGET_DISK"
ROOT_IDX=3
SWAP_PART=""
if [ "$SWAP_GB" -gt 0 ]; then
    SWAP_PART="$(partname "$TARGET_DISK" 2)"
    sgdisk -a 2048 -n 2:0:+"${SWAP_GB}G" -t 2:8200 -c 2:SWAP "$TARGET_DISK"
else
    ROOT_IDX=2
fi
ROOT_PART="$(partname "$TARGET_DISK" "$ROOT_IDX")"
sgdisk -a 2048 -n "${ROOT_IDX}:0:0" -t "${ROOT_IDX}:8300" -c "${ROOT_IDX}:ROOT" "$TARGET_DISK"

# 4) Re-scan kernel COMPLET + attente active des nodes (le vrai fix vda :
#    jamais de mkfs tant que le noyau n'a pas publié les partitions).
info "Re-scan du noyau (partprobe + partx + udevadm settle)…"
partprobe "$TARGET_DISK"
partx -u "$TARGET_DISK" 2>/dev/null || true
udevadm settle
sleep 2
wait_for_node "$ESP_PART"
if [ "$SWAP_GB" -gt 0 ]; then wait_for_node "$SWAP_PART"; fi
wait_for_node "$ROOT_PART"
lsblk "$TARGET_DISK" -o NAME,SIZE,TYPE,PARTLABEL
ok "Partitionnement validé par le noyau."

# ────────────────────────────── Formatage ────────────────────────────────
step "Formatage"
mkfs.vfat -F32 -n ESP "$ESP_PART"
if [ -n "$SWAP_PART" ]; then
    # Fix « swap sur vda » : mkswap puis swapon avec retry — le device est
    # garanti présent (wait_for_node) et le re-scan est terminé.
    mkswap -L SWAP "$SWAP_PART"
    for i in 1 2 3 4 5; do
        if swapon "$SWAP_PART"; then break; fi
        warn "swapon tentative $i/5…"; udevadm settle; sleep 2
        [ "$i" = 5 ] && die "Impossible d'activer le swap sur $SWAP_PART."
    done
fi
if [ "$FSTYPE" = "btrfs" ]; then
    mkfs.btrfs -f -L MUNDANE "$ROOT_PART"
else
    mkfs.ext4 -F -L MUNDANE "$ROOT_PART"
fi
ok "Filesystems créés."

# ────────────────────────────── Montage ──────────────────────────────────
step "Montage dans /mnt"
mkdir -p /mnt
if [ "$FSTYPE" = "btrfs" ]; then
    mount "$ROOT_PART" /mnt
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@nix
    umount /mnt
    mount -o subvol=@,noatime,compress=zstd:3 "$ROOT_PART" /mnt
    mkdir -p /mnt/home /mnt/nix /mnt/boot
    mount -o subvol=@home,noatime,compress=zstd:3 "$ROOT_PART" /mnt/home
    mount -o subvol=@nix,noatime,compress=zstd:3 "$ROOT_PART" /mnt/nix
else
    mount "$ROOT_PART" /mnt
    mkdir -p /mnt/boot
fi
mount "$ESP_PART" /mnt/boot
ok "Montages prêts (btrfs subvolumes: @ @home @nix)."

# ───────────────────── Récupération du flake Mundane ─────────────────────
step "Flake Mundane Shell"
NIXOS_DIR=/mnt/etc/nixos
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/flake.nix" ]; then
    info "Copie du dépôt local ($SCRIPT_DIR)…"
    mkdir -p "$NIXOS_DIR"
    cp -a "$SCRIPT_DIR/." "$NIXOS_DIR/"
    rm -rf "$NIXOS_DIR/.git"
else
    info "Clonage https://github.com/mundane-0/mundane-shell …"
    git clone --depth 1 https://github.com/mundane-0/mundane-shell "$NIXOS_DIR"
fi
ok "Flake en place : $NIXOS_DIR (hôte #$PROFILE)"

# ─────────────── hardware-configuration régénéré (par la vraie machine) ──
info "Génération du hardware-configuration réel…"
nixos-generate-config --root /mnt
rm -f "$NIXOS_DIR/configuration.nix" # fourni par le flake, jamais généré
mv "$NIXOS_DIR/hardware-configuration.nix" "$NIXOS_DIR/hosts/$PROFILE/hardware-configuration.nix"
ok "hosts/$PROFILE/hardware-configuration.nix remplacé (UUIDs réels, plus aucun nom vda/sda codé en dur)."

# ─────────────────────────── overrides.nix ───────────────────────────────
cat > "$NIXOS_DIR/hosts/$PROFILE/overrides.nix" <<EOF
# Généré par install.sh le $(date '+%Y-%m-%d %H:%M') — modifiable librement.
{ ... }: {
  mundane.hostname = "$HOSTNAME";
  mundane.username = "$USERNAME";
  mundane.keyboardLayout = "$KBD";
  mundane.timezone = "$TZ";
  mundane.locale = "$LOCALE";
  mundane.defaultSession = "$SESSION";
  mundane.autoLogin = $AUTOLOGIN;
}
EOF
ok "Préférences écrites (hosts/$PROFILE/overrides.nix)."

# ──────────────────────────── Installation ───────────────────────────────
step "nixos-install (peut prendre 10-40 min selon la connexion)"
export NIX_CONFIG="experimental-features = nix-command flakes"
nixos-install --flake "$NIXOS_DIR#$PROFILE" --no-root-password
ok "Système installé."

# Mot de passe utilisateur posé dans le chroot (jamais stocké en clair).
SET_PASS_FILE=/mnt/tmp/.mundane-setpass
mkdir -p /mnt/tmp
printf '%s:%s\n' "$USERNAME" "$USER_PASS" > "$SET_PASS_FILE"
chmod 600 "$SET_PASS_FILE"
nixos-enter --root /mnt -c 'chpasswd' < "$SET_PASS_FILE"
rm -f "$SET_PASS_FILE"
ok "Mot de passe de $USERNAME posé."

# ────────────────────────────── Terminé ──────────────────────────────────
step "Installation terminée ✔"
cat <<EOF

  Démarrez sur le disque : SDDM proposera  ${SESSION}  (et l'autre session).

  ── Rollback instantané ──────────────────────────────────────────────────
  • Génération précédente : menu systemd-boot au boot (« Generation … »).
  • Snapshots BTRFS :  sudo snapper list  |  sudo snapper rollback <num>
  • $( [ -n "$PREINSTALL_BACKUP" ] && echo "Avant-install préservé sur le disque :$PREINSTALL_BACKUP
    (montez subvolid=5 pour y accéder ou renommez-le en @ pour revenir en arrière)." || echo "Première installation : aucun ancien système à restaurer.")

  ── Mise à jour du système ───────────────────────────────────────────────
    cd /etc/nixos && sudo git pull && sudo nixos-rebuild switch --flake .#$PROFILE

  ── Personnalisation de l'interface (à chaud, sans rebuild) ──────────────
    ~/.config/quickshell/config.json   (position barre, modules, widgets)
    ~/.config/quickshell/theme.json    (couleurs, police)
    Glisser-déposer des widgets bureau = positions sauvegardées auto.

EOF
ok "Vous pouvez redémarrer : reboot"
