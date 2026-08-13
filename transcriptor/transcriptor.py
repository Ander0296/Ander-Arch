#!/usr/bin/env python3
"""
Transcriptor de audio del sistema.

Captura lo que suena (el stream de la app que reproduce, o el monitor de
PipeWire), lo corta en trozos por silencio con solapamiento y los transcribe
EN PARALELO mientras la clase sigue. Al terminar queda un Markdown con marcas
de tiempo, listo para usarse como material/ de un proyecto de estudio.

Motor de transcripcion:
  1. Groq (whisper-large-v3-turbo) — rapido y muy superior en nombres propios.
  2. Local (faster-whisper small) — respaldo si no hay red, clave o cuota.

Subcomandos:
    elegir              menu para elegir la materia (fuzzel)
    materia [nombre]    fija o muestra la materia activa
    donde <materia>     donde caeria la transcripcion, sin grabar
    iniciar [materia]   arranca la grabacion en segundo plano
    alternar [materia]  inicia si esta apagado, detiene si esta prendido
    marcar              clava un "no entendi esto" en el punto actual
    estado              una linea con el estado (para la barra o el bind)
    detener             corta, vacia la cola y cierra el archivo
    motor               que motor se usaria ahora y por que
    descargar-modelo    baja el modelo local de respaldo
"""

import argparse
import array
import json
import math
import os
import queue
import re
import signal
import subprocess
import sys
import threading
import time
import unicodedata
import wave
from collections import deque
from datetime import datetime
from pathlib import Path

# ── Formato de audio ────────────────────────────────────────────────────────
# 16 kHz mono s16 es exactamente lo que comen Whisper y la API de Groq: no hay
# que resamplear, y pesa 32 KB por segundo.
RATE = 16000
CHANNELS = 1
SAMPLE_BYTES = 2
BYTES_PER_SEC = RATE * CHANNELS * SAMPLE_BYTES  # 32000

FRAME_MS = 30  # ventana con la que medimos volumen
FRAME_BYTES = int(BYTES_PER_SEC * FRAME_MS / 1000)  # 960 bytes
FRAME_SEC = FRAME_MS / 1000

# ── Reglas de corte ─────────────────────────────────────────────────────────
# El corte va por SILENCIO, no por reloj: cortar cada N segundos exactos parte
# palabras al medio. Pero en un video o una clase corrida puede no haber NUNCA
# 0,8 s de silencio (medido: todos los cortes caian justo en el maximo), asi
# que el corte forzado existe igual — y por eso existe el SOLAPAMIENTO.
MIN_CHUNK_SEC = 12.0
MAX_CHUNK_SEC = 45.0
SILENCE_CUT_SEC = 0.8
# El trozo nuevo arranca 2 s ANTES del final del anterior. Asi la palabra
# partida por un corte forzado aparece entera en al menos uno de los dos, y
# despues se quita el texto repetido comparando las puntas.
OVERLAP_SEC = 2.0
VOICE_RATIO_MIN = 0.08  # trozo con menos voz que esto no se transcribe
# Candado anti-silencio, CALIBRADO con mediciones reales. Se mira el p90 del
# trozo, NO el máximo: un stream inactivo tiene picos sueltos (medido: p90 29
# pero máximo 176) y dos picos aislados alcanzaban para burlar un candado
# basado en el máximo. El p90 no se deja engañar por eso.
#   stream de app inactivo ....... p90  29
#   voz por el monitor del sink .. p90 131   (peor caso: volumen 36% + HSP)
#   voz por el stream de la app .. p90 4801
# 80 parte ese rango dejando margen para los dos lados.
P90_MINIMO_CHUNK = 80.0
GANANCIA_MAX = 30.0  # tope de amplificacion por trozo (ver normalizar())

# ── Umbral adaptativo ───────────────────────────────────────────────────────
# Un umbral FIJO no puede funcionar: medido en la misma clase, el stream de la
# app llega con piso de ruido ~121 y el monitor del sink con ~12. Un numero que
# sirve para uno tira a la basura todo lo del otro. Se calibra solo.
VENTANA_PISO_SEC = 20  # cuanto audio reciente se mira para estimar el piso
PISO_MULTIPLICADOR = 3.0  # cuanto hay que superar al ruido para contar como voz
# 25 y no 8: el ruido de fondo de un stream inactivo llega a 8 (p90 medido),
# así que un umbral de 8 tomaba ese ruido por voz y mandaba silencio a Groq,
# que devolvía "Gracias. Gracias.".
PISO_MINIMO = 25.0  # suelo absoluto, por si la fuente es digital y muda
PISO_SUBIDA_MAX = 1.05  # el piso puede subir 5% por segundo (baja al instante)

# ── Vigilancia ──────────────────────────────────────────────────────────────
# 45 min y no 10: en una clase hay descansos de media hora, y cortar en el
# recreo es peor que grabar silencio (el silencio no se transcribe ni se envia,
# asi que no cuesta nada). Sigue cubriendo "me lo deje prendido toda la noche".
AUTOSTOP_SILENCE_MIN = 45
CHECK_FUENTE_FRAMES = 150  # cada ~4,5 s revisa si cambio la fuente de audio
REFRESCO_AVISO_SEC = 15  # cada cuanto se actualiza el texto del aviso
# MEDIDO en el daemon de notificaciones de Quickshell: el cartel dura menos de
# 11 s en pantalla aunque se pida `-t 0`, y reemplazarlo con `-r` lo actualiza
# EN SILENCIO, sin volver a mostrarlo. O sea: no existe el "cartel siempre
# visible". Lo unico que hace aparecer el popup es CREAR una notificacion
# nueva, asi que cada tanto se cierra la vieja y se crea otra: eso es lo que
# te recuerda que sigue grabando.
RECORDATORIO_MIN = 5

# ── Groq ────────────────────────────────────────────────────────────────────
GROQ_URL = "https://api.groq.com/openai/v1/audio/transcriptions"
GROQ_MODELO = "whisper-large-v3-turbo"
GROQ_REINTENTOS = 2
GROQ_TIMEOUT = 120
PROMPT_CONTEXTO_CHARS = 200  # cola del texto previo que se manda como contexto

APP_NAME = "Transcriptor"
DATA_DIR = Path.home() / ".local/share/transcriptor"
MODELS_DIR = DATA_DIR / "models"
LOG_FILE = DATA_DIR / "transcriptor.log"
MATERIA_FILE = DATA_DIR / "materia"
# La clave vive FUERA del repo versionado: ~/.config es un repo publico y un
# `git add -A` distraido la publicaria. Ver README.
GROQ_KEY_FILE = DATA_DIR / "groq.key"


# ════════════════════════════════════════════════════════════════════════════
# Estado compartido
# ════════════════════════════════════════════════════════════════════════════

def state_dir() -> Path:
    """Carpeta volatil: vive en RAM (tmpfs) y se borra sola al reiniciar."""
    base = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    d = Path(base) / "transcriptor"
    d.mkdir(parents=True, exist_ok=True)
    return d


def state_file() -> Path:
    return state_dir() / "state.json"


def notif_file() -> Path:
    """Id de la notificacion fija, para poder cerrarla desde otro proceso."""
    return state_dir() / "notificacion.id"


def es_nuestro_daemon(pid: int) -> bool:
    """Confirma que ese pid es NUESTRO daemon, no cualquier proceso vivo.

    No alcanza con preguntar "existe este pid": cuando el daemon muere de
    golpe, Linux tarde o temprano recicla ese numero para otro programa. Si
    solo miraramos existencia, `marcar` le mandaria SIGUSR1 a un inocente — y
    la accion por defecto de SIGUSR1 es MATAR el proceso.
    """
    try:
        return b"transcriptor.py" in Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return False


