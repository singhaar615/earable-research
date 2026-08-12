# Earable-Based Sleep Bruxism Detection

Research project developing a low-cost, in-ear wearable ("earable") system to detect and classify sleep bruxism (teeth grinding) using acoustic signal processing. The system captures grinding-related sound via an in-ear MEMS microphone, processes it on an Arduino, and analyzes it in MATLAB to flag grinding severity.

## Overview

Sleep bruxism is typically diagnosed via polysomnography (PSG), which is expensive, lab-based, and inconvenient for longitudinal monitoring. This project explores whether a simple in-ear acoustic sensor can achieve meaningful grinding detection outside a clinical setting: using nothing more than a MEMS microphone, an Arduino, and signal processing techniques adapted from PSG-based bruxism severity research.

The pipeline spans three layers:

- **Hardware** — an Arduino-based in-ear MEMS microphone rig for raw audio data collection
- **Signal processing** — MATLAB scripts for filtering, burst detection, and spectral analysis
- **Classification** — a lightweight warning algorithm that flags grinding events as No Warning / Mild / Severe

## Background & Motivation

Occlusion testing (mic near the jaw vs. mic sealed in-ear) showed that in-ear placement produced a substantially stronger grinding signal than external placement — and was more comfortable — so all subsequent data collection used in-ear placement.

Detection logic was informed by a review of PSG-based bruxism severity literature, whose burst-detection thresholds and two-factor severity structure (episode count vs. duration) shaped the design of this project's own detection algorithm.

### Key scripts

| Script | Purpose |
|---|---|
| `bruxism_fft_analysis.m` | Full analysis pipeline — burst detection, STFT spectrograms, Butterworth bandpass filtering |
| `bruxism_warning_simple.m` | MATLAB only (no toolboxes) classifier — reads `daily_log.csv`, isolates the grinding band, detects bursts via envelope thresholding, applies duty-cycle/spectral-flatness speech rejection, and issues a Mild/Severe warning when corroborating bursts are found |


## Known Limitations

- Detected grinding duration tracks the correct relative trend across severity tiers but is not numerically precise against ground-truth grinding time
- Classification accuracy has only been validated on a single subject; generalization to other users/ear geometries is untested
- Band selection (20–80 Hz) and thresholds were tuned empirically for this dataset and may need recalibration for other hardware or environments

## Status

This research project has concluded; the repository is preserved as a record of the methodology, pipeline, and findings.

## License

See [LICENSE](LICENSE) for details.
