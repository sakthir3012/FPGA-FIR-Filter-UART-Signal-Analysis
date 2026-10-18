# FIR multimode (LPF / HPF / BPF / BSF) - Nexys A7

SW1:SW0 = mode (00 LPF, 01 HPF, 10 BPF, 11 BSF). SW2 up = bypass (UART echo test). Press BTNC after changing any switch.

## What changed vs. your previous zip
BSF coefficients redesigned: exact zeros forced at 49, 50, 51 Hz (for fs = 200 Hz) so the 50 Hz mains spike disappears
(about -50 dB -> below -100 dB at 49-51 Hz). LPF/HPF/BPF unchanged. The old bitstream is NOT included because it
contains the old BSF, so rebuild first.

## Folders
rtl/          fir_filter_32tap_modes.v, fir_uart_modes_top.v, uart_rx.v, uart_tx.v
tb/           tb_fir_uart_modes_top.v
constraints/  nexys_a7_uart_modes.xdc
scripts/      design_modes.py (generates coefficients), build_modes_batch.tcl
pc/           fir_audio.py (LPF/HPF/audio), fir_bio.py (BPF/BSF demos), fir_modes_coeffs.py, make_bio_demo.py
wav/          netaji_high_frequency_noise.wav (LPF/HPF input), demo_input.wav, eegreal_* (BPF/BSF inputs), S001R02.edf (source EEG)

## Build (Vivado Command Prompt, after settings64.bat)
    cd C:\Users\sakth\FIRFILTER_MULTIMODE
    vivado -mode batch -source scripts\build_modes_batch.tcl
Result: bitstreams\fir_uart_modes.bit. Check that WNS and WHS are positive, then program the board.

## Run (SW2 down, press BTNC before each run)
    python pc\fir_audio.py --port COMx --wav wav\netaji_high_frequency_noise.wav --mode lpf    (SW1:SW0=00)
    python pc\fir_audio.py --port COMx --wav wav\netaji_high_frequency_noise.wav --mode hpf    (SW1:SW0=01)
    python pc\fir_bio.py   --wav wav\eegreal_bpf_40Hz.wav      --mode bpf --port COMx          (SW1:SW0=10)
    python pc\fir_bio.py   --wav wav\eegreal_bsf_200Hz_hum.wav --mode bsf --port COMx          (SW1:SW0=11)
No board: replace --port COMx with --selftest.

## Changing the BSF notch
Edit the null list in scripts\design_modes.py (with_nulls(..., [0.245, 0.25, 0.255]) = 49/50/51 Hz at fs = 200 Hz),
run  python scripts\design_modes.py, then copy the new BSF numbers from pc\fir_modes_coeffs.py into case 2d3 of
rtl\fir_filter_32tap_modes.v (the Verilog is hand-synced).


## Verification notes

The testbench reference model uses the same BSF coefficient values as the current RTL. Re-run the testbench in Vivado before treating the latest RTL/testbench pair as passing. The raw EEG `.edf` dataset is not included; provide a properly licensed input dataset when reproducing the biomedical demo.
