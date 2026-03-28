import numpy as np
import matplotlib.pyplot as plt

WINDOW_SIZE  = 512
NUM_SAMPLES  = 1000  # per class

def rc_waveform(tau, window=WINDOW_SIZE, amplitude=1.0):
    """Generate a single RC exponential decay spike."""
    t = np.arange(window)
    return amplitude * np.exp(-t / tau)

def generate_dataset(tau_A=10, tau_B=100, noise_std=0.05):
    X, y = [], []
    for _ in range(NUM_SAMPLES):
        # Neuron A — fast spike
        w = rc_waveform(tau_A) + np.random.normal(0, noise_std, WINDOW_SIZE)
        X.append(w); y.append(0)

        # Neuron B — slow spike
        w = rc_waveform(tau_B) + np.random.normal(0, noise_std, WINDOW_SIZE)
        X.append(w); y.append(1)

        # Noise — no clear spike
        w = np.random.normal(0, noise_std * 2, WINDOW_SIZE)
        X.append(w); y.append(2)

    return np.array(X), np.array(y)

def extract_features(waveform, threshold=0.3):
    """
    F1: spike width  — fraction of window above threshold
    F2: peak timing  — normalized position of maximum value
    """
    above = waveform > threshold
    F1 = np.sum(above) / len(waveform)
    F2 = np.argmax(waveform) / len(waveform)
    return np.array([F1, F2])

if __name__ == "__main__":
    X, y = generate_dataset()

    # Save raw waveforms
    np.save("data/X_raw.npy", X)
    np.save("data/y_labels.npy", y)

    # Extract and save features
    X_feat = np.array([extract_features(x) for x in X])
    np.save("data/X_features.npy", X_feat)

    print(f"Dataset generated: {X.shape[0]} samples, {X_feat.shape[1]} features each")

    # Plot one example of each class
    fig, axes = plt.subplots(1, 3, figsize=(12, 3))
    for i, label in enumerate(["Neuron A", "Neuron B", "Noise"]):
        axes[i].plot(X[y == i][0])
        axes[i].set_title(label)
        axes[i].set_xlabel("Sample")
        axes[i].set_ylabel("Amplitude")
    plt.tight_layout()
    plt.savefig("data/waveforms.png")
    print("Saved: data/waveforms.png")

    # Plot feature space
    plt.figure(figsize=(6, 5))
    colors = ['blue', 'red', 'gray']
    labels = ['Neuron A', 'Neuron B', 'Noise']
    for cls in range(3):
        mask = y == cls
        plt.scatter(X_feat[mask, 0], X_feat[mask, 1],
                    c=colors[cls], label=labels[cls], alpha=0.4, s=10)
    plt.xlabel("F1: Spike Width")
    plt.ylabel("F2: Peak Timing")
    plt.legend()
    plt.title("Feature Space")
    plt.savefig("data/feature_space.png")
    print("Saved: data/feature_space.png")
