#!/usr/bin/env python3
"""Makes demo inputs for the BPF and BSF modes of the FPGA filter, from ECG/EEG-like signals.

Why these sample rates: the filter's response is fixed in units of the sample rate fs (fs = 1.0):
    BPF passes 0.20-0.30 fs flat (-6 dB at 0.15 and 0.35 fs), stops below 0.1 fs and above 0.4 fs
    BSF stops 0.20-0.30 fs (about -45 dB), passes below 0.1 fs and above 0.4 fs
So the signal is resampled to the rate that puts the band you care about in the right place:
    fs = 40 Hz  -> BPF passes 8-12 Hz (EEG alpha band; also the 6-14 Hz QRS band of an ECG)
    fs = 200 Hz -> BSF removes 40-60 Hz (50 Hz mains hum, India), passes 0-20 Hz (ECG/EEG content)

Outputs (16-bit WAV files whose "sample rate" is just the bio-signal rate):
    ecg_bpf_40Hz.wav        ECG + baseline wander + muscle noise      -> run with --mode bpf
    eeg_bpf_40Hz.wav        EEG-like (delta/theta/alpha/beta) + drift  -> run with --mode bpf
    ecg_bsf_200Hz_hum.wav   ECG + 50 Hz mains hum                      -> run with --mode bsf
    eeg_bsf_200Hz_hum.wav   EEG-like + 50 Hz mains hum                 -> run with --mode bsf

Default source is SYNTHETIC (works offline). To use REAL recordings:
    --real-ecg         real ECG (MIT-BIH record 208, 360 Hz) via scipy; needs: pip install pooch (internet once)
                       -> writes ecgreal_bpf_40Hz.wav and ecgreal_bsf_200Hz_hum.wav
    --edf FILE         real EEG from an EDF file (e.g. S001R02.edf from the PhysioNet EEG Motor Movement/Imagery
                       dataset: 64 channels, 160 Hz, eyes-closed baseline). --channel Oz picks the electrode.
                       -> writes eegreal_bpf_40Hz.wav and eegreal_bsf_200Hz_hum.wav
    --csv FILE --csv-fs N   any one-column text/CSV recording sampled at N Hz (use --name to name the output)
    --start S          skip the first S seconds of a real recording (default 5)
The 50 Hz hum in the BSF files is always added artificially (the real recordings were not made in a 50 Hz country).
Needs: pip install numpy scipy
"""
import argparse, math, os, sys, wave
import numpy as np
from scipy.signal import resample_poly

rng = np.random.default_rng(7)
DUR = 30.0

def write_wav(path, x, fs, peak=16000):
    x = np.asarray(x, float); x = x - x.mean()
    x = np.round(x / np.abs(x).max() * peak).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(int(fs)); w.writeframes(x.tobytes())

