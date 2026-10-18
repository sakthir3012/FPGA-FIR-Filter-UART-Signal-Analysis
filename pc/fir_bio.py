#!/usr/bin/env python3
"""Run an ECG/EEG demo file through the FPGA filter (or the software model) and plot input vs filtered.
Put this file in your pc\\ folder (next to fir_audio.py and fir_modes_coeffs.py).

  python fir_bio.py --wav ecg_bsf_200Hz_hum.wav --mode bsf --port COM3     (board: SW1:SW0=11, SW2 down, press BTNC first)
  python fir_bio.py --wav eeg_bpf_40Hz.wav      --mode bpf --port COM3     (board: SW1:SW0=10, SW2 down, press BTNC first)
  python fir_bio.py --wav ecg_bsf_200Hz_hum.wav --mode bsf --selftest      (no board: software model stands in)
The WAV's own sample rate is used as the signal's sample rate (40 Hz or 200 Hz for the demo files).
"""
import argparse, sys
import numpy as np
from fir_audio import fir_model, read_wav, run_fpga, SWITCH   # your existing PC script

DELAY = 15.5   # samples; the 32-tap symmetric filter delays everything by (32-1)/2

def band_power(sig, fs, lo, hi):
    w = np.hanning(len(sig)); P = np.abs(np.fft.rfft((sig - sig.mean()) * w)) ** 2
    f = np.fft.rfftfreq(len(sig), 1 / fs); return P[(f >= lo) & (f <= hi)].sum(), P.sum()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--wav', required=True); ap.add_argument('--mode', choices=['bpf', 'bsf', 'lpf', 'hpf'], required=True)
    ap.add_argument('--port'); ap.add_argument('--baud', type=int, default=1000000)
    ap.add_argument('--selftest', action='store_true'); ap.add_argument('--noshow', action='store_true')
    ap.add_argument('--out', default='bio_result'); ap.add_argument('--zoom', type=float, default=8.0, help='seconds shown in the time plots')
    a = ap.parse_args()

    x, fs = read_wav(a.wav)
    x = np.round(x / max(1.0, np.max(np.abs(x))) * 0.5 * 32767).astype(np.int16)
    print(f"{len(x)} samples at {fs} Hz ({len(x)/fs:.1f} s), mode {a.mode.upper()}")
    expected = fir_model(x, a.mode)
    if a.selftest:
        y = expected.copy(); print("SELFTEST: software model stands in for the board")
    else:
        if not a.port: sys.exit("need --port COMx, or --selftest")
        print(f"board must have {SWITCH[a.mode]}, SW2 down; press BTNC before running")
        y = run_fpga(a.port, a.baud, x)
    bad = int(np.count_nonzero(y != expected))
    print(f"Hardware vs software model: {len(x)-bad}/{len(x)} samples identical -> {'PASS' if bad == 0 else 'FAIL'}")

    # ---- numbers that show what the filter did (stop/pass band = 0.2-0.3 x fs)
    lo, hi = 0.2 * fs, 0.3 * fs
    pin, tin = band_power(x.astype(float), fs, lo, hi); pout, tout = band_power(y.astype(float), fs, lo, hi)
    if a.mode == 'bsf':
        print(f"Band {lo:.0f}-{hi:.0f} Hz (the notch): power reduced by {10*np.log10(pin/max(pout,1e-9)):.1f} dB")
    elif a.mode == 'bpf':
        print(f"Band {lo:.0f}-{hi:.0f} Hz (the pass band): {100*pin/tin:.0f}% of the input power -> {100*pout/tout:.0f}% of the output power")
        print(f"Everything outside it: power reduced by {10*np.log10((tin-pin)/max(tout-pout,1e-9)):.1f} dB")

    # ---- plots (filtered trace shifted back by the filter delay, for display only)
    import matplotlib
    if a.noshow: matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.gridspec import GridSpec
    t = np.arange(len(x)) / fs; xf = x.astype(float); yf = y.astype(float)
    y_al = np.interp(t + DELAY / fs, t, yf)
    n = min(len(x), int(a.zoom * fs)); lim = 1.1 * max(np.abs(xf).max(), np.abs(yf).max())
    fig = plt.figure(figsize=(12, 9), constrained_layout=True); gs = GridSpec(3, 2, figure=fig)
    a1 = fig.add_subplot(gs[0, :]); a2 = fig.add_subplot(gs[1, :], sharex=a1, sharey=a1)
    a3 = fig.add_subplot(gs[2, 0]); a4 = fig.add_subplot(gs[2, 1], sharex=a3, sharey=a3)
    a1.plot(t[:n], xf[:n], lw=0.8); a1.set_title(f'INPUT ({a.wav}, fs = {fs} Hz)'); a1.set_ylim(-lim, lim)
    a2.plot(t[:n], y_al[:n], lw=0.8, color='C1')
    a2.set_title(f'FILTERED, {a.mode.upper()} ' + ('(software model)' if a.selftest else '(from FPGA)') + ' - shifted back by the 15.5-sample filter delay')
    a2.set_xlabel('time (s)')
    w = np.hanning(len(x)); f = np.fft.rfftfreq(len(x), 1 / fs)
    def spec(v): return 20 * np.log10(np.abs(np.fft.rfft((v - v.mean()) * w)) / (w.sum() / 2) / 32768 + 1e-9)
    S1, S2 = spec(xf), spec(yf); top = 3 * (np.ceil(max(S1.max(), S2.max()) / 3) + 1)
    a3.plot(f, S1, lw=0.8); a3.set_title('INPUT spectrum'); a4.plot(f, S2, lw=0.8, color='C1'); a4.set_title('FILTERED spectrum')
    a3.set_ylim(top - 90, top)
    for ax in (a3, a4):
        ax.axvspan(lo, hi, color='gray', alpha=0.2, label=f'{lo:.0f}-{hi:.0f} Hz'); ax.set_xlabel('frequency (Hz)'); ax.set_ylabel('dB re full scale'); ax.grid(alpha=.3)
    a3.legend(loc='lower left')
    plt.savefig(a.out + '.png', dpi=110); print(f"saved {a.out}.png")
    if not a.noshow: plt.show()

if __name__ == '__main__':
    main()
