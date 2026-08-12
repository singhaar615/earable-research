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
| `filtering_algorithm.m` | Detects teeth-grinding bursts from a single acoustic trial. Bandpasses the raw signal to the grinding band, builds an envelope, and flags "active" stretches using an adaptive baseline threshold, scoring each candidate burst on duty cycle and spectral flatness to reject non-grinding noise. Classifies the trial as No/Mild/Severe Warning based on burst count and duration, and plots the time-domain and frequency-domain (Welch PSD) views. |
| `silence_v_fan.m` | Compares the frequency spectrum of grinding recordings made in silence vs. with fan noise present. Concatenates matching Raw (or Filtered) columns per condition across multiple days, computes a Welch PSD for each, and plots the two spectra side by side to check whether fan noise masks or shifts the grinding signature. |
| `updated_fft.ino` | Arduino sketch that samples the earable's microphone at 5 kHz for 150 seconds, tracking a slowly-updating baseline (rolling average) to subtract out DC drift. Applies a fixed noise floor to the deviation from baseline and streams both the raw and processed values over serial as CSV. All data collected from this was used in filtering/analysis in MATLAB. |

## Known Limitations

- Detected grinding duration tracks the correct relative trend across severity tiers but is not numerically precise against ground-truth grinding time
- Classification accuracy has only been validated on a single subject; generalization to other users/ear geometries is untested
- Band selection (20–80 Hz) and thresholds were tuned empirically for this dataset and may need recalibration for other hardware or environments

## Status

This research project has concluded; the repository is preserved as a record of the methodology, pipeline, and findings.

## License

See [LICENSE](LICENSE) for details.