def resample(x, fs_in, fs_out):
    g = math.gcd(int(fs_in), int(fs_out))
    return resample_poly(x, int(fs_out) // g, int(fs_in) // g)     # includes an anti-alias filter

def synth_ecg(fs=500, dur=DUR):
    """Sum-of-Gaussians ECG (P, Q, R, S, T waves) with heart-rate variability, baseline wander, muscle noise."""
    t = np.arange(int(fs * dur)) / fs; x = np.zeros_like(t)
    beat = 0.5
    while beat < dur + 1:
        rr = 0.85 + 0.05 * rng.standard_normal()                    # ~70 bpm
        for amp, off, wid in ((0.15, -0.20, 0.040), (-0.12, -0.035, 0.012), (1.00, 0.0, 0.012),
                              (-0.25, 0.035, 0.014), (0.30, 0.25, 0.070)):
            x += amp * np.exp(-0.5 * ((t - beat - off) / wid) ** 2)
        beat += rr
    wander = 0.35 * np.sin(2*np.pi*0.25*t + 1.0) + 0.15 * np.sin(2*np.pi*0.1*t)
    emg = 0.04 * rng.standard_normal(len(t))
    return t, x + wander + emg

def synth_eeg(fs=250, dur=DUR):
    """EEG-like: 1/f background + delta + theta + alpha bursts (10 Hz) + beta + slow drift."""
    n = int(fs * dur); t = np.arange(n) / fs
    f = np.fft.rfftfreq(n, 1/fs); f[0] = 1
    pink = np.fft.irfft((rng.standard_normal(len(f)) + 1j*rng.standard_normal(len(f))) / f, n)
    pink = pink / pink.std() * 6.0
    burst = np.clip(np.sin(2*np.pi*0.15*t) + 0.3, 0, 1) ** 2        # alpha comes and goes every ~7 s
    x = (pink + 12*np.sin(2*np.pi*2.0*t) + 6*np.sin(2*np.pi*5.5*t + 1.3)
         + 20*burst*np.sin(2*np.pi*10.0*t) + 4*np.sin(2*np.pi*21.0*t + 0.4)
         + 25*np.sin(2*np.pi*0.2*t))
    return t, x

def add_hum(x, fs, rel=0.6, f0=50.0):
    t = np.arange(len(x)) / fs
    return x + rel * np.std(x) * math.sqrt(2) * np.sin(2*np.pi*f0*t + 0.7)


def read_edf(path):
    """Minimal EDF/EDF+ reader (no extra packages). Returns {label: (samples_in_physical_units, fs)}; skips annotations."""
    raw = open(path, 'rb').read()
    ns = int(raw[252:256]); hbytes = int(raw[184:192]); nrec = int(raw[236:244]); dur = float(raw[244:252])
    off = [256]
    def field(w):
        v = [raw[off[0] + i*w: off[0] + (i+1)*w].decode('latin1').strip() for i in range(ns)]; off[0] += ns*w; return v
    labels = field(16); field(80); field(8)
    pmin = [float(v) for v in field(8)]; pmax = [float(v) for v in field(8)]
    dmin = [float(v) for v in field(8)]; dmax = [float(v) for v in field(8)]
    field(80); nsamp = [int(v) for v in field(8)]; field(32)
    per_rec = sum(nsamp); data = np.frombuffer(raw[hbytes:], dtype='<i2')
    if nrec < 0 or nrec * per_rec > len(data): nrec = len(data) // per_rec
    data = data[:nrec * per_rec].reshape(nrec, per_rec)
    out = {}; start = 0
    for i in range(ns):
        sig = data[:, start:start + nsamp[i]].reshape(-1).astype(float); start += nsamp[i]
        if 'annotation' in labels[i].lower(): continue
        gain = (pmax[i] - pmin[i]) / (dmax[i] - dmin[i]); out[labels[i]] = ((sig - dmin[i]) * gain + pmin[i], nsamp[i] / dur)
    return out

def pick_channel(chs, name):
    key = lambda s: s.replace('.', '').replace(' ', '').lower()
    for k in chs:
        if key(k) == key(name): return chs[k]
    sys.exit(f"channel '{name}' not found. Available: " + ', '.join(sorted(key(k) for k in chs)))

def write_pair(x, fs_in, prefix, hum):
    """The two demo files for one real signal: BPF at 40 Hz, BSF at 200 Hz (+ 50 Hz hum added)."""
    x = x - x.mean()
    write_wav(f'{prefix}_bpf_40Hz.wav', resample(x, fs_in, 40), 40)
    write_wav(f'{prefix}_bsf_200Hz_hum.wav', add_hum(resample(x, fs_in, 200), 200, hum), 200)
    print(f'wrote {prefix}_bpf_40Hz.wav and {prefix}_bsf_200Hz_hum.wav')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--real-ecg', action='store_true'); ap.add_argument('--edf'); ap.add_argument('--channel', default='Oz')
    ap.add_argument('--csv'); ap.add_argument('--csv-fs', type=float); ap.add_argument('--name', default='myrec')
    ap.add_argument('--start', type=float, default=5.0, help='seconds to skip at the start of a real recording')
    ap.add_argument('--hum', type=float, default=0.6, help='50 Hz hum amplitude relative to the signal rms (BSF demos)')
    a = ap.parse_args()
    real = False

    if a.csv:
        if not a.csv_fs: sys.exit("give --csv-fs (sample rate of the file, Hz)")
        x = np.loadtxt(a.csv, delimiter=',' if a.csv.lower().endswith('.csv') else None, usecols=0, ndmin=1)
        x = x[int(a.start * a.csv_fs):int((a.start + DUR) * a.csv_fs)]
        write_pair(x, a.csv_fs, a.name, a.hum); real = True

    if a.edf:
        x, fs = pick_channel(read_edf(a.edf), a.channel)
        print(f"EDF channel {a.channel}: {len(x)/fs:.0f} s at {fs:.0f} Hz")
        x = x[int(a.start * fs):int((a.start + DUR) * fs)]
        if len(x) < 10 * fs: sys.exit("recording too short after --start; lower --start")
        write_pair(x, fs, 'eegreal', a.hum); real = True

    if a.real_ecg:
        try: from scipy.datasets import electrocardiogram
        except Exception as e: sys.exit(f"{e}\nInstall: pip install pooch   (needs internet)")
        try: ecg = electrocardiogram()
        except Exception as e: sys.exit(f"could not load the ECG ({e}). Needs: pip install pooch, and internet the first time.")
        ecg = ecg[int(a.start * 360):int((a.start + DUR) * 360)]
        write_pair(ecg, 360, 'ecgreal', a.hum); real = True
        print("ECG is REAL: MIT-BIH Arrhythmia Database record 208 (360 Hz), as shipped with scipy")

    if real: return

    _, ecg = synth_ecg(500); _, eeg = synth_eeg(250)
    print("using SYNTHETIC ECG and EEG (generated, not recordings)")
    write_wav('ecg_bpf_40Hz.wav', resample(ecg, 500, 40), 40)
    write_wav('eeg_bpf_40Hz.wav', resample(eeg, 250, 40), 40)
    write_wav('ecg_bsf_200Hz_hum.wav', add_hum(resample(ecg, 500, 200), 200, a.hum), 200)
    write_wav('eeg_bsf_200Hz_hum.wav', add_hum(resample(eeg, 250, 200), 200, a.hum), 200)
    print("wrote ecg_bpf_40Hz.wav, eeg_bpf_40Hz.wav, ecg_bsf_200Hz_hum.wav, eeg_bsf_200Hz_hum.wav")

if __name__ == '__main__':
    main()