def read_state() -> dict | None:
    """El estado si hay una grabacion VIVA; si no, None (y limpia la mentira)."""
    try:
        data = json.loads(state_file().read_text())
    except (OSError, ValueError):
        return None
    if not es_nuestro_daemon(data.get("pid", -1)):
        state_file().unlink(missing_ok=True)
        return None
    return data


def write_state(data: dict) -> None:
    """Escritura atomica: nadie puede leer un JSON a medio escribir."""
    tmp = state_file().with_suffix(".tmp")
    tmp.write_text(json.dumps(data))
    tmp.replace(state_file())


# ════════════════════════════════════════════════════════════════════════════
# Notificaciones
# ════════════════════════════════════════════════════════════════════════════

def notify(titulo: str, cuerpo: str = "", urgencia: str = "normal",
           fija: bool = False, reemplazar: int | None = None) -> int | None:
    """Manda una notificacion y devuelve su id.

    `fija=True` usa `-t 0`: no expira nunca (verificado con el daemon de
    Quickshell). Se pide el id SIEMPRE con `-p`, tambien al reemplazar: si la
    notificacion fue cerrada —porque la descartaste, o porque el daemon cerro
    el grupo entero de la app— reemplazar un id muerto no muestra nada. Con el
    id de vuelta, el aviso se recrea solo en el siguiente refresco.
    """
    cmd = ["notify-send", "-a", APP_NAME, "-u", urgencia, "-p"]
    if fija:
        cmd += ["-t", "0"]
    if reemplazar:
        cmd += ["-r", str(reemplazar)]
    cmd += [titulo, cuerpo]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, check=False)
        return int(r.stdout.strip())
    except (OSError, ValueError):
        return None


def cerrar_notificacion(nid: int) -> None:
    """Cierra una notificacion por id (las fijas no se van solas)."""
    subprocess.run(
        ["gdbus", "call", "--session",
         "--dest", "org.freedesktop.Notifications",
         "--object-path", "/org/freedesktop/Notifications",
         "--method", "org.freedesktop.Notifications.CloseNotification", str(nid)],
        capture_output=True, check=False,
    )


def cerrar_aviso_huerfano() -> None:
    """Cierra un aviso fijo que quedo colgado de un daemon muerto a lo bruto."""
    try:
        nid = int(notif_file().read_text().strip())
    except (OSError, ValueError):
        return
    cerrar_notificacion(nid)
    notif_file().unlink(missing_ok=True)


# ════════════════════════════════════════════════════════════════════════════
# Utilidades varias
# ════════════════════════════════════════════════════════════════════════════

def hhmmss(segundos: float) -> str:
    s = int(segundos)
    h, s = divmod(s, 3600)
    m, s = divmod(s, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m:02d}:{s:02d}"


def slug(texto: str) -> str:
    """Nombre de carpeta seguro: sin tildes, sin espacios, minusculas."""
    limpio = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return "".join(c if c.isalnum() else "-" for c in limpio.lower()).strip("-") or "clase"


def describir_motor(activo: str, ultimo: str, usos: dict) -> str:
    """Que motor esta haciendo el trabajo, con la verdad de lo que paso.

    No alcanza con decir el motor elegido al arrancar: si Groq se cae a mitad
    de clase y seguimos en local, el aviso tiene que delatarlo — esos tramos
    salen con peor calidad y hay que poder saberlo sin abrir el archivo.
    """
    if ultimo in ("", "?", None):
        return f"{activo} (sin trozos todavia)"

    caidos = usos.get("local", 0) if activo == "groq" else 0
    if ultimo == "local" and activo == "groq":
        texto = f"local ← Groq no responde ({caidos} tramos asi)"
    elif caidos:
        texto = f"groq · {caidos} tramos salieron en local"
    else:
        texto = ultimo
    if usos.get("error"):
        texto += f" · {usos['error']} con error"
    return texto


def rms(frame: bytes) -> float:
    """Volumen medio del frame (raiz cuadratica media).

    Es la forma barata de preguntar "hay alguien hablando o es silencio":
    eleva cada muestra al cuadrado (para que los negativos no se cancelen),
    promedia y saca la raiz.
    """
    muestras = array.array("h")
    muestras.frombytes(frame)
    if not muestras:
        return 0.0
    return math.sqrt(sum(m * m for m in muestras) / len(muestras))


def pcm_a_wav(pcm: bytes, destino: Path) -> None:
    """Envuelve el PCM crudo en un WAV: es lo que espera la API de Groq."""
    with wave.open(str(destino), "wb") as w:
        w.setnchannels(CHANNELS)
        w.setsampwidth(SAMPLE_BYTES)
        w.setframerate(RATE)
        w.writeframes(pcm)


# Repertorio de alucinaciones de Whisper sobre silencio. Es corto y conocido:
# cuando no oye nada, el modelo rellena con muletillas de subtitulado. Filtrar
# LA SALIDA es mas confiable que intentar detectar el silencio perfecto por
# volumen — medido: un stream "inactivo" de Brave tiene p95 150 y picos de 697,
# asi que ningun umbral gana siempre.
ALUCINACIONES = {
    "gracias", "muchas gracias", "gracias por ver el video",
    "gracias por ver este video", "gracias por su atencion",
    "suscribete", "suscribete al canal", "no te olvides de suscribirte",
    "subtitulos por la comunidad de amara org",
    "subtitulos realizados por la comunidad de amara org",
    "subtitulado por la comunidad de amara org",
    "mas videos en", "hasta la proxima", "nos vemos en el proximo video",
    "no", "si", "y", "ah", "eh", "mm", "ya", "bueno", "ok", "vamos",
    "amara org", "c'est la fin", "thanks for watching",
    "subscribe", "thank you", "you",
}


def es_alucinacion(texto: str) -> bool:
    """¿Este texto es relleno de Whisper sobre silencio, no habla real?

    Se normaliza (sin tildes, sin puntuacion, minusculas) y se COLAPSAN las
    repeticiones, porque la alucinacion tipica es la misma palabra en bucle:
    "Gracias. Gracias." o "no, no, no, no..." cien veces. Solo se descarta si
    ademas es corto: si el profe dice "gracias" en medio de una frase larga,
    eso es habla real y se respeta.
    """
    limpio = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    palabras = [p for p in "".join(
        c if c.isalnum() else " " for c in limpio.lower()).split() if p]
    if not palabras or len(palabras) > 8:
        return False
    sin_repes = [p for i, p in enumerate(palabras) if i == 0 or p != palabras[i - 1]]
    return " ".join(sin_repes) in ALUCINACIONES


# Corta despues de punto, interrogacion o exclamacion, pero SOLO si lo que
# sigue no empieza en minuscula. Asi "etc. y despues" no se parte, y tampoco
# se rompen los decimales tipo "1,5 GB".
PATRON_FRASE = re.compile(r"(?<=[.!?…])\s+(?=[^a-záéíóúüñ])")
ANCHO_MAXIMO = 88  # tope para una frase sin puntuacion interna


def en_frases(texto: str) -> list[str]:
    """Parte el texto en UNA FRASE POR LINEA.

    Una linea = una idea completa: se lee sin scrollear al costado y se puede
    citar un tramo suelto sin arrastrar el parrafo entero. Las frases que
    igual salen larguisimas (Whisper a veces devuelve chorizos sin puntuacion)
    se cortan por palabras, para que ninguna linea se vaya de pantalla.
    """
    lineas = []
    for frase in PATRON_FRASE.split(texto.strip()):
        frase = frase.strip()
        if not frase:
            continue
        if len(frase) <= 100:
            lineas.append(frase)
            continue
        actual = ""
        for palabra in frase.split():
            if actual and len(actual) + 1 + len(palabra) > ANCHO_MAXIMO:
                lineas.append(actual)
                actual = palabra
            else:
                actual = f"{actual} {palabra}".strip()
        if actual:
            lineas.append(actual)
    return lineas


