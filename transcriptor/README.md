# Transcriptor de audio del sistema

Graba **lo que suena** (clase por videollamada, video de YouTube, reunión) y lo va
transcribiendo **en paralelo, mientras sigue sonando**. Al cortar, en segundos
tenés un Markdown con marcas de tiempo listo para estudiar.

No usa el micrófono. Nunca. Captura el stream de audio de la aplicación que está
reproduciendo, o el monitor de PipeWire — siempre la salida, jamás la entrada.

---

## Qué hace distinto

| | |
|---|---|
| **Transcribe mientras grabás** | Corta en trozos y los procesa en segundo plano. Una clase de 2 h no tarda 2 h en salir: al cortar faltan segundos |
| **Captura la app, no el altavoz** | Medido en una clase real: el stream de la app trae **37× más señal** que el monitor del sink (p90 4801 vs 131). El monitor cobra dos peajes que el stream no: el volumen del sistema y el códec del Bluetooth |
| **Corta por silencio, con solapamiento** | Cortar cada N segundos exactos parte palabras al medio. Corta donde hay pausa, y los trozos se solapan 2 s para que ninguna palabra se pierda en el borde. El texto repetido se quita solo |
| **Umbral que se calibra solo** | Un umbral fijo no puede servir: el stream de una app tiene piso de ruido ~121 y el monitor ~12. Estima el piso real y se acomoda |
| **No transcribe silencio** | Whisper alucina sobre audio mudo (*"Subtítulos por la comunidad"*, *"no, no, no…"* cien veces). Los trozos sin voz se descartan antes de salir de la máquina — y así tampoco gastan cuota |
| **Te avisa que está prendido** | Notificación que se actualiza sola cada 15 s (tiempo, cola, fuente, motor) y **reaparece en pantalla cada 5 minutos** |
| **Se apaga solo** | 45 min de silencio y corta. Aguanta un descanso de clase; el escenario "lo dejé toda la noche" no existe |
| **Sigue la salida de audio** | Si en media clase te ponés los auriculares, la captura se re-engancha sola |
| **Marcador de dudas** | Un atajo clava un ⚠️ en la transcripción. Después repasás esos seis puntos, no las 8.000 palabras |

---

## El motor de transcripción

Hay dos, y se eligen solos:

| Motor | Cuál es | Cuándo se usa |
|---|---|---|
| **Groq** | `whisper-large-v3-turbo` en la nube | Por defecto. Mucho mejor con nombres propios y términos técnicos, y no le pide nada al CPU |
| **Local** | `faster-whisper small` en tu máquina | Respaldo automático: sin internet, sin clave o si Groq devuelve error |

Con `--motor groq` o `--motor local` se fuerza uno. Para ver qué usaría ahora:

```bash
transcriptor motor            # qué motor usaría y por qué
transcriptor motor --probar   # además valida la clave contra Groq (no gasta audio)
```

`--probar` pregunta por la lista de modelos en vez de mandar grabación: es la forma
barata de contestar *"¿mi clave sigue viva?"* sin enviar un solo segundo de audio.

**Qué sale de tu máquina:** con Groq, el audio de la clase viaja a un servidor de
terceros. Con el motor local no sale nada. El silencio nunca se envía en ninguno
de los dos casos.

**Costo:** se factura por minuto de audio. El pie de cada transcripción dice
cuántos minutos se enviaron, para poder cruzarlo con el *spend limit* de la
consola de Groq.

---

## Instalación en un PC nuevo

El proyecto vive dentro del repo `Ander-Arch` (es `~/.config/transcriptor/`), así
que **llega solo** al clonar los dotfiles. En cada máquina hay que hacer dos cosas:
poner la clave y —si querés respaldo sin internet— bajar el modelo local.

### 1. Dependencias del sistema

```bash
sudo pacman -S --needed pipewire pipewire-pulse libpulse libnotify curl fuzzel uv
sudo pacman -D --asexplicit uv     # uv suele venir como dependencia de otro paquete
```

`uv` solo hace falta para el respaldo local.

### 2. Instalador

```bash
bash ~/.config/transcriptor/install.sh
```

