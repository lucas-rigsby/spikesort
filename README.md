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