def quitar_solape(anterior: str, nuevo: str, max_palabras: int = 25) -> str:
    """Quita del texto nuevo la parte que ya aparecia al final del anterior.

    Los trozos se solapan 2 s a proposito, asi que esas palabras se transcriben
    DOS veces. Se compara la cola del anterior con la cabeza del nuevo palabra
    por palabra (ignorando mayusculas y puntuacion, que Whisper cambia entre
    pasadas) y se corta la coincidencia mas larga. Se exigen 3 palabras minimo:
    con una o dos, "que" o "de la" darian falsos positivos todo el tiempo.
    """
    if not anterior or not nuevo:
        return nuevo

    def limpiar(p: str) -> str:
        return "".join(c for c in p.lower() if c.isalnum())

    cola = anterior.split()[-max_palabras:]
    cabeza = nuevo.split()
    cola_n = [limpiar(p) for p in cola]
    cabeza_n = [limpiar(p) for p in cabeza[:max_palabras]]

    for k in range(min(len(cola_n), len(cabeza_n)), 2, -1):
        if cola_n[-k:] == cabeza_n[:k]:
            return " ".join(cabeza[k:])
    return nuevo


# ════════════════════════════════════════════════════════════════════════════
# Fuente de audio
# ════════════════════════════════════════════════════════════════════════════

def sink_por_defecto() -> str:
    """El sink activo, por su nombre de nodo (SIN sufijo .monitor).

    El sufijo `.monitor` es un nombre de la capa de compatibilidad PulseAudio.
    `pw-record` es nativo de PipeWire y NO lo entiende: con `--target
    <sink>.monitor` no falla, se engancha a la fuente por defecto — que con
    auriculares en modo headset ES EL MICROFONO. Verificado con `pw-link -l`.
    Para capturar la salida de un sink hay que pasar su nombre pelado y la
    propiedad `stream.capture.sink=true` (ver abrir_captura).
    """
    r = subprocess.run(["pactl", "get-default-sink"],
                       capture_output=True, text=True, check=True)
    return r.stdout.strip()


def origenes_reales() -> list[str]:
    """De donde esta recibiendo audio pw-record, SEGUN PIPEWIRE.

    No alcanza con mirar el `--target` que pedimos: pw-record no falla cuando
    el destino no existe, se cuelga de otra cosa sin avisar. Esta es la unica
    fuente de verdad, y es la comprobacion que faltaba cuando terminamos
    grabando el microfono del usuario sin que nadie se enterara.
    """
    try:
        r = subprocess.run(["pw-link", "-l"], capture_output=True,
                           text=True, check=True)
    except (subprocess.SubprocessError, OSError):
        return []
    origenes, dentro = [], False
    for linea in r.stdout.splitlines():
        if linea.startswith("pw-record:input"):
            dentro = True
            continue
        if dentro:
            limpia = linea.strip()
            if limpia.startswith("|<-"):
                origenes.append(limpia[3:].strip())
            elif not limpia.startswith("|"):
                dentro = False
    return origenes


def fuentes_de_salida() -> tuple[list[str], set[str]]:
    """Todo lo que se puede capturar SIN riesgo de agarrar un microfono.

    Devuelve (streams de apps reproduciendo, nombres de sinks).

    Esta lista blanca no es paranoia: `pw-record --target X` NO FALLA cuando X
    no existe — se engancha en silencio a la fuente por defecto, que con unos
    auriculares en modo headset es EL MICROFONO. Verificado con `pw-link -l`:
    despues de que Brave cerrara su stream, pw-record habia quedado enlazado a
    `bluez_input...capture_MONO` y estaba grabando la voz del usuario. Por eso
    todo destino se valida contra esta lista antes de abrir la captura.
    """
    try:
        datos = json.loads(subprocess.run(
            ["pw-dump"], capture_output=True, text=True, check=True).stdout)
    except (subprocess.SubprocessError, OSError, ValueError):
        return [], set()

    apps, sinks = [], set()
    for obj in datos:
        props = (obj.get("info") or {}).get("props") or {}
        nombre = props.get("node.name")
        clase = props.get("media.class")
        if not nombre:
            continue
        if clase == "Stream/Output/Audio" and nombre not in apps:
            apps.append(nombre)  # una app reproduciendo
        elif clase == "Audio/Sink":
            # Se guarda el nombre PELADO del sink. Su monitor no es un nodo
            # aparte: es un puerto del propio sink, y se captura pidiendo
            # stream.capture.sink=true (ver abrir_captura).
            sinks.add(nombre)
    return apps, sinks


def app_sonando() -> str | None:
    """Nodo de la app que esta reproduciendo, si hay UNA sola.

    Capturar el stream de la app directo da MUCHISIMA mas senal que el monitor
    del sink: medido en una clase real, 37x mas (p90 4801 vs 131). El monitor
    cobra dos peajes que el stream no: el control de volumen del sink (captura
    DESPUES de aplicarlo) y la degradacion del perfil Bluetooth. Con el monitor
    debil, Whisper alucina ("no, no, no, no...") en vez de transcribir.

    Si suenan varias apps a la vez no podemos elegir por vos: se cae al
    monitor, que al menos las mezcla todas.
    """
    nombres, _ = fuentes_de_salida()
    return nombres[0] if len(nombres) == 1 else None


# ════════════════════════════════════════════════════════════════════════════
# Materia activa
# ════════════════════════════════════════════════════════════════════════════

def leer_materia() -> str | None:
    try:
        return MATERIA_FILE.read_text().strip() or None
    except OSError:
        return None


def guardar_materia(nombre: str) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    MATERIA_FILE.write_text(nombre.strip() + "\n")


def proyectos_disponibles() -> list[str]:
    base = Path.home() / "Proyectos"
    if not base.is_dir():
        return []
    return sorted(p.name for p in base.iterdir()
                  if p.is_dir() and not p.name.startswith("."))


def resolver_destino(materia: str, crear: bool = True) -> Path:
    """Donde cae la transcripcion.

    Si existe el proyecto de estudio, va a su material/ (la carpeta que el
    flujo de estudio ya lee). Si no, a ~/Transcripciones/, para no crear
    proyectos fantasma por un error de tipeo.
    """
    proyecto = Path.home() / "Proyectos" / materia
    destino = (proyecto / "material" if proyecto.is_dir()
               else Path.home() / "Transcripciones" / slug(materia))
    if crear:
        destino.mkdir(parents=True, exist_ok=True)
    return destino


# ════════════════════════════════════════════════════════════════════════════
# Motores de transcripcion
# ════════════════════════════════════════════════════════════════════════════

def leer_clave_groq() -> str | None:
    """La clave, del entorno o de un archivo fuera del repo.

    El entorno primero permite probar sin tocar nada; el archivo es lo que
    funciona de verdad, porque el daemon lo lanza Hyprland y el entorno de
    Hyprland no tiene las variables que exporta fish.
    """
    clave = os.environ.get("GROQ_API_KEY", "").strip()
    if clave:
        return clave
    try:
        return GROQ_KEY_FILE.read_text().strip() or None
    except OSError:
        return None


