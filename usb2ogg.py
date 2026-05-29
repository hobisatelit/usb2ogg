#!/usr/bin/env python3
# Copyright 2026 hobisatelit
# https://github.com/hobisatelit/
# License: GPL-3.0-or-later


import numpy as np
from scipy import signal
from scipy.io import wavfile
import argparse

def main():
    parser = argparse.ArgumentParser(
        description="Convert raw IQ file (48 kHz sample rate) to USB-demodulated WAV. "
                    "Applies frequency offset adjustment and USB bandwidth filtering."
    )
    parser.add_argument("input_file", help="Input raw IQ file (interleaved I/Q samples)")
    parser.add_argument("output_wav", help="Output WAV file")
    parser.add_argument("--samp_rate", type=int, default=48000, help="Sample rate in Hz (default: 48000)")
    parser.add_argument("--freq_offset", type=float, default=-1230.0, help="Frequency offset adjustment in Hz (default: -1230)")
    parser.add_argument("--bandwidth", type=float, default=5000.0, help="USB bandwidth in Hz (default: 5000)")
    parser.add_argument("--dtype", default="int16", choices=["int16", "float32"], help="Input sample type (default: int16)")
    args = parser.parse_args()

    # Load raw IQ data
    if args.dtype == "int16":
        data = np.fromfile(args.input_file, np.int16)
        iq = (data[::2] + 1j * data[1::2]) / 32768.0
    else:
        data = np.fromfile(args.input_file, np.float32)
        iq = data[::2] + 1j * data[1::2]

    # Frequency shift to correct carrier offset
    n = np.arange(len(iq))
    iq_shifted = iq * np.exp(-2j * np.pi * args.freq_offset / args.samp_rate * n)

    # USB demodulation (extract real part after frequency shift)
    usb_demod = iq_shifted.real

    # Low-pass filter for audio bandwidth
    nyquist = args.samp_rate / 2.0
    normalized_cutoff = args.bandwidth / nyquist
    
    # Clamp cutoff to valid range (0 < cutoff < 1)
    if normalized_cutoff >= 1.0:
        normalized_cutoff = 0.99
    
    sos = signal.butter(4, normalized_cutoff, 'low', output='sos')
    audio = signal.sosfilt(sos, usb_demod)

    # Normalize to 80% of max for headroom
    max_val = np.max(np.abs(audio))
    if max_val > 0:
        audio = np.int16(audio / max_val * 32767 * 0.8)
    else:
        audio = np.int16(audio)

    # Save WAV file with correct sample rate
    wavfile.write(args.output_wav, args.samp_rate, audio)

if __name__ == "__main__":
    main()

