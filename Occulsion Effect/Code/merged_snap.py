import matplotlib.pyplot as plt
import numpy as np

SAMPLE_MS  = 10
WINDOW_MS  = 200

#load data
def load_amplitudes(filepath):
    amplitudes = []

    with open(filepath, "r") as f:
        for line in f:
            parts = line.strip().split()

            if len(parts) == 3:
                try:
                    amplitudes.append(int(parts[2]))
                except ValueError:
                    continue #skip invalid values

    if len(amplitudes) == 0:
        raise ValueError(f"No valid data found in {filepath}.")

    return np.array(amplitudes)

#initialize
datasets = [
    ("sound_intensity_data.txt", "lightblue", "blue", "Open Ear (No Occlusion)"),
    ("in_ear_sound_data.txt", "pink", "red", "Ear Canal (Occluded)"),
]

#plotting
fig, axes = plt.subplots(2, 1, figsize=(12, 12), sharex=True, sharey=True)

for ax, (filepath, raw_color, title) in zip(axes, datasets):
    amplitudes = load_amplitudes(filepath)
    n          = len(amplitudes)
    time_s     = np.arange(n) * SAMPLE_MS / 1000.0

    window_samples = max(1, WINDOW_MS // SAMPLE_MS)
    kernel         = np.ones(window_samples) / window_samples

    ax.plot(time_s, amplitudes, color=raw_color, linewidth=1.2, alpha=0.7, label="Raw amplitude")

    ax.set_title(title, fontsize=20, fontweight="bold")
    ax.set_ylabel("Amplitude (ADC units)", fontsize=22, fontweight="bold")
    ax.set_xlim(0, time_s[-1])
    ax.set_ylim(0, 300)
    ax.legend(fontsize=16)
    ax.grid(True, linestyle="--", alpha=0.4)

axes[1].set_xlabel("Time (s)", fontsize=22, fontweight="bold")

fig.suptitle("Teeth Snapping: Open Ear vs. Occluded (Ear Canal)", fontsize=30, fontweight="bold")
fig.tight_layout(rect=[0, 0, 1, 0.97])

plt.savefig("snapping_comparison.png", dpi=150, bbox_inches="tight")
plt.show()
