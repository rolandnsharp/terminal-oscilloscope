## Terminal oscilloscope — braille dot rendering (4× resolution).

import os, strutils, parseopt
import posix/termios as ptermios
from posix import read
import osc/canvas/[braille, term, effects]
import osc/[scope, audio]

# ── Configuration ────────────────────────────────────────────────────

type Config = object
  decay: float
  beam: float
  bloom: float
  hotGlow: float
  warmGlow: float
  coolGlow: float
  palette: string

proc defaultConfig(): Config =
  Config(
    decay: 0.85,
    beam: 0.4,
    bloom: 0.08,
    hotGlow: 0.7,
    warmGlow: 0.4,
    coolGlow: 0.15,
    palette: "green"
  )

proc usage() =
  echo """
Terminal oscilloscope

Options:
  -p, --palette:NAME   Palette name, default: green
  -d, --decay:FLOAT    Phosphor decay, default: 0.85
      --beam:FLOAT     Beam intensity, default: 0.4
      --bloom:FLOAT    Bloom intensity, default: 0.08
      --hot:FLOAT      Hot glow, default: 0.7
      --warm:FLOAT     Warm glow, default: 0.4
      --cool:FLOAT     Cool glow, default: 0.15
  -h, --help           Show this help

Example:
  ./osc_braille --palette:amber --decay:0.92 --beam:0.6 --bloom:0.12
"""

proc parseConfig(): Config =
  result = defaultConfig()

  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "h", "help":
        usage()
        quit 0
      of "palette", "p":
        result.palette = val
      of "decay", "d":
        result.decay = parseFloat(val)
      of "beam":
        result.beam = parseFloat(val)
      of "bloom":
        result.bloom = parseFloat(val)
      of "hot":
        result.hotGlow = parseFloat(val)
      of "warm":
        result.warmGlow = parseFloat(val)
      of "cool":
        result.coolGlow = parseFloat(val)
      else:
        quit "Unknown option: " & key
    else:
      discard

# ── Audio thread ─────────────────────────────────────────────────────

type AudioFrame = object
  samples: array[4096, array[2, float]]
  count: int

var
  audioChan: Channel[AudioFrame]
  audioRunning: bool

proc audioThread(aud: ptr AudioCapture) {.thread.} =
  var scope = initScope(1, 1)
  while audioRunning:
    aud[].readSamples(scope)
    if scope.sampleCount > 0:
      var frame: AudioFrame
      frame.count = min(scope.sampleCount, 4096)
      for i in 0..<frame.count:
        frame.samples[i] = [scope.samplesL[i], scope.samplesR[i]]
      audioChan.send(frame)

# ── Input ────────────────────────────────────────────────────────────

var savedTermios: ptermios.Termios

proc setRawMode() =
  discard tcGetAttr(0.cint, addr savedTermios)
  var raw = savedTermios
  raw.c_lflag = raw.c_lflag and not (ECHO or ICANON)
  raw.c_cc[VMIN] = 0.char
  raw.c_cc[VTIME] = 0.char
  discard tcSetAttr(0.cint, TCSANOW, addr raw)

proc restoreMode() =
  discard tcSetAttr(0.cint, TCSANOW, addr savedTermios)

proc readKey(): char =
  var ch: char
  if read(0.cint, addr ch, 1) == 1: ch else: '\0'

# ── Phosphor ─────────────────────────────────────────────────────────

proc plotDot(c: var BrailleCanvas, fx, fy: float, cfg: Config) =
  let x = int(fx)
  let y = int(fy)
  c.addPixel(x, y, cfg.beam)
  c.addPixel(x - 1, y, cfg.bloom)
  c.addPixel(x + 1, y, cfg.bloom)

proc plotLine(
  c: var BrailleCanvas,
  x0, y0, x1, y1: float,
  cfg: Config
) =
  let steps = max(int(max(abs(x1 - x0), abs(y1 - y0))), 1)
  for i in 0..steps:
    let t = i.float / steps.float
    c.plotDot(
      x0 + (x1 - x0) * t,
      y0 + (y1 - y0) * t,
      cfg
    )