class MotorGroq:
    """Transcribe mandando el audio a Groq (whisper-large-v3-turbo).

    Se usa curl y no una libreria HTTP para no sumar dependencias al entorno:
    curl ya esta en cualquier Arch y es exactamente lo que hacia la version
    anterior de esta herramienta, que funcionaba.
    """

    nombre = "groq"

    def __init__(self, clave: str, idioma: str):
        self.clave = clave
        self.idioma = idioma
        self.segundos_enviados = 0.0  # para poder mirar el gasto al final
        self.cuota_audio = None  # segundos de audio que quedan en la ventana

    def transcribir(self, pcm: bytes, contexto: str = "") -> str:
        self.cuota_audio = None  # segundos de audio que quedan en la ventana
        wav = state_dir() / f"envio-{os.getpid()}.wav"
        pcm_a_wav(pcm, wav)
        try:
            for intento in range(GROQ_REINTENTOS + 1):
                texto, codigo = self._pedir(wav, contexto)
                if codigo == 200:
                    self.segundos_enviados += len(pcm) / BYTES_PER_SEC
                    return texto.strip()
                # 429 = pasaste la cuota por minuto. Es temporal: se espera y
                # se reintenta antes de tirar el trozo al motor local.
                if codigo == 429 and intento < GROQ_REINTENTOS:
                    time.sleep(3 * (intento + 1))
                    continue
                raise RuntimeError(f"Groq respondio {codigo}: {texto[:120]}")
            raise RuntimeError("Groq: sin cuota tras reintentar")
        finally:
            wav.unlink(missing_ok=True)

    def _pedir(self, wav: Path, contexto: str) -> tuple[str, int]:
        cabeceras = state_dir() / f"cab-{os.getpid()}.txt"
        cmd = [
            "curl", "--silent", "--show-error", "--max-time", str(GROQ_TIMEOUT),
            "--dump-header", str(cabeceras),
            "--request", "POST", "--url", GROQ_URL,
            "--header", f"Authorization: Bearer {self.clave}",
            "--form", f"file=@{wav};type=audio/wav",
            "--form", f"model={GROQ_MODELO}",
            "--form", "response_format=text",
        ]
        if self.idioma:
            cmd += ["--form", f"language={self.idioma}"]
        if contexto:
            # El `prompt` de Whisper sesga el vocabulario: pasarle la cola de
            # lo ya transcrito mejora muchisimo los nombres propios y la
            # continuidad entre trozos.
            cmd += ["--form", f"prompt={contexto}"]
        cmd += ["--write-out", "\n%{http_code}"]

        r = subprocess.run(cmd, capture_output=True, text=True, check=False)

        # Groq informa la cuota que queda en cada respuesta. Vale la pena
        # guardarla: contesta sola la pregunta "¿el plan gratis me alcanza?".
        try:
            for linea in cabeceras.read_text().splitlines():
                if linea.lower().startswith("x-ratelimit-remaining-audio-seconds:"):
                    self.cuota_audio = int(float(linea.split(":", 1)[1].strip()))
        except (OSError, ValueError):
            pass
        finally:
            cabeceras.unlink(missing_ok=True)

        cuerpo, _, codigo = r.stdout.rpartition("\n")
        try:
            return cuerpo, int(codigo.strip())
        except ValueError:
            return (r.stderr or r.stdout), 0


class MotorLocal:
    """Respaldo: faster-whisper corriendo en el CPU de la maquina.

    Se carga PEREZOSAMENTE. Con Groq andando no se toca nunca, y asi el
    arranque es instantaneo y no se ocupan ~1 GB de RAM al pedo.
    """

    nombre = "local"

    def __init__(self, modelo: str, idioma: str):
        self.modelo_nombre = modelo
        self.idioma = idioma
        self._modelo = None

    def _cargar(self):
        if self._modelo is None:
            from faster_whisper import WhisperModel
            self._modelo = WhisperModel(
                self.modelo_nombre, device="cpu",
                compute_type="int8",  # cuantizado: unica forma sensata en este CPU
                cpu_threads=os.cpu_count() or 4,
                download_root=str(MODELS_DIR),
            )
        return self._modelo

    def transcribir(self, pcm: bytes, contexto: str = "") -> str:
        import numpy as np
        modelo = self._cargar()
        audio = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
        # NORMALIZACION: el audio puede llegar a -60 dBFS (medido). Con eso
        # Whisper devuelve texto VACIO: no transcribe mal, no oye nada.
        pico = float(np.abs(audio).max())
        if pico > 0:
            audio = audio * min(GANANCIA_MAX, 0.9 / pico)
        segmentos, _ = modelo.transcribe(
            audio, language=self.idioma or None,
            beam_size=1,  # en CPU, beam mayor cuesta el doble y aporta poco
            vad_filter=False,  # ya cortamos por silencio nosotros
            condition_on_previous_text=False,  # evita bucles de repeticion
            initial_prompt=contexto or None,
        )
        return " ".join(s.text.strip() for s in segmentos).strip()


def elegir_motores(preferencia: str, modelo_local: str, idioma: str):
    """Devuelve (motor_principal, motor_respaldo, explicacion)."""
    local = MotorLocal(modelo_local, idioma)
    if preferencia == "local":
        return local, None, "forzado a local por --motor local"

    clave = leer_clave_groq()
    if not clave:
        if preferencia == "groq":
            return None, None, f"falta la clave: pone una en {GROQ_KEY_FILE}"
        return local, None, f"sin clave de Groq ({GROQ_KEY_FILE} no existe) → local"

    groq = MotorGroq(clave, idioma)
    if preferencia == "groq":
        return groq, None, "forzado a Groq por --motor groq"
    return groq, local, "Groq (whisper-large-v3-turbo), con local de respaldo"


# ════════════════════════════════════════════════════════════════════════════
# El daemon
# ════════════════════════════════════════════════════════════════════════════

