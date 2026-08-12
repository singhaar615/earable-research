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
                    continue #skip invalid

    if len(amplitudes) == 0:
        raise ValueError(f"No valid data found in {filepath}.")

    return np.array(amplitudes)

#initialize
datasets = [
    ("sound_intensity_data.txt", "lightblue", "blue", "Open Ear (No Occlusion)"),
    ("in_ear_sound_data.txt",    "pink",      "red",  "Ear Canal (Occluded)"),
]

#plot
fig, axes = plt.subplots(2, 1, figsize=(12, 12), sharex=True)

for ax, data in zip(axes, datasets):

    filepath, raw_color, avg_color, title = data

    #load amplitude data
    amplitudes = load_amplitudes(filepath)

    #time values
    time_s = np.arange(len(amplitudes)) * SAMPLE_MS / 1000

    #calculate rolling average
    window = max(1, WINDOW_MS // SAMPLE_MS)
    smoothed = np.convolve(amplitudes, np.ones(window) / window, mode = "same")

    #raw data
    ax.plot(time_s, amplitudes, color = raw_color, linewidth = 1, alpha = 0.7, label = "Raw amplitude")
    
    #rolling average
    ax.plot(time_s, smoothed, color = avg_color, linewidth = 1.6, label = f"Rolling avg ({WINDOW_MS} ms)")

    #labels
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

#main title
fig.suptitle(
    "Teeth Grinding: Open Ear vs. Occluded (Ear Canal)", fontsize = 30, fontweight = "bold")

fig.tight_layout(rect = [0, 0, 1, 0.97])

plt.savefig("grinding_comparison.png", dpi = 150, bbox_inches = "tight")
plt.show()
