# Ander-Arch — README de replicación exacta del sistema
Arch Linux + Hyprland (end-4/dots-hyprland) + stack de IA (Claude Code +
gentle-ai + Engram + CodeGraph), pensado para que CUALQUIERA de tus PCs
(igual o distinto hardware: Intel/AMD, con o sin GPU dedicada) termine
siendo una copia funcional idéntica de este sistema.

Convenciones:
- `[UNIVERSAL]` = corré esto en cualquier PC, sin importar el hardware.
- `[CONDICIONAL]` = depende del resultado de la FASE 0 (hardware).
- `[DOTFILES]` = clonado/reconstrucción de configuración, no instalación de paquetes.

---

## FASE 0: Detección de hardware [UNIVERSAL]
Antes de instalar nada, identificá tu hardware — decide la rama de la FASE 4.
```bash
lscpu | grep "Model name"     # CPU / iGPU
lspci | grep -E "VGA|3D"      # GPU dedicada, si hay
ping -c 3 archlinux.org       # confirmar internet
```
Según `lspci`: Intel iGPU / AMD / NVIDIA legacy / NVIDIA moderna / sin GPU
dedicada (una VM cae en esta última).

## FASE 1: ISO / Live environment [UNIVERSAL]
```bash
loadkeys dvorak      # opcional, solo si tu teclado no es QWERTY
```
Listo para archinstall (FASE 2).

## FASE 2: archinstall [UNIVERSAL — un solo dato cambia según el disco]
```bash
archinstall
```
Configuración a elegir en el wizard (igual en cualquier PC):
- Locales: keyboard dvorak, locale en_US.UTF-8
- Disk: best-effort default — boot (fat32, 1GiB) + / (ext4, resto del disco),
  sin cifrado, sin LVM
  - PC original (NVMe): `/dev/nvme0n1`
  - VM (VirtIO): `/dev/vda`
- Swap: zram, compresión zstd
- Bootloader: systemd-boot + UKI
- Kernel: linux
- Profile: Minimal (el DE lo instala end-4 después, no acá)
- Applications: Bluetooth, Audio pipewire, power-profiles-daemon, Firewall ufw
- Network configuration: Network Manager
- Additional packages: base-devel git networkmanager
- Timezone: America/Bogota, NTP: Enabled

Confirmá con Install y esperá a que termine.

## FASE 3: Primer arranque [UNIVERSAL]
En una VM: antes de reiniciar, sacá la ISO del CD-ROM virtual (en virt-manager:
detalles de la VM -> SATA CDROM 1 -> Disconnect), si no va a bootear la ISO
de nuevo en vez del disco instalado.
```bash
reboot
```
Login con el usuario que creaste, y actualizá:
```bash
sudo pacman -Syu
```