class Transcriptor:
    def __init__(self, materia, modelo, idioma, umbral=None, dispositivo=None,
                 silencio_max=AUTOSTOP_SILENCE_MIN, app=None, motor="auto"):
        self.materia = materia
        self.modelo_local = modelo
        self.idioma = idioma
        self.umbral_fijo = umbral  # None = adaptativo
        self.dispositivo = dispositivo
        self.silencio_max = silencio_max
        self.app = app
        self.preferencia_motor = motor

        self.inicio = time.time()
        self.parar = False
        self.motivo_parada = "pedido del usuario"
        self.cola: queue.Queue = queue.Queue()
        self.marcas: list[float] = []
        self.marcas_lock = threading.Lock()

        self.trozos_listos = 0
        self.descartados = 0  # alucinaciones filtradas
        self.palabras = 0
        self.fase = "arrancando"
        self.fuente_actual = None
        self.fuente_es_sink = False
        self.mudo_seguido = 0.0
        self.texto_previo = ""  # cola del texto, para contexto y para el solape
        self.usos = {"groq": 0, "local": 0, "error": 0}
        self.notif_id = None
        # Se resuelven en run(), pero se declaran aca para que guardar_estado()
        # nunca pueda explotar por un atributo que todavia no existe.
        self.motor_activo = "?"  # el que se eligio al arrancar
        self.motor_ultimo = "?"  # el que hizo el ultimo trozo DE VERDAD
        self.principal = None
        self.respaldo = None
        self.aviso_respaldo = False

        # Piso de ruido adaptativo
        self.historial = deque(maxlen=int(VENTANA_PISO_SEC / FRAME_SEC))
        self.piso = None
        self.umbral_cache = 0.0

        nombre = f"{datetime.now():%Y-%m-%d-%H%M}-{slug(materia)}.md"
        self.salida = resolver_destino(materia) / nombre
        self.captura: subprocess.Popen | None = None

    # ── Estado ─────────────────────────────────────────────────────────────
    def guardar_estado(self):
        write_state({
            "pid": os.getpid(),
            "fase": self.fase,
            "materia": self.materia,
            "inicio": self.inicio,
            "pendientes": self.cola.qsize(),
            "listos": self.trozos_listos,
            "palabras": self.palabras,
            "marcas": len(self.marcas),
            "mudo": round(self.mudo_seguido),
            "fuente": self.fuente_actual or "",
            "motor": self.motor_activo,  # el elegido al arrancar
            "motor_ultimo": self.motor_ultimo,  # el que hizo el ultimo trozo
            "usos": dict(self.usos),
            "cuota_audio": getattr(self.principal, "cuota_audio", None),
            "salida": str(self.salida),
        })

    # ── Senales ────────────────────────────────────────────────────────────
    def instalar_senales(self):
        signal.signal(signal.SIGUSR1, self._marcar)
        signal.signal(signal.SIGTERM, self._detener)
        signal.signal(signal.SIGINT, self._detener)

    def _marcar(self, *_):
        t = time.time() - self.inicio
        with self.marcas_lock:
            self.marcas.append(t)
        notify("Duda marcada", f"En el minuto {hhmmss(t)}")

    def _detener(self, *_):
        self.parar = True

    # ── Umbral adaptativo ──────────────────────────────────────────────────
    def recalcular_umbral(self):
        """Estima el piso de ruido de ESTA fuente y pone el umbral encima.

        El piso baja al instante (un silencio real lo revela enseguida) pero
        sube como maximo 5% por segundo: asi un tramo largo hablando no lo
        arrastra hacia arriba hasta el punto de tomar la voz por silencio.
        """
        if len(self.historial) < int(3 / FRAME_SEC):
            # CALIBRANDO. Devolver 0 aca era un bug real: con umbral 0 todos
            # los frames contaban como VOZ, asi que un trozo de silencio puro
            # arrancaba con 3 s "hablados" (25% de un trozo de 12 s), superaba
            # el minimo del 8% y se mandaba igual — y Whisper devolvia
            # "Gracias. Gracias." sobre la nada. None = "todavia no se".
            self.umbral_cache = None
            return
        ordenados = sorted(self.historial)
        p10 = ordenados[len(ordenados) // 10]
        if self.piso is None:
            self.piso = p10
        else:
            self.piso = min(p10, self.piso * PISO_SUBIDA_MAX)
        self.umbral_cache = max(self.piso * PISO_MULTIPLICADOR, PISO_MINIMO)

    def umbral(self) -> float | None:
        """El umbral de voz, o None mientras se calibra (no se sabe todavia)."""
        return self.umbral_fijo if self.umbral_fijo is not None else self.umbral_cache

    # ── Archivo de salida ──────────────────────────────────────────────────
    def escribir_cabecera(self):
        self.salida.write_text(
            f"# {self.materia} — {datetime.now():%d/%m/%Y %H:%M}\n\n"
            f"> Transcripcion automatica del audio del sistema.\n"
            f"> Motor: `{self.motor_activo}` · idioma: `{self.idioma}`.\n"
            f"> Las marcas ⚠️ son los puntos donde no entendiste en vivo.\n\n"
            f"---\n\n"
        )

    def escribir_trozo(self, inicio_s: float, fin_s: float, texto: str):
        # Una frase por linea y SIN lineas en blanco entre trozos: la marca de
        # tiempo en negrita ya senala donde empieza cada uno, asi que el
        # renglon vacio solo gastaba pantalla.
        lineas = en_frases(texto)
        with self.salida.open("a") as f:
            f.write(f"**[{hhmmss(inicio_s)}]** {lineas[0] if lineas else texto}\n")
            for linea in lineas[1:]:
                f.write(linea + "\n")
            with self.marcas_lock:
                vencidas = [m for m in self.marcas if m <= fin_s]
                self.marcas = [m for m in self.marcas if m > fin_s]
            for m in vencidas:
                f.write(f"> ⚠️ **DUDA** — no entendi esto (marcado en {hhmmss(m)})\n")

    def escribir_cierre(self):
        dur = time.time() - self.inicio
        with self.salida.open("a") as f:
            with self.marcas_lock:
                sobrantes = list(self.marcas)
            for m in sobrantes:
                f.write(f"> ⚠️ **DUDA** — no entendi esto (marcado en {hhmmss(m)})\n")
            detalle = f"{self.usos['groq']} por Groq, {self.usos['local']} locales"
            if self.descartados:
                detalle += f", {self.descartados} descartados por silencio"
            if self.usos["error"]:
                detalle += f", {self.usos['error']} con error"
            minutos_groq = getattr(self.principal, "segundos_enviados", 0) / 60
            f.write(
                f"---\n\n"
                f"_Duracion: {hhmmss(dur)} · {self.trozos_listos} trozos "
                f"({detalle}) · ~{self.palabras} palabras · "
                f"{minutos_groq:.1f} min de audio enviados a Groq · "
                f"fin: {self.motivo_parada}._\n"
            )

    # ── Aviso permanente ───────────────────────────────────────────────────
    def texto_aviso(self) -> tuple[str, str]:
        transcurrido = hhmmss(time.time() - self.inicio)
        pendientes = self.cola.qsize()
        cuerpo = f"{self.materia} — {transcurrido}"
        if pendientes:
            cuerpo += f" · {pendientes} en cola"
        if self.mudo_seguido >= 60:
            restante = self.silencio_max - self.mudo_seguido / 60
            cuerpo += (f"\nEn silencio hace {int(self.mudo_seguido // 60)} min"
                       f" (corta solo en {int(restante)})")
        motor = describir_motor(self.motor_activo, self.motor_ultimo, self.usos)
        cuerpo += f"\nFuente: {self.fuente_actual}\nMotor: {motor}"
        return "⏺ Transcribiendo", cuerpo

    def hilo_aviso(self):
        """Mantiene el aviso al dia y lo hace REAPARECER cada tanto.

        Dos ritmos distintos a proposito:
        - cada 15 s se actualiza el texto (silencioso): si abris el centro de
          notificaciones, lo que dice es verdad.
        - cada RECORDATORIO_MIN se cierra y se crea de nuevo, que es lo unico
          que vuelve a mostrar el cartel en pantalla. Ese es el recordatorio
          de "segui grabando", el que evita que te lo olvides prendido.
        """
        # Si run() ya mostro el aviso de arranque, se adopta ESE en vez de
        # crear otro: si no, arrancar deja dos carteles diciendo lo mismo.
        ultimo_popup = time.time() if self.notif_id else 0.0
        while not self.parar:
            if time.time() - ultimo_popup >= RECORDATORIO_MIN * 60:
                if self.notif_id:
                    cerrar_notificacion(self.notif_id)
                self.notif_id = None  # sin id -> se crea nueva -> aparece
                ultimo_popup = time.time()

            titulo, cuerpo = self.texto_aviso()
            self.notif_id = notify(titulo, cuerpo, fija=True,
                                   reemplazar=self.notif_id)
            if self.notif_id:
                notif_file().write_text(str(self.notif_id))

            for _ in range(REFRESCO_AVISO_SEC):
                if self.parar:
                    return
                time.sleep(1)

    # ── Worker ─────────────────────────────────────────────────────────────
    def transcribir_trozo(self, pcm: bytes) -> str:
        """Manda el trozo al motor principal; si falla, al de respaldo."""
        contexto = self.texto_previo[-PROMPT_CONTEXTO_CHARS:]
        try:
            texto = self.principal.transcribir(pcm, contexto)
            self.usos[self.principal.nombre] += 1
            # Se registra el motor que REALMENTE hizo el trozo, no el que se
            # eligio al arrancar: si Groq se cae a mitad de clase y seguimos en
            # local, el aviso tiene que decir la verdad.
            self.motor_ultimo = self.principal.nombre
            return texto
        except Exception as e:
            if not self.respaldo:
                self.usos["error"] += 1
                return f"_[error de transcripcion: {e}]_"
            # Se avisa UNA sola vez: si se cayo la red, no queremos una
            # notificacion por trozo durante dos horas.
            if not self.aviso_respaldo:
                self.aviso_respaldo = True
                notify("Groq falló — sigo en local",
                       f"{e}\nLa transcripcion continua, con menos calidad.",
                       "critical")
            try:
                texto = self.respaldo.transcribir(pcm, contexto)
                self.usos[self.respaldo.nombre] += 1
                self.motor_ultimo = self.respaldo.nombre
                return texto
            except Exception as e2:
                self.usos["error"] += 1
                return f"_[error de transcripcion: {e2}]_"

    def worker(self):
        while True:
            item = self.cola.get()
            if item is None:
                break
            inicio_s, fin_s, pcm = item

            texto = self.transcribir_trozo(pcm)
            if es_alucinacion(texto):
                # Relleno sobre silencio: no se escribe. Cuenta como trozo
                # hecho igual, para que los numeros del pie no mientan.
                self.trozos_listos += 1
                self.descartados += 1
                self.guardar_estado()
                continue
            # Los trozos se solapan a proposito: hay que quitar lo repetido.
            texto = quitar_solape(self.texto_previo, texto)

            if texto:
                self.escribir_trozo(inicio_s, fin_s, texto)
                self.palabras += len(texto.split())
                self.texto_previo = (self.texto_previo + " " + texto)[-1000:]
            self.trozos_listos += 1
            self.guardar_estado()

    # ── Captura ────────────────────────────────────────────────────────────
    def fuente_deseada(self) -> str | None:
        """De donde HAY que capturar ahora mismo, VALIDADO.

        Prioridad: app pedida a mano > fuente fija > app detectada sola >
        monitor del sink. Vive en un solo metodo para que el chequeo periodico
        compare contra la MISMA logica.

        Todo candidato se valida contra la lista blanca de salidas. Si el
        destino elegido ya no existe (la app cerro su stream), NO se devuelve
        igual: eso hacia que pw-record se enganchara al MICROFONO por defecto y
        grabara la voz del usuario. Antes de eso, se cae al monitor; y si no
        hay ni monitor, se devuelve None y la grabacion se detiene.
        """
        apps, sinks = fuentes_de_salida()

        def elegir_sink():
            porDefecto = sink_por_defecto()
            if porDefecto in sinks:
                return (porDefecto, True)
            return (next(iter(sinks)), True) if sinks else None

        for candidata in (self.app, self.dispositivo):
            if candidata:
                # Una fuente pedida a mano se respeta solo si SIGUE existiendo.
                if candidata in apps:
                    return (candidata, False)
                if candidata in sinks:
                    return (candidata, True)
                return elegir_sink()

        if len(apps) == 1:
            return (apps[0], False)
        return elegir_sink()

    def abrir_captura(self):
        elegida = self.fuente_deseada()
        if elegida is None:
            # Sin destino seguro NO se graba. Capturar "lo que haya" es
            # exactamente como se termina grabando el microfono sin enterarse.
            raise RuntimeError("no hay ninguna salida de audio capturable")
        fuente, es_sink = elegida

        if (fuente, es_sink) != (self.fuente_actual, self.fuente_es_sink):
            # Fuente nueva = piso de ruido completamente distinto (medido:
            # 121 en el stream de una app, 12 por el monitor). Recalibrar.
            self.historial.clear()
            self.piso = None
        self.fuente_actual, self.fuente_es_sink = fuente, es_sink

        cmd = ["pw-record"]
        if es_sink:
            # ESTA propiedad es la que captura la SALIDA de un sink. Sin ella,
            # `--target <sink>` (con o sin el sufijo .monitor de PulseAudio) se
            # engancha al microfono por defecto sin decir nada. Verificado con
            # `pw-link -l`: es la unica de las tres formas que queda enlazada a
            # `<sink>:monitor_*` en vez de a `bluez_input:capture_*`.
            cmd += ["-P", "{ stream.capture.sink=true }"]
        cmd += ["--target", fuente, "--rate", str(RATE),
                "--channels", str(CHANNELS), "--format", "s16", "--raw", "-"]

        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL)
        self.comprobar_no_microfono(proc, fuente)
        return proc

    def comprobar_no_microfono(self, proc, fuente: str) -> None:
        """Verifica con PipeWire de donde entra el audio DE VERDAD.

        Pedir un destino no garantiza nada: pw-record no falla cuando no
        existe, se cuelga de la fuente por defecto. Asi terminamos grabando el
        microfono del usuario sin que nadie se enterara. Esta comprobacion es
        la que faltaba: si el origen real no es el monitor de un sink ni el
        stream que pedimos, se corta todo en el acto.
        """
        time.sleep(1.0)  # darle tiempo a PipeWire a armar el enlace
        origenes = origenes_reales()
        if not origenes:
            return  # sin datos no se puede afirmar nada; el nivel lo delatara
        seguro = all(":monitor" in o or o.startswith(fuente + ":") for o in origenes)
        if not seguro:
            proc.kill()
            raise RuntimeError(
                "PipeWire enlazo la captura a algo que no es una salida "
                f"({', '.join(origenes)}) — corto para no grabar el microfono")

    def encolar(self, inicio_s, fin_s, buf, voz, total, niveles):
        """Encola el trozo salvo que sea silencio.

        Ese filtro no es un lujo: Whisper ALUCINA sobre silencio (te escribe
        "Gracias. Gracias.", "Subtitulos por la comunidad", o "no, no, no..."
        cien veces). Y con Groq, ademas, mandar silencio gasta cuota al pedo.

        DOS candados, porque uno solo ya nos fallo dos veces:
        1. el p90 del propio trozo contra un piso absoluto — la medida que de
           verdad separa silencio de voz, y que no se deja enganar por picos
           sueltos como si se dejaba el maximo, y
        2. la proporcion de frames por encima del umbral adaptativo.
        """
        if niveles:
            p90 = sorted(niveles)[int(len(niveles) * 0.9)]
            if p90 < P90_MINIMO_CHUNK:
                return
        if total and voz / total >= VOICE_RATIO_MIN:
            self.cola.put((inicio_s, fin_s, bytes(buf)))
            self.guardar_estado()

    # ── Bucle principal ────────────────────────────────────────────────────
    def run(self):
        self.instalar_senales()
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        cerrar_aviso_huerfano()

        self.principal, self.respaldo, explicacion = elegir_motores(
            self.preferencia_motor, self.modelo_local, self.idioma)
        self.aviso_respaldo = False
        if self.principal is None:
            notify("No hay motor de transcripcion", explicacion, "critical")
            print(explicacion, file=sys.stderr)
            return
        self.motor_activo = self.principal.nombre

        self.fase = "grabando"
        self.guardar_estado()
        self.escribir_cabecera()

        hilo_worker = threading.Thread(target=self.worker, daemon=True)
        hilo_worker.start()

        try:
            self.captura = self.abrir_captura()
        except RuntimeError as e:
            notify("No se puede grabar", f"{e}.\nPone algo a sonar y volve a intentar.",
                   "critical")
            print(e, file=sys.stderr)
            state_file().unlink(missing_ok=True)
            return
        self.guardar_estado()  # recien aca se conoce la fuente: hay que republicar
        # La fuente y el motor se DICEN al arrancar: si detecto mal, tenes que
        # poder notarlo ahora y no al final, con el archivo lleno de basura.
        self.notif_id = notify(
            "⏺ Transcribiendo",
            f"{self.materia}\nFuente: {self.fuente_actual}\n"
            f"Motor: {explicacion}\n→ {self.salida.parent}", fija=True)
        threading.Thread(target=self.hilo_aviso, daemon=True).start()

        buf = bytearray()
        voz = total = 0
        niveles_chunk = []
        silencio_seguido = 0.0
        t0 = 0.0
        reintentos = 0
        frames_desde_chequeo = 0
        frames_desde_umbral = 0

        while not self.parar:
            # ── Seguir la fuente si cambia ─────────────────────────────────
            # Enchufar auriculares NO mata a pw-record: sigue capturando la
            # fuente vieja, que ahora esta muda. Sin este chequeo la clase se
            # graba en silencio y uno se entera al final.
            # El chequeo corre SIEMPRE, tambien con --app o --dispositivo: si
            # esa fuente desaparece hay que enterarse, porque pw-record no
            # avisa — se cuelga del microfono por defecto y sigue como si nada.
            frames_desde_chequeo += 1
            if frames_desde_chequeo >= CHECK_FUENTE_FRAMES:
                frames_desde_chequeo = 0
                try:
                    nueva = self.fuente_deseada()
                except (subprocess.SubprocessError, OSError):
                    nueva = self.fuente_actual
                if nueva is None:
                    self.motivo_parada = "se quedo sin ninguna salida de audio capturable"
                    notify("Sin salida de audio", "Corto para no grabar el microfono",
                           "critical")
                    break
                if nueva != (self.fuente_actual, self.fuente_es_sink):
                    notify("Fuente de audio cambiada", f"Siguiendo: {nueva[0]}")
                    self.captura.kill()
                    try:
                        self.captura = self.abrir_captura()
                    except RuntimeError as e:
                        self.motivo_parada = str(e)
                        notify("Captura insegura", str(e), "critical")
                        break
                    continue

            frame = self.captura.stdout.read(FRAME_BYTES)
            if len(frame) < FRAME_BYTES:  # se corto la captura
                if self.parar or reintentos >= 3:
                    self.motivo_parada = "se corto la captura de audio"
                    break
                reintentos += 1
                notify("Reconectando audio", f"Intento {reintentos}/3", "critical")
                time.sleep(1)
                self.captura.kill()
                try:
                    self.captura = self.abrir_captura()
                except RuntimeError as e:
                    self.motivo_parada = str(e)
                    break
                continue

            nivel = rms(frame)
            self.historial.append(nivel)
            frames_desde_umbral += 1
            if frames_desde_umbral >= int(1 / FRAME_SEC):  # ~1 vez por segundo
                frames_desde_umbral = 0
                self.recalcular_umbral()

            buf += frame
            niveles_chunk.append(nivel)
            u = self.umbral()
            if u is None:
                # Calibrando: el audio se guarda, pero este frame no vota ni
                # como voz ni como silencio. Contarlo seria inventar.
                silencio_seguido += FRAME_SEC
                self.mudo_seguido += FRAME_SEC
            else:
                total += 1
                if nivel >= u:
                    voz += 1
                    silencio_seguido = 0.0
                    self.mudo_seguido = 0.0
                else:
                    silencio_seguido += FRAME_SEC
                    self.mudo_seguido += FRAME_SEC

            dur = len(buf) / BYTES_PER_SEC
            corta_por_silencio = (dur >= MIN_CHUNK_SEC
                                  and silencio_seguido >= SILENCE_CUT_SEC)
            if corta_por_silencio or dur >= MAX_CHUNK_SEC:
                self.encolar(t0, t0 + dur, buf, voz, total, niveles_chunk)
                # SOLAPAMIENTO: el trozo siguiente arranca con los ultimos 2 s
                # del anterior, para que ninguna palabra quede partida por el
                # corte. El texto repetido lo saca quitar_solape().
                cola_bytes = int(OVERLAP_SEC * BYTES_PER_SEC)
                resto = bytes(buf[-cola_bytes:]) if len(buf) > cola_bytes else b""
                t0 += dur - (len(resto) / BYTES_PER_SEC)
                buf = bytearray(resto)
                voz = total = 0
                niveles_chunk = []
                silencio_seguido = 0.0

            if self.mudo_seguido >= self.silencio_max * 60:
                self.motivo_parada = (f"auto-apagado por {self.silencio_max} min "
                                      f"de silencio")
                self.parar = True

        # ── Cierre ordenado ────────────────────────────────────────────────
        self.fase = "terminando"
        self.guardar_estado()
        if self.captura:
            self.captura.terminate()
        if len(buf) / BYTES_PER_SEC >= 1.0:
            self.encolar(t0, t0 + len(buf) / BYTES_PER_SEC, buf, voz, total, niveles_chunk)

        pendientes = self.cola.qsize()
        if pendientes:
            notify("Terminando", f"Faltan {pendientes} trozos por transcribir...")
        self.cola.put(None)
        hilo_worker.join()

        self.escribir_cierre()
        state_file().unlink(missing_ok=True)
        if self.notif_id:
            cerrar_notificacion(self.notif_id)
        notif_file().unlink(missing_ok=True)
        notify("⏹ Transcripcion lista",
               f"{self.salida.name} · ~{self.palabras} palabras\n{self.motivo_parada}")
        print(self.salida)


