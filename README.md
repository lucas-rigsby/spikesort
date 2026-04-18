# SpikeSort
**Real-Time LIF Spiking Neural Network Neural Spike Classifier on Basys-3 FPGA**

---

## Motivation

When an electrode is implanted in neural tissue, it picks up electrical activity
from multiple neurons simultaneously. Identifying which neuron fired a given spike, a problem called spike sorting, is fundamental to brain-computer interfaces, implantable neuroprosthetics, and intraoperative neural monitoring. Current
clinical hardware solves this in real time under extreme power and latency constraints, making it an ideal target for FPGA implementation.

This project implements a minimal but physically grounded spike sorter. A
breadboard circuit synthesizes two biologically realistic neuron waveforms:
a fast-spiking GABAergic interneuron and a slow-spiking glutamatergic pyramidal
cell. Signals are then classified in real time by a spiking neural network running on a Basys-3 FPGA.

---

## Theory: The Leaky Integrate-and-Fire (LIF) Model

The LIF model is the simplest biologically plausible neuron model that captures
the essential dynamics of spike generation. Each neuron maintains a membrane
potential $V$ that integrates incoming current and decays passively over time. 

When $V$ crosses a threshold, the neuron fires a spike and resets to zero. The
LEAK term approximates the continuous exponential decay of a real neuron membrane
between inputs. This makes LIF neurons naturally event-driven and sparse in their
computation, properties that map efficiently onto FPGA logic and mirror the
low-power characteristics of biological neural tissue.

The SNN in this project uses a 2 → 4 → 3 LIF architecture: two input neurons
encoding spike width and peak timing, four hidden LIF neurons, and three output
neurons corresponding to Neuron A, Neuron B, and Noise. Weights are trained
offline in PyTorch using snnTorch and exported as Q8 fixed-point constants hardcoded into the RTL.

---

## System Overview

The breadboard generates analog spike waveforms using RC networks with distinct time constants (τ = 10 µs for the interneuron, τ = 1 ms for the pyramidal cell), sums them through an op-amp, and thresholds the result into a clean digital pulse via a comparator. This digital signal enters the FPGA on a Pmod GPIO pin.

On the FPGA, the signal is first passed through a two flip-flop synchronizer to resolve metastability. A finite state machine then captures a fixed-length window around each spike, extracts two temporal features (spike width F1 and peak timing F2), and feeds them as rate-coded spike trains into the LIF network. The output layer's spike counts are integrated over a voting window and decoded into a final classification displayed on the 7-segment display.

---

## Repository Structure
```
spikesort/
├── data/         # waveform simulation and feature extraction
├── model/        # SNN definition and training (snnTorch)
├── export/       # Q8 weight conversion and Verilog export
└── rtl/          # synthesizable Verilog + XDC constraints
```

## Quickstart
```bash
pip install -r requirements.txt
python data/simulate_waveforms.py
python model/train_snn.py
python export/export_weights.py     # paste output into rtl/snn_core.v
```

# SpikeSort
**Real-Time Spiking Neural Network Neural Spike Classifier on FPGA**

---

## Project Overview

SpikeSort classifies neural spike waveforms in real time on a Basys-3 FPGA.
Two biologically meaningful neuron types are distinguished:

| Class | Neuron type | τ_d | Display |
|---|---|---|---|
| A | Fast-spiking GABAergic interneuron | 10 µs | `A` |
| B | Regular-spiking pyramidal cell | 1 ms | `b` |
| N | Background noise | — | `N` |

The analog front end uses RC integrator-differentiator networks to generate
synthetic multi-unit waveforms. The Basys-3 XADC digitizes the composite
signal at 12-bit resolution (~960 KSPS). A Verilog RTL pipeline extracts
three waveform features (F1 spike width, F2 peak timing, F3 rise ratio) and
classifies each spike using a Leaky Integrate-and-Fire spiking neural network
whose weights are pre-trained offline in Python using snnTorch.

---

## Analog Circuit

```
Signal generator
  CH1 (2Hz square) ──[R_i=1kΩ]──┬──[C_d=10nF]──┬──[Ra=10kΩ]──┐
  τ_i=1µs, τ_d=10µs             [C_i=1nF]      [R_d=1kΩ]     │
                                  │              │              │
                                 GND            GND            │
                                                               ├──► TL071 ──► R1/R2 ──► JXADC J3
  CH2 (1Hz square) ──[R_i=10kΩ]──┬──[C_d=100nF]──┬──[Rb=10kΩ]──┤   summing   divider
  τ_i=100µs, τ_d=1ms             [C_i=10nF]      [R_d=10kΩ]   │   amp
                                  │               │              │
                                 GND             GND            │
                                                               │
  Zener noise ──[100kΩ] ──[Rn=47kΩ] ──────────────────────────┘

  R1=20kΩ, R2=80kΩ  →  ×0.8 scaling  →  peak ≈ 0.62V  (within 0–1V XADC range)
  External XADC filter: 100Ω series + 10nF differential cap at J3/K3
```

