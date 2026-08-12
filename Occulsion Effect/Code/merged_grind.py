import matplotlib.pyplot as plt
import numpy as np

SAMPLE_MS  = 10
WINDOW_MS  = 200

//load data
def load_amplitudes(filepath):
    amplitudes = []
    with open(filepath, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split()
            if len(parts) == 3:
                try:
                    amplitudes.append(int(parts[2]))
                except ValueError:
                    pass
    if not amplitudes:
        raise ValueError(f"No valid data found in {filepath}.")
    return np.array(amplitudes)

//initialize
datasets = [
    ("sound_intensity_data.txt", "#a8c8f0", "#1f6fbf", "Open Ear (No Occlusion)"),
    ("in_ear_sound_data.txt",    "#d87272", "#801e2e", "Ear Canal (Occluded)"),
]

//plot
fig, axes = plt.subplots(2, 1, figsize=(12, 12), sharex=True)

for ax, (filepath, raw_color, avg_color, title) in zip(axes, datasets):
    amplitudes = load_amplitudes(filepath)
    n = len(amplitudes)
    time_s = np.arange(n) * SAMPLE_MS / 1000.0

    window_samples = max(1, WINDOW_MS // SAMPLE_MS)
    kernel = np.ones(window_samples) / window_samples
    smoothed = np.convolve(amplitudes, kernel, mode = "same")

    ax.plot(time_s, amplitudes, color = raw_color, linewidth = 1.0, alpha = 0.7, label =" Raw amplitude")
    ax.plot(time_s, smoothed,   color = avg_color, linewidth = 1.6, label = f"Rolling avg ({WINDOW_MS} ms)")

    ax.set_title(title, fontsize = 20, fontweight = "bold")
    ax.set_ylabel("Amplitude (ADC units)", fontsize = 22, fontweight = "bold")
    ax.set_xlim(0, time_s[-1])

    if title == "Open Ear (No Occlusion)":
            ax.set_ylim(0, 100) 
    else:
        ax.set_ylim(0, 210)

    ax.legend(fontsize = 16)
    ax.grid(True, linestyle = "--", alpha = 0.4)

axes[1].set_xlabel("Time (s)", fontsize = 22, fontweight = "bold")

fig.suptitle("Teeth Grinding: Open Ear vs. Occluded (Ear Canal)", fontsize = 30, fontweight = "bold")
fig.tight_layout(rect = [0, 0, 1, 0.97])

plt.savefig("grinding_comparison.png", dpi = 150, bbox_inches = "tight")
plt.show()