# ════════════════════════════════════════════════════════════════════════════
# Subcomandos
# ════════════════════════════════════════════════════════════════════════════

def cmd_materia(args) -> int:
    if not args.nombre:
        actual = leer_materia()
        if not actual:
            print("no hay materia fijada — usa: transcriptor materia <nombre>")
            return 1
        print(f"{actual}  →  {resolver_destino(actual, crear=False)}")
        return 0
    guardar_materia(args.nombre)
    destino = resolver_destino(args.nombre, crear=False)
    if not (Path.home() / "Proyectos" / args.nombre).is_dir():
        print(f"ojo: no existe ~/Proyectos/{args.nombre} — ira a {destino}")
    print(f"materia activa: {args.nombre}")
    print(f"se guardara en: {destino}")
    return 0


def cmd_elegir(_args) -> int:
    opciones = proyectos_disponibles()
    if not opciones:
        notify("No hay proyectos", f"No encontre carpetas en ~/Proyectos", "critical")
        return 1
    try:
        r = subprocess.run(["fuzzel", "--dmenu", "--prompt", "Materia a transcribir: "],
                           input="\n".join(opciones), capture_output=True,
                           text=True, check=False)
    except FileNotFoundError:
        print("falta fuzzel", file=sys.stderr)
        return 1
    elegida = r.stdout.strip()
    if not elegida:
        return 1  # cancelaste: no se toca nada
    guardar_materia(elegida)
    notify("Materia activa", f"{elegida}\n→ {resolver_destino(elegida, crear=False)}")
    print(elegida)
    return 0