**Corrected differentiator topology:**
Each differentiator stage has the capacitor in series and resistor to GND
(output taken across the resistor — high-pass filter). Both integrator and
differentiator are distinct stages, not cascaded low-pass filters.

---

## Project Structure

```
spikesort/
├── data/
│   └── simulate_waveforms.py   — generates RC waveform dataset, extracts features
├── model/
│   └── train_snn.py            — trains 3→6→3 LIF SNN in PyTorch/snnTorch
├── export/
│   └── export_weights.py       — converts weights to Q8, prints Verilog localparam block
├── rtl/
│   ├── spike_sorter_top.v      — top-level: clock divider, rate encoder, integration
│   ├── xadc_sampler.v          — XADC primitive, 12-bit samples at ~960 KSPS
│   ├── spike_detector.v        — FSM: capture window + F1/F2/F3 feature extraction
│   ├── lif_neuron.v            — LIF neuron primitive (reusable)
│   ├── snn_core.v              — 3→6→3 LIF SNN with Q8 weight constants
│   ├── output_decoder.v        — population vote classifier
│   ├── seg7_controller.v       — 7-segment display driver
│   └── spikesort.xdc           — Basys-3 pin constraints (ANALOG for JXADC pins)
├── requirements.txt
└── README.md
```

---

## Usage

### Step 1 — Python environment

```bash
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### Step 2 — Generate training data

```bash
python data/simulate_waveforms.py
```

Simulates integrator-differentiator cascade waveforms analytically. Saves
`data/X_raw.npy`, `data/y_labels.npy`, `data/X_features.npy` and two
diagnostic plots. Check `data/waveforms.png` — Neuron A should show a narrow
spike (~12 samples wide), Neuron B a wide spike (~1200 samples wide).

### Step 3 — Train the SNN

```bash
python model/train_snn.py
```

Trains 3→6→3 LIF network for 50 epochs. Target accuracy > 90%.
Best checkpoint saved to `model/spikesort_weights.pt`.

### Step 4 — Export Q8 weights

```bash
python export/export_weights.py
```

Prints a Verilog `localparam` block to the terminal and saves it to
`export/weights_q8.vh`.

### Step 5 — Paste weights into RTL

Open `rtl/snn_core.v`. Find the comment:

```
// ── PASTE EXPORTED Q8 WEIGHTS HERE ──
```

Replace the placeholder `W_IH` and `W_HO` blocks with the output from Step 4.

### Step 6 — Vivado project

1. Create project → RTL Project → part `xc7a35tcpg236-1`
2. Set language to **SystemVerilog** (required for localparam array syntax)
3. Add all `.v` files from `rtl/` as design sources
4. Add `rtl/spikesort.xdc` as constraints
5. Set `spike_sorter_top` as top module
6. Run Synthesis → Implementation → Generate Bitstream → Program Device

### Step 7 — Hardware test

| Test | Expected display |
|---|---|
| Reset only (btnC) | `-` |
| CH1 only, 2 Hz | `A` at 2 Hz |
| CH2 only, 1 Hz | `b` at 1 Hz |
| Both channels | `A` and `b` alternating |
| No input, noise only | `N` or holds last result |

---

## Timing

| Parameter | Value |
|---|---|
| Signal generator CH1 | 2 Hz, 5 Vpp, High Z |
| Signal generator CH2 | 1 Hz, 5 Vpp, High Z, 180° phase offset |
| XADC sample rate | ~960 KSPS |
| Spike capture window | 1000 samples = 1 ms |
| Refractory period | 10000 samples = 10 ms |
| Pipeline latency | ~11 ms per spike |
| ISI Neuron A | 500 ms |
| Overlap margin | 495 ms (>100× spike duration) |

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Display stuck on `-` | Probe JXADC J3 — verify peak > 49 mV; check R1/R2 divider |
| Always classifies as A | Re-run export_weights.py, paste new weights into snn_core.v |
| LIF neurons never fire | Change `.THRESHOLD(128)` to `.THRESHOLD(64)` in snn_core.v |
| Noisy / flickering display | Increase `.VOTE_WINDOW(256)` to `.VOTE_WINDOW(512)` |
| Vivado ANALOG iostandard error | Ensure `set_property IOSTANDARD ANALOG` for vp_in and vn_in in XDC |
| localparam array syntax error | Confirm project language is set to SystemVerilog in Vivado settings |
