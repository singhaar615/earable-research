%% bruxism_fft_silence_vs_fan
clear; clc; close all;
filename       = 'baseline.csv';   % <-- update to your actual filename
maxDisplayFreq = 1000;             % Hz, x-axis limit on both plots
yAxisLimits    = [-20 25];         % dB, y-axis limit on both plots
%% LOAD DATA
if ~isfile(filename)
    error('Can''t find "%s" in the current folder (%s). cd there or set filename to the full path.', filename, pwd);
end
T = readtable(filename, 'VariableNamingRule', 'preserve');
t = T.("Time (s)");
silenceCol = T.Silence;
fanCol     = T.Fan;
Fs = round(1 / median(diff(t), 'omitnan'));   % sample rate from Time column
fprintf('Detected sample rate: %d Hz\n', Fs);
% drop any trailing/blank NaN rows, remove DC offset
silenceSignal = silenceCol(~isnan(silenceCol));
silenceSignal = silenceSignal - mean(silenceSignal);
fanSignal = fanCol(~isnan(fanCol));
fanSignal = fanSignal - mean(fanSignal);
fprintf('Silence: %d samples (%.1f s)\n', numel(silenceSignal), numel(silenceSignal)/Fs);
fprintf('Fan: %d samples (%.1f s)\n', numel(fanSignal), numel(fanSignal)/Fs);
%% FREQUENCY DOMAIN VIA WELCH'S METHOD
% segment -> window -> FFT -> average, plain fft() so no toolbox needed
winLen   = 4096;                 % ~0.82 s window at 5 kHz
noverlap = round(winLen/2);
nfft     = winLen;
[Psilence, fAxis] = welchPSD(silenceSignal, winLen, noverlap, nfft, Fs);
[Pfan, ~]         = welchPSD(fanSignal,     winLen, noverlap, nfft, Fs);
%% PLOT

% dB scale to compress dynamic range so smaller peaks stay visible

fig = figure('Position', [100 100 900 700], 'Color', 'white');

subplot(2,1,1);

plot(fAxis, 10*log10(Psilence), 'LineWidth', 1);

title('Silence (Frequency Spectrum)','Color', 'black');
xlabel('Frequency (Hz)');
ylabel('Decibels (dB)');
grid on;
xlim([0 maxDisplayFreq]);
ylim(yAxisLimits);

set(gca, 'Color', 'white');
set(gca, 'XColor', 'black', 'YColor', 'black');

subplot(2,1,2);

plot(fAxis, 10*log10(Pfan), 'LineWidth', 1, 'Color', [0.85 0.33 0.10]);

title('Fan Noise (Frequency Spectrum)', 'Color', 'black');
xlabel('Frequency (Hz)');
ylabel('Decibels (dB)');
grid on;
xlim([0 maxDisplayFreq]);
ylim(yAxisLimits);

set(gca, 'Color', 'white');
set(gca, 'XColor', 'black', 'YColor', 'black');

sgtitle('Bruxism Signal: Silence vs Fan Noise — Baseline Frequency Comparison', 'Color', 'black');

outPng = 'bruxism_silence_vs_fan_spectrum.png';

exportgraphics(fig, outPng, 'Resolution', 200);

fprintf('Saved plot to %s\n', outPng);

%%helper
function [Pxx, f] = welchPSD(x, winLen, noverlap, nfft, Fs)
% Minimal Welch PSD estimate: Hamming-windowed segments, FFT each,
% average the power spectra. Same idea as pwelch, no toolbox needed.
x = x(:);
n = (0:winLen-1)';
win = 0.54 - 0.46*cos(2*pi*n/(winLen-1));  % Hamming window
U = sum(win.^2);                            % window power, for normalization
step = winLen - noverlap;
numSegs = floor((length(x) - winLen)/step) + 1;
assert(numSegs >= 1, 'Signal is shorter than the analysis window (%d samples).', winLen);
halfN = nfft/2 + 1;
Pxx = zeros(halfN, 1);
for k = 1:numSegs
    idx = (k-1)*step + (1:winLen);
    seg = x(idx) .* win;
    X = fft(seg, nfft);
    Xh = X(1:halfN);
    Pk = (abs(Xh).^2) / (Fs*U);
    Pk(2:end-1) = 2*Pk(2:end-1);             % fold negative-frequency energy in
    Pxx = Pxx + Pk;
end
Pxx = Pxx / numSegs;
f = (0:halfN-1)' * (Fs/nfft);
end
