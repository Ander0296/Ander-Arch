# Ander-Arch

Réplica exacta de mi sistema en cualquier PC: **Arch Linux + Hyprland ([end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)) + mis dotfiles + stack de IA** (Claude Code, gentle-ai, Engram, CodeGraph).

Este repo **ES** mi `~/.config` versionado. Clonarlo encima de `~/.config` restaura todo idéntico: keybinds (hjkl, clúster Z, scratchpad), layout scrolling, teclado dvorak-alt-intl, kitty, fish, starship, yazi (plugins incluidos), Neovim/LazyVim (versiones exactas vía `lazy-lock.json`) y Quickshell con mis fixes.

---

## Cómo usar esta guía (leer esto primero)

**Qué es cada archivo de este repo:**

| Archivo | Qué es | Cuándo se usa |
|---|---|---|
| `README.md` | Esta guía. Es el único documento que hay que seguir | Siempre abierto en otro dispositivo (celular u otra PC) mientras instalás |
| `bootstrap.sh` | Script que instala todas las apps y ajustes de la fase 7 | Se ejecuta UNA vez en la fase 7. No hay que descargarlo ni moverlo a ningún lado: llega solo a `~/.config` en la fase 6 |
| `pkgs-pacman.txt` / `pkgs-aur.txt` | Las listas de paquetes que `bootstrap.sh` lee | Nunca se ejecutan a mano; solo se **editan** cuando instalás algo nuevo (ver fase 10) |
| Todo lo demás (`hypr/`, `fish/`, `nvim/`, `yazi/`…) | La configuración en sí | Se restaura sola en la fase 6 |

**Cómo leer los comandos:**
- Los bloques grises son comandos: se escriben tal cual en la terminal y se presiona Enter, uno por línea.
- Las líneas que empiezan con `#` son comentarios explicativos — **no se escriben**.
- Lo que está entre `<>` se reemplaza por tu valor (sin los `<>`).

**Qué necesitás:** una USB con la ISO de Arch, internet (cable idealmente; WiFi también sirve, ver fase 1) y esta guía abierta en otro dispositivo.

**El orden es el de las fases: 1 → 10, sin saltear.** La única que cambia según la máquina es la 4 (GPU). La fase 0 no es parte de la instalación: se hace UNA sola vez en un PC que ya funciona, para preparar el repo.

---

## 0. Solo la primera vez — en un PC que ya funcione

Subir los 4 archivos de replicación a la **raíz** del repo (al mismo nivel que este README) y habilitarlos en el gitignore:

```bash
cd ~/.config
# (mover acá README.md, bootstrap.sh, pkgs-pacman.txt y pkgs-aur.txt — el README nuevo reemplaza al viejo)
printf '%s\n' '' '# --- Replicación multi-PC ---' '!/bootstrap.sh' '!/pkgs-pacman.txt' '!/pkgs-aur.txt' '!/illogical-impulse' >> .gitignore
git status     # revisar: README y .gitignore modificados + bootstrap.sh, pkgs-*.txt e illogical-impulse/ nuevos
git add -A && git commit -m "replicación: bootstrap, listas de paquetes, config de Quickshell" && git push
```

(El bloque usa `printf` y no heredoc porque el shell por defecto es fish, que no soporta `<<EOF`.)

También se puede hacer desde el navegador en cualquier dispositivo: GitHub → repo → *Add file → Upload files* (los 4 archivos) y editar `.gitignore` agregando las 4 líneas de arriba.

Regla permanente: **cada paquete nuevo que instales va a `pkgs-pacman.txt` o `pkgs-aur.txt`** + commit. Eso mantiene viva la "copia perfecta".

**Verificación de que no falta ninguna app** (recomendado la primera vez). El conteo total: `pacman -Qqe | wc -l` (paquetes elegidos a propósito); desglose con `-Qqen` (oficiales) y `-Qqem` (AUR/locales).

```bash
# AUR instalados que FALTAN en pkgs-aur.txt:
pacman -Qqem | grep -v '^illogical-impulse' | sort > /tmp/a
grep -v '^#' pkgs-aur.txt | grep -v '^$' | sort > /tmp/b
comm -23 /tmp/a /tmp/b     # ignorar: yay y nvidia-580xx-* (hardware, van por fase 4)

# Oficiales explícitos que FALTAN en pkgs-pacman.txt:
pacman -Qqen | sort > /tmp/c
pacman -Qqg illogical-impulse 2>/dev/null | sort > /tmp/d
comm -23 /tmp/c /tmp/d > /tmp/e
grep -v '^#' pkgs-pacman.txt | grep -v '^$' | sort > /tmp/f
comm -23 /tmp/e /tmp/f     # ignorar: base, base-devel, linux y los de archinstall/fase 4
```