proc renderTrace(c: var BrailleCanvas, scope: Scope, cfg: Config) =
  if scope.sampleCount < 2:
    return

  let w = c.pixW
  let h = c.pixH
  let cy = h.float / 2.0
  let gain = scope.gain

  case scope.mode
  of ModeYT:
    let visible = max(int(scope.sampleCount.float / scope.timeDiv), 2)
    var px, py: float
    var first = true

    for col in 0..<w:
      let s = min((col * visible) div w, scope.sampleCount - 1)
      let x = col.float
      let y = cy - scope.samplesL[s] * gain * cy * 0.5

      if first:
        c.plotDot(x, y, cfg)
      else:
        c.plotLine(px, py, x, y, cfg)

      first = false
      px = x
      py = y

  of ModeXY:
    var px, py: float
    var first = true
    let step = max(scope.sampleCount div 1024, 1)

    for i in countup(0, scope.sampleCount - 1, step):
      let x = (1.0 + scope.samplesL[i] * gain * 0.5) * w.float / 2.0
      let y = (1.0 - scope.samplesR[i] * gain * 0.5) * h.float / 2.0

      if first:
        c.plotDot(x, y, cfg)
      else:
        c.plotLine(px, py, x, y, cfg)

      first = false
      px = x
      py = y

# ── Main ─────────────────────────────────────────────────────────────

proc main() =
  let cfg = parseConfig()

  initTerm()
  setRawMode()

  var w = termWidth()
  var h = termHeight()

  var hb = newCanvas(
    w,
    h,
    cfg.palette,
    [cfg.hotGlow, cfg.warmGlow, cfg.coolGlow]
  )

  crtTurnOn(hb)

  var c = newBrailleCanvas(
    w,
    h,
    cfg.palette,
    [cfg.hotGlow, cfg.warmGlow, cfg.coolGlow]
  )

  var scope = initScope(w, h)
  var aud = startAudio()
  var running = true

  audioChan.open()
  audioRunning = true

  var aThread: Thread[ptr AudioCapture]
  createThread(aThread, audioThread, addr aud)

  while running:
    let nw = termWidth()
    let nh = termHeight()

    if nw != w or nh != h:
      w = nw
      h = nh
      c.resize(w, h)
      scope.resize(w, h)

    let got = audioChan.tryRecv()

    if got.dataAvailable:
      scope.sampleCount = got.msg.count

      for i in 0..<got.msg.count:
        scope.samplesL[i] = got.msg.samples[i][0]
        scope.samplesR[i] = got.msg.samples[i][1]

    c.decayPixels(cfg.decay)
    c.renderTrace(scope, cfg)

    let hud =
      " " &
      (if scope.mode == ModeYT: "Y-T" else: "X-Y") &
      " G:" &
      scope.gain.formatFloat(ffDecimal, 1) &
      " "

    let help = " m:mode +/-:gain [/]:time q:quit "

    c.flush([
      (1, 0, tNormal, hud),
      (w - help.len - 1, h - 1, tDim, help)
    ])

    sleep(16)

    case readKey()
    of 'q', '\x1b':
      running = false
    of 'm':
      scope.mode =
        if scope.mode == ModeYT:
          ModeXY
        else:
          ModeYT
    of '+', '=':
      scope.gain = min(scope.gain * 1.3, 20.0)
    of '-':
      scope.gain = max(scope.gain / 1.3, 0.5)
    of ']':
      scope.timeDiv = min(scope.timeDiv * 1.5, 16.0)
    of '[':
      scope.timeDiv = max(scope.timeDiv / 1.5, 0.25)
    else:
      discard

  audioRunning = false
  joinThread(aThread)
  audioChan.close()

  aud.stop()
  crtTurnOff(hb)
  restoreMode()
  deinitTerm()

when isMainModule:
  main()
