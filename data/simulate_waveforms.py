import numpy as np
import matplotlib.pyplot as plt

# Sampling parameters
WINDOW_SIZE  = 1000      # samples per waveform — matches FPGA WINDOW_SIZE
FS           = 1e6       # 1 MHz — matches XADC sample rate and FPGA 1 MHz clock
NUM_SAMPLES  = 1000      # waveforms per class
THRESHOLD    = 200/4095  # normalized detection threshold (200 LSB / 4095 full-scale)

# RC time constants
#    Neuron A: R_i=1kΩ, C_i=1nF, R_d=1kΩ, C_d=10nF
#    Neuron B: R_i=10kΩ, C_i=10nF, R_d=10kΩ, C_d=100nF
TAU_I_A, TAU_D_A = 1e-6,   10e-6   # interneuron:   τ_i=1µs,   τ_d=10µs
TAU_I_B, TAU_D_B = 100e-6, 1e-3    # pyramidal cell: τ_i=100µs, τ_d=1ms


# Waveform generation
def spike_waveform(tau_i, tau_d, n_points=WINDOW_SIZE, fs=FS):
    """
    Analytical cascade response of RC integrator + RC differentiator to a
    unit step input.

    V(t) = [τ_d / (τ_d − τ_i)] × (e^(−t/τ_d) − e^(−t/τ_i))

    Peak occurs at: t_peak = ln(τ_d/τ_i) × τ_i×τ_d / (τ_d − τ_i)
    Peak amplitude ≈ 0.39 × V_in  when τ_d/τ_i = 10
    """
    dt = 1.0 / fs
    t  = np.arange(n_points) * dt

    if abs(tau_d - tau_i) > 1e-12:
        scale    = tau_d / (tau_d - tau_i)
        waveform = scale * (np.exp(-t / tau_d) - np.exp(-t / tau_i))
    else:
        # Degenerate case τ_i == τ_d
        waveform = (t / tau_d) * np.exp(-t / tau_d)

    # Rectification 
    waveform = np.maximum(waveform, 0.0)

    # Normalize peak
    peak = np.max(np.abs(waveform))
    if peak > 0:
        waveform /= peak
    return waveform

# Feature extraction
def extract_features(waveform, threshold=THRESHOLD):
    """
    Extract F1, F2, F3 using identical logic to FPGA spike_detector.v.
    Valid because waveform has amplitude information (12-bit XADC samples),
    unlike a single-bit comparator which cannot locate the true peak.

    F1: fraction of window above threshold          → spike width
    F2: normalized index of maximum sample          → peak timing
    F3: rise samples / total above-threshold        → rise ratio
    """
    above    = waveform > threshold
    peak_idx = int(np.argmax(waveform))

    # F1 — spike width
    F1 = float(np.sum(above)) / WINDOW_SIZE

    # F2 — peak timing
    F2 = float(peak_idx) / WINDOW_SIZE

    # F3 — rise ratio
    above_before_peak = np.sum(above[:peak_idx])
    total_above       = np.sum(above)
    F3 = float(above_before_peak) / float(total_above) if total_above > 0 else 0.0

    return np.array([F1, F2, F3], dtype=np.float32)


# Dataset generation
def generate_dataset(noise_std=0.05):
    """
    Generate labeled dataset for three classes:
      0 = Neuron A  (fast-spiking interneuron,    τ_d = 10 µs)
      1 = Neuron B  (regular-spiking pyramidal,   τ_d = 1 ms)
      2 = Noise     (sub-threshold background activity)
    """
    X, y = [], []

    base_A = spike_waveform(TAU_I_A, TAU_D_A)
    base_B = spike_waveform(TAU_I_B, TAU_D_B)

    rng = np.random.default_rng(seed=42)

    for _ in range(NUM_SAMPLES):
        # Neuron A — narrow fast spike
        w = base_A + rng.normal(0, noise_std, WINDOW_SIZE)
        X.append(w.astype(np.float32))
        y.append(0)

        # Neuron B — wide slow spike
        w = base_B + rng.normal(0, noise_std, WINDOW_SIZE)
        X.append(w.astype(np.float32))
        y.append(1)

        # Noise — no spike, pure noise floor
        w = rng.normal(0, noise_std * 2, WINDOW_SIZE)
        X.append(w.astype(np.float32))
        y.append(2)

    return np.array(X), np.array(y)