Todo lo demás que aparezca es una app olvidada → agregarla a la lista correspondiente antes del commit.

## 1. Bootear la USB / Live ISO

1. Conectá la USB, encendé el PC y abrí el **menú de arranque** (tecla al encender según la marca: `F12`, `F9`, `F8` o `Esc`). Elegí la USB → *Arch Linux install medium*.
2. Aparece una terminal con `root@archiso`. Ahí:

```bash
loadkeys dvorak               # opcional, solo comodidad en el live

# Solo si NO tenés cable de red (WiFi):
iwctl device list                                  # anotá el nombre (ej: wlan0)
iwctl station wlan0 connect "NombreDeTuRed"        # pide la contraseña

ping -c 3 archlinux.org       # confirmar internet (0% packet loss)
lspci | grep -E "VGA|3D"      # ANOTAR la GPU → decide la fase 4
archinstall
```

## 2. archinstall

Es un menú: se navega con flechas, Enter selecciona, Esc vuelve. Configurar (idéntico en cualquier PC, solo cambia el disco):

| Opción | Valor |
|---|---|
| Locales | keyboard `dvorak` · locale `en_US.UTF-8` |
| Mirrors | tu región + Worldwide · repo `multilib` habilitado |
| Disk | best-effort en el disco destino (`nvme0n1` / `sda` / `vda`) → boot fat32 1 GiB + `/` ext4 · sin cifrado ni LVM |
| Swap | zram (zstd) |
| Bootloader / Kernel | systemd-boot + UKI · `linux` |
| Profile | **Minimal** (el escritorio lo instala end-4 en la fase 5) |
| Applications | Bluetooth · pipewire · power-profiles-daemon · ufw |
| Network | NetworkManager · NTP enabled · Timezone `America/Bogota` |
| Additional packages | `base-devel git networkmanager` |
| Authentication | crear tu usuario con sudo |

→ **Install** y confirmar. Al terminar, sacar la USB y reiniciar (en VM: expulsar la ISO virtual antes).

## 3. Primer arranque

Vas a ver una pantalla negra con `login:` — es normal, todavía no hay escritorio (llega en la fase 8). Entrá con tu usuario y contraseña.

```bash
# Solo si usás WiFi (NetworkManager ya está instalado):
nmcli device wifi connect "NombreDeTuRed" password "TuContraseña"

sudo pacman -Syu               # actualizar el sistema

# Instalar yay (permite instalar paquetes de AUR):
cd ~ && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si && cd ~
```

## 4. GPU — única fase condicional

Según lo anotado en la fase 1:

| GPU detectada | Qué hacer |
|---|---|
| Solo Intel | `sudo pacman -S --needed mesa vulkan-intel lib32-mesa lib32-vulkan-intel` → fase 5 |
| Solo AMD | `sudo pacman -S --needed mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon` → fase 5 |
| NVIDIA Turing o más nueva (GTX 16xx / RTX) | `sudo pacman -S --needed nvidia-open nvidia-utils lib32-nvidia-utils` → luego **4.1** |
| NVIDIA Pascal/Maxwell/Volta (MX330, GTX 10xx…) | **4.2** (el caso del Acer Aspire 3 original) |
| VM / sin GPU dedicada | nada — fase 5 directo |

### 4.1 KMS NVIDIA (ambas ramas NVIDIA)

```bash
sudo sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf   # correr UNA sola vez
echo 'options nvidia_drm modeset=1' | sudo tee /etc/modprobe.d/nvidia.conf
sudo mkinitcpio -P
sudo systemctl enable nvidia-persistenced
sudo reboot
lsmod | grep nvidia            # tras reiniciar: driver "nvidia", ya no "nouveau"
```

### 4.2 NVIDIA legacy (Optimus Intel + Pascal/Maxwell)

`nvidia-open` **no funciona** con estas tarjetas (sin GSP). Driver desde AUR:

```bash
sudo pacman -S --needed linux-headers mesa vulkan-intel lib32-mesa lib32-vulkan-intel
yay -S nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils nvidia-580xx-settings
dkms status                    # → nvidia/580.x … installed
```

→ luego **4.1**.

## 5. end-4/dots-hyprland

```bash
git clone https://github.com/end-4/dots-hyprland ~/dots-hyprland
cd ~/dots-hyprland && ./setup install
```

