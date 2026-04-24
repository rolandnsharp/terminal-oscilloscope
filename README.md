# terminal-oscilloscope

A terminal-based oscilloscope with CRT phosphor physics, written in Nim. Zero dependencies — 200KB binary, just libc.

## Braille renderer (amber palette)

![braille demo](braille_demo.gif)

## Half-block renderer

![demo](demo.gif)

## Features

- **CRT boot/shutdown animations** — phosphor ramp, beam sweep, vertical collapse, dot fade
- **Y-T and X-Y modes** — time-domain waveform or Lissajous figures
- **Phosphor persistence** — beam bloom, decay trails, intensity-based shading
- **Two renderers** — half-block (`▀▄█`) or braille dots for 4× resolution
- **Live audio capture** — direct libav bindings via dlopen, zero install
- **Threaded audio** — 60fps rendering, audio capture on separate thread
- **6 CRT phosphor palettes** — green, amber, cyan, blue, white, red

## Install

Requires [Nim](https://nim-lang.org/) 2.x.

```bash
git clone https://github.com/rolandnsharp/terminal-oscilloscope.git
cd terminal-oscilloscope
```

**Half-block version** (chunky CRT look):
```bash
nim c -d:release --threads:on -o:osc src/osc.nim
./osc
```

**Braille version** (high-resolution dots):
```bash
nim c -d:release --threads:on -o:osc_braille src/osc_braille.nim
./osc_braille
```

**Install globally:**
```bash
sudo ln -s $(pwd)/osc /usr/local/bin/osc
```

## Controls

| Key | Action |
|-----|--------|
| `m` | Toggle Y-T / X-Y mode |
| `+` / `-` | Increase / decrease gain (amplitude) |
| `]` / `[` | Zoom in / out time axis |
| `q` | Quit (with CRT shutdown effect) |

## Configuration

Runtime options can be passed via CLI flags:

```bash
./osc --palette:amber --decay:0.92 --beam:0.6 --bloom:0.12
./osc_braille --palette:green --hot:0.8 --warm:0.45 --cool:0.12
```

Available options:

| Option | Description | Default |
|--------|-------------|---------|
| `-p`, `--palette:NAME` | Palette name | `green` |
| `-d`, `--decay:FLOAT` | Phosphor persistence per frame | `0.85` |
| `--beam:FLOAT` | Beam impact intensity | `0.4` |
| `--bloom:FLOAT` | Horizontal glow spread | `0.08` |
| `--hot:FLOAT` | White-hot beam core threshold | `0.7` |
| `--warm:FLOAT` | Bright phosphor threshold | `0.4` |
| `--cool:FLOAT` | Dim persistence trail threshold | `0.15` |

Show help:

```bash
./osc --help
./osc_braille --help
```

### Palettes

| Name | Phosphor | Look |
|------|----------|------|
| `green` | P31 | classic oscilloscope |
| `amber` | P12 | warm retro terminal |
| `cyan` | P7 | Tektronix blue-green |
| `blue` | P11 | cool/modern |
| `white` | P4 | TV phosphor |
| `red` | P22-R | radar display |

## Audio

Captures system audio by opening the PulseAudio/PipeWire monitor of your default output sink directly via libavformat and libavdevice. Libraries are loaded at runtime with `dlopen` — no dev packages, no subprocess, no extra dependencies.

## Credits

CRT turn-on/off animations inspired by [AetherTune](https://github.com/nevermore23274/AetherTune).
