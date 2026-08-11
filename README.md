# Earable-Based Sleep Bruxism Detection

Research project developing a low-cost, in-ear wearable ("earable") system to detect and classify sleep bruxism (teeth grinding) using acoustic signal processing. The system captures grinding-related sound via an in-ear MEMS microphone, processes it on an Arduino, and analyzes it in MATLAB to flag grinding severity.

## Overview

Sleep bruxism is typically diagnosed via polysomnography (PSG), which is expensive, lab-based, and inconvenient for longitudinal monitoring. This project explores whether a simple in-ear acoustic sensor can achieve meaningful grinding detection outside a clinical setting — using nothing more than a MEMS microphone, an Arduino, and signal processing techniques adapted from PSG-based bruxism severity research.

The pipeline spans three layers:

- **Hardware** — an Arduino-based in-ear MEMS microphone rig for raw audio data collection
- **Signal processing** — MATLAB scripts for filtering, burst detection, and spectral analysis
- **Classification** — a lightweight warning algorithm that flags grinding events as No Warning / Mild / Severe

## Background & Motivation

Occlusion testing (mic near the jaw vs. mic sealed in-ear) showed that in-ear placement produced a substantially stronger grinding signal than external placement — and was more comfortable — so all subsequent data collection used in-ear placement.

Detection logic was informed by a review of PSG-based bruxism severity literature (Rosar et al., 2021), whose burst-detection thresholds and two-factor severity structure (episode count vs. duration) shaped the design of this project's own detection algorithm.

## Hardware

- In-ear MEMS microphone
- Arduino sketch samples at 5 kHz, transmitting both raw ADC values and a baseline-corrected (processed) signal simultaneously at 1 Mbaud
- Trials recorded in 2.5-minute sessions across multiple conditions (silence, fan noise) and multiple days
- A resting DC bias (~250 ADC counts) is expected — an artifact of the powered sensor, not a fault

## Signal Processing Pipeline

Implemented in MATLAB, the pipeline evolved through several iterations:

1. **Data ingestion** — originally `.wav`/`.mat` based, later moved to CSV loading to match the Arduino output format
2. **Burst detection** — rolling RMS thresholding over the raw signal, with gap-bridging to merge closely-spaced sub-events into a single burst
3. **Spectral analysis** — FFT / Welch's PSD and STFT spectrograms to characterize grinding acoustic content; the **20–80 Hz band** was identified as the band that changes significantly during grinding versus baseline (silence/fan) conditions, and is used as the primary filter target
4. **Filtering** — Butterworth bandpass filtering isolates the grinding band before burst detection
5. **False-positive rejection** — normal speech was initially misclassified as severe grinding, since voice fundamental pitch overlapped an earlier, wider grinding band (80–160 Hz). This was resolved by tightening gap-bridging and adding duty-cycle and spectral-flatness checks, which distinguish continuous grinding friction noise from sparse speech pulses

### Key scripts

| Script | Purpose |
|---|---|
| `bruxism_fft_analysis.m` | Full analysis pipeline — burst detection, STFT spectrograms, Butterworth bandpass filtering |
| `bruxism_warning_simple.m` | Lightweight, base-MATLAB-only (no toolboxes) classifier — reads `daily_log.csv`, isolates the grinding band, detects bursts via envelope thresholding, applies duty-cycle/spectral-flatness speech rejection, and issues a Mild/Severe warning when corroborating bursts are found |

## Classification Logic

Grinding events are tiered by burst duration and count:

- **Severe** — requires only 1 corroborating burst above the severe-length floor (a single long sustained burst, e.g. ~7–8s, is enough — it should not be diluted into a "Mild" classification)
- **Mild** — requires 2+ corroborating bursts above the mild-length floor
- **No Warning** — no qualifying bursts detected

On single-subject validation trials, the classifier scored 3/3 (No Warning), 3/3 (Mild), and 2/2 (Severe) — promising, though not yet validated across multiple subjects.

## Data

- **Occlusion comparison** — 3× 10s grinding trials, mic near jaw vs. in-ear
- **Grinding trials** — 30 minutes of grinding under silence, 30 minutes under fan noise (in-ear)
- **Baseline trials** — 5 minutes silence-only and 5 minutes fan-only (in-ear, no grinding), used to identify non-grinding peaks (e.g. powerline interference and harmonics)
- Trial data is organized in `bruxism_data_log.xlsx` (full multi-trial log) and a simplified baseline workbook (single header row with Sample #, Time (s), Silence, and Fan columns)
- `daily_log.csv` — per-day trial log with repeating Severe / Mild / No Warning column blocks, separated by spacer columns

## Known Limitations

- Detected grinding duration tracks the correct relative trend across severity tiers but is not numerically precise against ground-truth grinding time
- Classification accuracy has only been validated on a single subject; generalization to other users/ear geometries is untested
- Band selection (20–80 Hz) and thresholds were tuned empirically for this dataset and may need recalibration for other hardware or environments

## Status

Complete. This research project has concluded; the repository is preserved as a record of the methodology, pipeline, and findings.

## License

See [LICENSE](LICENSE) for details.