Tarda bastante (instala Hyprland, Quickshell y decenas de paquetes). Notas:
- **NO** seleccionar UWSM si lo pregunta.
- El warning final `HYPRLAND_INSTANCE_SIGNATURE not set` es normal desde TTY.

## 6. Restaurar TODA la configuración (el paso clave)

Convierte el `~/.config` recién creado por end-4 en este repo — pisa la config base con la mía, sin tocar lo no versionado:

```bash
cd ~/.config
git init -b main                                                   # inicia un repo git vacío acá
git remote add origin https://github.com/Ander0296/Ander-Arch.git  # lo conecta a este repo
git fetch origin                                                   # descarga todo (aún sin aplicar)
git reset --hard origin/main                                       # APLICA: pisa lo versionado con mi config
git branch --set-upstream-to=origin/main main                      # deja "git pull/push" funcionando a futuro
```

Listo: keybinds, dvorak, yazi, nvim, fish, Quickshell — todo idéntico desde el primer login. Lo ignorado (colores de matugen, `monitors.lua`) lo regenera el sistema solo.

## 7. Apps y ajustes de sistema

Los archivos `bootstrap.sh` y `pkgs-*.txt` ya están en `~/.config` (llegaron en la fase 6). Solo hay que ejecutar:

```bash
cd ~/.config
git pull             # por si el repo recibió cambios desde que hiciste la fase 6
bash bootstrap.sh    # con "bash" adelante: funciona aunque el archivo no tenga permiso de ejecución
```

Instala todo (Brave, 1Password, LazyVim y sus deps, Java + IDEs, yazi, zoxide, fastfetch, Anki, OBS…), protege los paquetes de end-4 de `pacman -Syu`, configura npm en el home, instala Claude Code, clona el tema de fastfetch y crea las carpetas de `~/Pictures`. **Idempotente**: re-ejecutarlo es seguro, no reinstala ni duplica nada.

### 7-B. Alternativa manual por grupos

Para cuando `bootstrap.sh` todavía no está en el repo (fase 0 pendiente), o si preferís instalar de a partes. Cada línea es un grupo completo:

```bash
# CLI base / LazyVim + git
sudo pacman -S --needed neovim git ripgrep fd fzf tree-sitter-cli gcc lazygit git-delta github-cli wl-clipboard nodejs npm
# CLI extras
sudo pacman -S --needed bat sd tealdeer btop
# Yazi + previews / papelera
sudo pacman -S --needed yazi ffmpeg 7zip jq poppler imagemagick trash-cli
# Shell / terminal
sudo pacman -S --needed starship zoxide fastfetch
# Sistema
sudo pacman -S --needed sddm timeshift rtkit nano ntfs-3g ntfsprogs
# Java + IDEs (repos oficiales)
sudo pacman -S --needed jdk-openjdk maven intellij-idea-community-edition netbeans
# Apps de escritorio
sudo pacman -S --needed anki obs-studio mpv imv kate zathura zathura-pdf-mupdf plasma-browser-integration
# Virtualización (VMs con virt-manager)
sudo pacman -S --needed qemu-full libvirt virt-manager dnsmasq edk2-ovmf
sudo systemctl enable libvirtd && sudo usermod -aG libvirt $USER
# AUR: apps
yay -S --needed brave-bin 1password ttf-jetbrains-mono-nerd onlyoffice-bin
# AUR: Eclipse (pesado, puede tardar)
yay -S --needed eclipse-java-bin
```

Esto cubre solo los **paquetes**. Los demás ajustes (npm, Claude Code, IgnoreGroup, tema de fastfetch, carpetas) los completa `bash bootstrap.sh` cuando esté disponible — al ser idempotente, no repite lo ya instalado.

## 8. Primer login gráfico

```bash
sudo pacman -S --needed sddm      # por si venís por el camino sin bootstrap
sudo systemctl enable sddm
sudo reboot
```

En la pantalla de login (SDDM) elegir la sesión **Hyprland** (no UWSM) y entrar. El escritorio ya arranca con toda la configuración. `Super+Enter` abre la terminal, `Super+/` muestra todos los keybinds en vivo.

> Si aún no corriste `bootstrap.sh` ni el 7-B completo, la terminal puede mostrar 1–2 errores tipo `command not found: zoxide/fastfetch` al abrirse — desaparecen al completar la fase 7.

## 9. Pasos manuales (~10 min, no automatizables)