Te pide la API key de Groq (se saca en <https://console.groq.com/keys>) y la guarda
en `~/.local/share/transcriptor/groq.key` con permisos `600`.

> **Por qué ahí y no en `.env` ni en `fish/conf.d/secrets.fish`:** `~/.config` es un
> repo público — un `.env` adentro está a un `git add -A` de publicar tu clave. Y
> `secrets.fish` solo lo lee fish: el daemon lo lanza Hyprland, cuyo entorno no
> tiene esas variables. Un archivo propio fuera del repo resuelve las dos cosas.
> (Igual, si `GROQ_API_KEY` está en el entorno, tiene prioridad.)

Si solo querés Groq, sin el modelo local de ~500 MB:

```bash
bash ~/.config/transcriptor/install.sh --sin-local
```

### 3. Verificar

```bash
transcriptor motor      # tiene que decir: Groq (whisper-large-v3-turbo)...
transcriptor estado     # ○ apagado
```

Si dice `command not found`, en fish: `fish_add_path ~/.local/bin`.

---

## Uso

```bash
transcriptor elegir                   # menú con las carpetas de ~/Proyectos
transcriptor materia HeadFirst-Java   # o fijarla a mano
transcriptor materia                  # ¿cuál está activa? y a qué ruta va

transcriptor alternar                 # prende o apaga (esto es lo que usa el atajo)
transcriptor estado                   # ⏺ 12:40 · HeadFirst-Java (1 en cola)
transcriptor marcar                   # clava un ⚠️ "no entendí esto" acá
transcriptor detener                  # corta, vacía la cola y cierra el archivo

transcriptor donde UML-Java           # ¿dónde caería? (no graba ni crea nada)
transcriptor iniciar UML-Java         # forzar otra materia solo esta vez
```

### Atajos (Hyprland)

| Atajo | Qué hace |
|---|---|
| `CTRL+SUPER+ALT+P` | Menú para elegir la materia |
| `CTRL+SUPER+ALT+R` | Prende/apaga (usa la materia activa) |
| `CTRL+SUPER+ALT+D` | Marca una duda en el punto actual |

Ningún atajo lleva el nombre de la materia escrito adentro: cambiar de materia no
toca la config de Hyprland.

### El aviso de "estoy grabando"

Vive dentro del daemon (no hay script aparte) y funciona en dos ritmos, por una
razón medida y no por gusto:

**En el daemon de notificaciones de Quickshell, `-t 0` NO deja el cartel fijo en
pantalla.** Medido: el popup dura menos de 11 segundos y después se esconde, aunque
se pida que no expire — `-t 0` solo mantiene la entrada en el centro de
notificaciones. Y reemplazarla con `-r <id>` la actualiza **en silencio**: no vuelve
a mostrarla. Lo único que hace aparecer el cartel es **crear** una notificación nueva.

De ahí los dos ritmos:

- **Cada 15 s** se actualiza el texto en silencio. Si abrís el centro de
  notificaciones, lo que dice es verdad: tiempo, cola, fuente y motor real.
- **Cada 5 min** se cierra y se crea de nuevo, así el cartel reaparece. Ese es el
  recordatorio que evita dejarlo prendido sin darte cuenta.

Además pide el id de vuelta (`-p`) en cada refresco: si la notificación fue cerrada
—porque la descartaste, o porque el daemon cerró el grupo entero de la app—
reemplazar un id muerto no muestra nada; con el id nuevo, el aviso se recupera solo.

Y dice el motor que **realmente** hizo el último trozo, no el que se eligió al
arrancar: si Groq se cae a mitad de clase y sigue en local, el aviso lo delata.

> **Con dos monitores:** el cartel sale en el monitor **enfocado**, no siempre en el
> mismo. Así ubica los popups Quickshell.

### Dónde queda la transcripción

- Si existe `~/Proyectos/<materia>/` → `~/Proyectos/<materia>/material/`, la carpeta
  que el flujo de estudio ya lee.
- Si no existe → `~/Transcripciones/<materia>/`, para no crear proyectos fantasma
  por un error de tipeo.

El nombre sale solo: `2026-08-12-2142-analisis-datos.md`.

### El formato del texto

**Un párrafo por trozo, separados por una línea en blanco.**

```markdown
**[01:20]** Ustedes me venían preguntando si pueden instalar una IA de forma local…

> ⚠️ **DUDA** — no entendi esto (marcado en 01:51)

**[02:03]** Y vamos a poner descargar Olama…
```

El párrafo va en una sola línea larga a propósito: este archivo se lee por
encima y sobre todo se le pasa a una IA, y para eso el párrafo entero de corrido
es mejor que cortado. Para leerlo cómodo en Neovim: `:set wrap linebreak`.

**La línea en blanco después de la duda no es decorativa.** La línea del ⚠️ es
una cita de Markdown (empieza con `>`), y sin el renglón en blanco debajo, la
*continuación perezosa* de Markdown se traga todo el texto siguiente dentro de
la cita: se ve pintado de otro color de ahí para abajo, como si la duda nunca
terminara.

La ruta se dice en cuatro momentos: al correr `donde`, al elegir la materia, al
arrancar (terminal y notificación) y en `transcriptor estado`.

### Opciones

| Opción | Default | Para qué |
|---|---|---|
| `--motor` | `auto` | `groq` o `local` para forzar uno |
| `--idioma` | `es` | Código ISO. `en` para una clase en inglés |
| `--modelo` | `small` | Modelo **local** de respaldo: `tiny`/`base` si el PC sufre |
| `--umbral` | adaptativo | Fija el umbral de voz a mano (0-32768). Rara vez hace falta |
| `--app` | detectada sola | Forzar la app a capturar (`Brave`, `mpv`…) |
| `--dispositivo` | — | Fuente fija de PipeWire. **Desactiva** el seguimiento automático |
| `--silencio-max` | `45` | Minutos de silencio antes de apagarse solo |

---

## Si algo falla

| Síntoma | Causa probable | Solución |
|---|---|---|
| `transcriptor: command not found` | `~/.local/bin` no está en el PATH | `fish_add_path ~/.local/bin` |
| Usa el motor local sin querer | Falta la clave o no hay internet | `transcriptor motor` te dice exactamente por qué |
| El texto sale como `no, no, no…` o *"Subtítulos por la comunidad"* | Está capturando una fuente casi muda y el modelo alucina | Mirá la fuente en `transcriptor estado`. Si dice `.monitor` y hay varias apps sonando, cerrá las que no sirven o usá `--app <nombre>` |
| Suenan varias apps y agarra la mezcla | No se puede adivinar cuál querés | `transcriptor iniciar --app Brave` |
| Con auriculares Bluetooth transcribe peor | Perfil `headset-head-unit` (HSP/HFP): mono 16 kHz calidad teléfono | `pactl set-card-profile <bluez_card…> a2dp-sink`. Desactiva el micrófono de los auriculares |
| El perfil A2DP se revierte solo | Una app tomó el micrófono y WirePlumber cambió el perfil | Ver "Bluetooth" abajo |
| La cola crece y no baja | Solo pasa con el motor local | `--modelo base`, o poné la clave de Groq |
| Groq responde 429 | Pasaste la cuota por minuto | Reintenta solo dos veces y después sigue en local. No se pierde audio |

El log vive en `~/.local/share/transcriptor/transcriptor.log`.

### Bluetooth

WirePlumber trae `bluetooth.autoswitch-to-headset-profile = true`: cuando
**cualquier** app abre el micrófono, tus auriculares pasan a modo headset y toda la
salida cae a mono 16 kHz. Si nunca usás el micrófono de los auriculares, se apaga
creando `~/.config/wireplumber/wireplumber.conf.d/50-bluetooth-sin-microfono.conf`:

```
wireplumber.settings = {
  bluetooth.autoswitch-to-headset-profile = false
}
```

(Ese archivo necesita su línea `!/wireplumber` en el `.gitignore` del repo.)

---

## Cómo funciona por dentro

```
pw-record ──► stream de la app (o monitor del sink)
    │  PCM crudo 16 kHz mono s16
    ▼
medidor de volumen (RMS cada 30 ms) + piso de ruido adaptativo
    │  corta en pausas de 0,8 s, entre 12 s y 45 s, con 2 s de solapamiento
    ▼
cola de trozos ──► worker ──► Groq  ─(falla)─►  local  ──► Markdown
    │                            │
    │                            └─ contexto: la cola del texto anterior va
    │                               como `prompt`, que mejora nombres propios
    │                               y la continuidad entre trozos
    │
    └─ estado en /run/user/<uid>/transcriptor/state.json
           └─ lo leen: la notificación fija y `transcriptor estado`
```

**Un solo worker, no varios.** El orden de los trozos queda garantizado, que en una
transcripción importa más que la velocidad bruta.

**Nada se pierde al detener.** `detener` no mata el proceso: encola el pedazo suelto,
espera a que la cola se vacíe y recién ahí cierra el archivo. Y cada trozo se escribe
al disco apenas se transcribe, así que ni un corte de luz se lleva lo ya hecho. Lo
único que vive en RAM es el audio que todavía espera turno: esperá la notificación
**"⏹ Transcripción lista"** antes de apagar.