def cmd_donde(args) -> int:
    proyecto = Path.home() / "Proyectos" / args.materia
    destino = resolver_destino(args.materia, crear=False)
    if proyecto.is_dir():
        print(f"proyecto de estudio encontrado: {proyecto}")
    else:
        print(f"NO existe {proyecto} — revisa el nombre (igual a la carpeta)")
    print(f"la transcripcion caeria en: {destino}/"
          f"{datetime.now():%Y-%m-%d-%H%M}-{slug(args.materia)}.md")
    return 0


def probar_groq(clave: str) -> tuple[int, list[str]]:
    """Valida la clave contra Groq sin gastar audio.

    Pregunta por la lista de modelos: si responde 200, la clave sirve. Es la
    forma barata de contestar "¿esta vencida?" sin mandar un solo segundo de
    grabacion.
    """
    r = subprocess.run(
        ["curl", "--silent", "--max-time", "20",
         "--url", "https://api.groq.com/openai/v1/models",
         "--header", f"Authorization: Bearer {clave}",
         "--write-out", "\n%{http_code}"],
        capture_output=True, text=True, check=False,
    )
    cuerpo, _, codigo = r.stdout.rpartition("\n")
    try:
        http = int(codigo.strip())
    except ValueError:
        return 0, []
    modelos = []
    if http == 200:
        try:
            modelos = [m["id"] for m in json.loads(cuerpo).get("data", [])
                       if "whisper" in m["id"]]
        except ValueError:
            pass
    return http, modelos