1. **1Password**: abrirlo, iniciar sesión, Settings → activar **SSH agent**. Crear `~/.config/1password/ssh/agent.toml` con:
   ```toml
   [[ssh-keys]]
   vault = "Personal"
   [[ssh-keys]]
   item = "Github"
   vault = "LLave SSH"
   ```
   Probar: `ssh-add -l` y `ssh -T git@github.com` (la llave vive en la bóveda → funciona igual en todos los PCs, sin generar nada).
2. **Remoto a SSH** (habilita `git push` desde este PC):
   ```bash
   cd ~/.config && git remote set-url origin git@github.com:Ander0296/Ander-Arch.git
   ```
3. **Claude Code + gentle-ai**: ejecutar `claude` (login) y después:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/scripts/install.sh | bash
   ```
   Wizard: `claude-code` · `gentleman` · `Dev Stack + Polish` · TDD `Disable` · `CodeGraph` ✅. Verificar: `gentle-ai doctor`.
4. **Neovim**: abrir `nvim` (instala los plugins solo) → comando `:Lazy restore` clava las versiones exactas de `lazy-lock.json`. Mason instala los LSP al abrir cada lenguaje.
5. **Imágenes** (no se versionan por peso): poblar `~/Pictures/Wallpapers` con los botones *Random: Konachan / osu!* de Settings (`Super+I`), y copiar tus PNGs a `~/Pictures/FastfetchLogos`.
6. **API key de Gemini** (solo Quickshell — traducción IA, estilo del reloj Cookie): `Super+A` → `/key` (queda en el keyring del sistema, no viaja por git).
   Tip: guardar la key en 1Password → en cada PC nuevo se copia desde la bóveda.
7. **Snapshot de seguridad**: `sudo timeshift --create --comments "sistema completo replicado"`.

## 10. Sincronizar cambios entre todos los PCs

Publicar un cambio (desde cualquier PC):

```bash
cd ~/.config && git add -A && git commit -m "qué cambié" && git push
```

Recibirlo en los demás:

```bash
cd ~/.config && git pull
hyprctl reload        # aplica los cambios de Hyprland al instante
```

- Tocaste Quickshell (QML) → `Ctrl+Super+R`.
- Cambió `lazy-lock.json` → en nvim: `:Lazy restore`.
- Agregaste un paquete a `pkgs-*.txt` → `bash bootstrap.sh` en los demás PCs (seguro, no repite nada).

## Actualizar end-4 (upstream) sin perder lo mío

`pacman -Syu` no toca las dots (IgnoreGroup, lo puso bootstrap). La actualización es siempre a propósito:

```bash
cd ~/dots-hyprland && git pull && ./setup install
cd ~/.config && git status     # ver qué archivos pisó upstream
```

Por cada archivo modificado: `git checkout -- <archivo>` recupera mi versión, o `git add` + commit adopta la de upstream. Ojo con `quickshell/ii/scripts/colors/applycolor.sh`: mi fix (apply_anyterm desactivado — evita que cambiar wallpaper trabe las terminales) vive ahí y upstream lo pisa; `git checkout --` lo restaura.

## Notas

- **Blur**: apagado global en `hypr/custom/general.lua` (la iGPU Iris Plus del PC original no daba abasto). Reactivarlo es 1 línea (`decoration.blur.enabled = true`), pero al ser config versionada aplica a todos los PCs.
- `hypr/monitors.lua` y `workspaces.lua`: por-máquina a propósito (ignorados; los genera `nwg-displays`).
- **fish viaja completo** con el repo: `config.fish`, `functions/` (`fastfetch-random`, `y` de yazi) y todo `conf.d/` — `1password.fish` (socket SSH del agente), `path.fish` (`~/.local/bin` + npm-global), `editor.fish` (`EDITOR=nvim`) y los dos `fish_frozen_*` (tema y bindings congelados de fish). **Única excepción**: `conf.d/secrets.fish` (ignorado a propósito) — hoy no hace falta crearlo; solo sería necesario si en algún momento reactivás avante.nvim (ver nvim/CLAUDE.md), que es lo único que consumía `GEMINI_API_KEY` ahí.
- **nvim**: `claudecode.nvim` (Claude Code real, vía CLI `claude`) es el asistente de IA in-editor activo; `avante.nvim` quedó desactivado (`enabled = false`) para no pisar sus atajos. Guía completa de uso en `nvim/guia.txt`.
- Verificación rápida final: `Super+Enter` (kitty con fastfetch-random) · `Super+/` (cheatsheet) · `z <dir>` (zoxide) · en `yazi`: `m e` (Claude explica el archivo) · `gentle-ai doctor`.