if __name__ == "__main__":
    print("Generating dataset...")
    X, y = generate_dataset()

    # Save raw waveforms and labels
    np.save("data/X_raw.npy",    X)
    np.save("data/y_labels.npy", y)
    print(f"  {X.shape[0]} waveforms saved to data/X_raw.npy")

    # Extract features
    X_feat = np.array([extract_features(x) for x in X])
    np.save("data/X_features.npy", X_feat)
    print(f"  Feature array shape: {X_feat.shape}")

    # Print expected Q8 values for verification
    print("\nExpected Q8 feature values (F1, F2, F3):")
    for cls, name in zip([0, 1, 2], ["Neuron A", "Neuron B", "Noise  "]):
        mask  = y == cls
        means = X_feat[mask].mean(axis=0)
        q8    = (means * 256).astype(int)
        print(f"  {name}: F1={q8[0]:3d}  F2={q8[1]:3d}  F3={q8[2]:3d}")

    # F1 separation ratio
    f1_A = X_feat[y==0, 0].mean()
    f1_B = X_feat[y==1, 0].mean()
    print(f"\n  F1 separation ratio (B/A): {f1_B/f1_A:.1f}x")

    # Waveform plot
    t_us = np.arange(WINDOW_SIZE) / FS * 1e6   # time axis in microseconds

    fig, axes = plt.subplots(1, 3, figsize=(14, 4))
    colors = ['#1F497D', '#C0392B', '#7F8C8D']
    for i, (label, color) in enumerate(zip(["Neuron A (τ_d=10µs)", "Neuron B (τ_d=1ms)", "Noise"], colors)):
        idx = np.where(y == i)[0][0]
        axes[i].plot(t_us, X[idx], color=color, linewidth=1.2)
        axes[i].axhline(THRESHOLD, color='orange', linestyle='--', linewidth=1, label=f'threshold ({THRESHOLD:.3f})')
        axes[i].set_title(label, fontsize=11, fontweight='bold')
        axes[i].set_xlabel("Time (µs)")
        axes[i].set_ylabel("Amplitude (normalized)")
        axes[i].legend(fontsize=8)
        axes[i].grid(True, alpha=0.3)
    plt.suptitle("RC Integrator-Differentiator Waveforms", fontsize=13, fontweight='bold')
    plt.tight_layout()
    plt.savefig("data/waveforms.png", dpi=150)
    print("\nSaved: data/waveforms.png")

    # Feature space plot
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    names  = ['Neuron A', 'Neuron B', 'Noise']
    colors = ['#1F497D', '#C0392B', '#7F8C8D']

    for cls in range(3):
        mask = y == cls
        axes[0].scatter(X_feat[mask, 0], X_feat[mask, 1],
                        c=colors[cls], label=names[cls], alpha=0.35, s=8)
        axes[1].scatter(X_feat[mask, 0], X_feat[mask, 2],
                        c=colors[cls], label=names[cls], alpha=0.35, s=8)

    axes[0].set_xlabel("F1: Spike Width");  axes[0].set_ylabel("F2: Peak Timing")
    axes[1].set_xlabel("F1: Spike Width");  axes[1].set_ylabel("F3: Rise Ratio")
    for ax in axes:
        ax.legend(); ax.grid(True, alpha=0.3)
    plt.suptitle("Feature Space — Three-Class Separation", fontsize=13, fontweight='bold')
    plt.tight_layout()
    plt.savefig("data/feature_space.png", dpi=150)
    print("Saved: data/feature_space.png")