def cmd_motor(args) -> int:
    principal, respaldo, explicacion = elegir_motores(
        args.motor, args.modelo, args.idioma)
    print(explicacion)
    if principal:
        print(f"principal: {principal.nombre}"
              + (f" ({GROQ_MODELO})" if principal.nombre == "groq" else ""))
        print(f"respaldo:  {respaldo.nombre if respaldo else 'ninguno'}")

    if args.probar:
        clave = leer_clave_groq()
        if not clave:
            print("no hay clave que probar")
            return 1
        http, modelos = probar_groq(clave)
        if http == 200:
            print(f"clave OK (HTTP 200) · modelos whisper: {', '.join(modelos)}")
            if GROQ_MODELO not in modelos:
                print(f"OJO: {GROQ_MODELO} no aparece en tu cuenta")
                return 1
        elif http == 401:
            print("clave INVALIDA o revocada (HTTP 401)")
            return 1
        elif http == 0:
            print("sin conexion a internet")
            return 1
        else:
            print(f"respuesta inesperada de Groq: HTTP {http}")
            return 1
    return 0 if principal else 1


def cmd_iniciar(args) -> int:
    anterior = read_state()
    if anterior:
        if anterior["fase"] == "terminando":
            notify("Esperá un momento",
                   f"Todavia cierra la anterior ({anterior['pendientes']} trozos)")
            print("la anterior sigue vaciando su cola", file=sys.stderr)
        else:
            notify("Ya estaba grabando", "Usa 'transcriptor detener' para cortar")
            print("ya hay una transcripcion en curso", file=sys.stderr)
        return 1

    materia = args.materia or leer_materia()
    if not materia:
        notify("No hay materia fijada",
               "Elegí una con el atajo del menú, o: transcriptor materia <nombre>",
               "critical")
        print("no hay materia fijada", file=sys.stderr)
        return 1

    venv_python = DATA_DIR / "venv/bin/python"
    interprete = str(venv_python) if venv_python.exists() else sys.executable

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    log = LOG_FILE.open("a")
    # start_new_session lo desprende de esta terminal: sobrevive al cierre
    subprocess.Popen(
        [interprete, os.path.abspath(__file__), "_daemon", materia,
         "--modelo", args.modelo, "--idioma", args.idioma,
         "--silencio-max", str(args.silencio_max), "--motor", args.motor]
        + (["--umbral", str(args.umbral)] if args.umbral is not None else [])
        + (["--dispositivo", args.dispositivo] if args.dispositivo else [])
        + (["--app", args.app] if args.app else []),
        stdout=log, stderr=log, start_new_session=True,
    )

    for _ in range(60):  # hasta 6 s a que el daemon publique su estado
        time.sleep(0.1)
        estado = read_state()
        if estado:
            print(f"grabando: {materia}")
            print(f"fuente: {estado.get('fuente') or '(resolviendo)'}"
                  f" · motor: {estado.get('motor')}")
            print(f"se guarda en: {estado['salida']}")
            return 0
    print(f"el daemon no arranco — revisa {LOG_FILE}", file=sys.stderr)
    return 1


def cmd_detener(_args) -> int:
    estado = read_state()
    if not estado:
        notify("No habia nada grabando")
        print("no hay transcripcion en curso", file=sys.stderr)
        return 1
    os.kill(estado["pid"], signal.SIGTERM)
    print("deteniendo (falta vaciar la cola)...")
    return 0


def cmd_alternar(args) -> int:
    return cmd_detener(args) if read_state() else cmd_iniciar(args)


def cmd_marcar(_args) -> int:
    estado = read_state()
    if not estado:
        notify("No hay nada grabando", "No se puede marcar una duda")
        return 1
    os.kill(estado["pid"], signal.SIGUSR1)
    return 0


def cmd_estado(args) -> int:
    estado = read_state()
    if args.json:
        print(json.dumps(estado or {"fase": "apagado"}))
        return 0
    if not estado:
        print("○ apagado")
        return 1

    transcurrido = hhmmss(time.time() - estado["inicio"])
    pendientes = estado["pendientes"]
    if estado["fase"] == "terminando":
        print(f"⏳ vaciando la cola · faltan {pendientes} trozos — no cierres todavia")
    else:
        atraso = f" ({pendientes} en cola)" if pendientes else ""
        mudo = estado.get("mudo", 0)
        silencio = f" · en silencio hace {int(mudo // 60)} min" if mudo >= 60 else ""
        print(f"⏺ {transcurrido} · {estado['materia']}{atraso}{silencio}")
    if sys.stdout.isatty():
        motor = describir_motor(estado.get("motor", "?"),
                                estado.get("motor_ultimo", "?"),
                                estado.get("usos", {}))
        print(f"  fuente: {estado.get('fuente')}")
        print(f"  motor:  {motor}")
        cuota = estado.get("cuota_audio")
        if cuota is not None:
            print(f"  cuota Groq: {cuota // 60} min de audio disponibles ahora")
        print(f"  → {estado['salida']}")
    return 0


def cmd_descargar_modelo(args) -> int:
    from faster_whisper import WhisperModel
    print(f"bajando el modelo local de respaldo '{args.modelo}'...")
    WhisperModel(args.modelo, device="cpu", compute_type="int8",
                 download_root=str(MODELS_DIR))
    print(f"listo, guardado en {MODELS_DIR}")
    return 0


def cmd_daemon(args) -> int:
    Transcriptor(args.materia, args.modelo, args.idioma, args.umbral,
                 args.dispositivo, args.silencio_max, args.app, args.motor).run()
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="Transcriptor de audio del sistema")
    sub = p.add_subparsers(dest="cmd", required=True)

    def con_opciones(sp):
        sp.add_argument("--modelo", default="small",
                        help="modelo LOCAL de respaldo (default: small)")
        sp.add_argument("--idioma", default="es", help="codigo ISO (default: es)")
        sp.add_argument("--motor", default="auto", choices=["auto", "groq", "local"],
                        help="auto = Groq con local de respaldo (default)")
        sp.add_argument("--umbral", type=float, default=None,
                        help="fija el umbral de voz (default: adaptativo)")
        sp.add_argument("--dispositivo", default=None,
                        help="fuente de PipeWire fija (desactiva el seguimiento)")
        sp.add_argument("--app", default=None,
                        help="capturar el stream de una app concreta (ej: Brave)")
        sp.add_argument("--silencio-max", type=int, default=AUTOSTOP_SILENCE_MIN,
                        dest="silencio_max",
                        help=f"min de silencio antes de apagarse (default: {AUTOSTOP_SILENCE_MIN})")
        return sp

    con_opciones(sub.add_parser("iniciar")).add_argument("materia", nargs="?")
    con_opciones(sub.add_parser("alternar")).add_argument("materia", nargs="?")
    con_opciones(sub.add_parser("_daemon")).add_argument("materia")
    con_opciones(sub.add_parser("motor")).add_argument(
        "--probar", action="store_true",
        help="valida la clave contra Groq (no gasta audio)")
    sub.add_parser("detener")
    sub.add_parser("marcar")
    sub.add_parser("elegir")
    sub.add_parser("estado").add_argument("--json", action="store_true")
    sub.add_parser("donde").add_argument("materia")
    sub.add_parser("materia").add_argument("nombre", nargs="?")
    sub.add_parser("descargar-modelo").add_argument("--modelo", default="small")

    args = p.parse_args()
    return {
        "iniciar": cmd_iniciar, "alternar": cmd_alternar, "detener": cmd_detener,
        "marcar": cmd_marcar, "estado": cmd_estado, "donde": cmd_donde,
        "materia": cmd_materia, "elegir": cmd_elegir, "motor": cmd_motor,
        "descargar-modelo": cmd_descargar_modelo, "_daemon": cmd_daemon,
    }[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
