# SpikeSort
**Real-Time LIF Spiking Neural Network Neural Spike Classifier on Basys-3 FPGA**

---

## Motivation

When an electrode is implanted in neural tissue, it picks up electrical activity
from multiple neurons simultaneously. Identifying which neuron fired a given spike, a problem called spike sorting, is fundamental to brain-computer interfaces, implantable neuroprosthetics, and intraoperative neural monitoring. Current
clinical hardware solves this in real time under extreme power and latency constraints, making it an ideal target for FPGA implementation.

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
whose weights are pre-trained offline in Python using snnTorch. Once classified,
the corresponding neuron type is shown on the Basys-3 7-segment display. 

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