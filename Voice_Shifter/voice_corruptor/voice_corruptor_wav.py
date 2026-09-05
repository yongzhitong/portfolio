"""
Load parameter a over UART, then stream a WAV through the voice corruptor.

Protocol (same as delay_loader):
  1. Prompt for a (13-bit, 1..8191)
  2. Send a as one little-endian 16-bit word  (IDLE -> SEL -> STAY)
  3. Stream WAV samples; write FPGA replies to --out
  4. No value checking — only report TX/RX success vs timeout

Usage:
  python voice_corruptor_wav.py COM9 --wav ../audio/clap_mono.wav
  python voice_corruptor_wav.py COM9 --wav ../audio/hello.wav --out ../audio/hello_corrupt.wav
  python voice_corruptor_wav.py COM9 --a 64 --wav ../audio/clap_mono.wav
"""

from __future__ import annotations

import argparse
import sys
import wave
from pathlib import Path

import serial
import serial.tools.list_ports

BAUD = 115200
A_MIN = 1
A_MAX = 8191


def list_ports():
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return
    print("Available ports:")
    for p in ports:
        print(f"  {p.device}: {p.description}")


def to_signed(u: int) -> int:
    u &= 0xFFFF
    return u - 0x10000 if u >= 0x8000 else u


def load_wav_words(path: str | Path, max_n: int | None = None) -> tuple[list[int], int]:
    import numpy as np

    with wave.open(str(path), "rb") as wf:
        n_ch = wf.getnchannels()
        width = wf.getsampwidth()
        rate = wf.getframerate()
        raw = wf.readframes(wf.getnframes())
    if width != 2:
        raise ValueError("need 16-bit WAV")
    samples = np.frombuffer(raw, dtype=np.int16)
    if n_ch > 1:
        samples = samples.reshape(-1, n_ch)[:, 0]
        print(f"  using channel 0 of {n_ch}")
    words = samples.astype(np.uint16).tolist()
    if max_n is not None:
        words = words[:max_n]
    return words, rate


def write_wav_words(path: str | Path, words: list[int], sample_rate: int) -> None:
    import numpy as np

    path = Path(path)
    samples = np.array(words, dtype=np.uint16).astype(np.int16)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(samples.tobytes())
    print(f"  wrote {path}  ({len(words)} samples, {sample_rate} Hz)")


def echo_word(ser: serial.Serial, tx: int) -> int | None:
    payload = tx.to_bytes(2, byteorder="little")
    ser.reset_input_buffer()
    ser.write(payload)
    ser.flush()
    raw = ser.read(2)
    if len(raw) < 2:
        return None
    return int.from_bytes(raw, byteorder="little")


def ask_a() -> int:
    while True:
        raw = input(f"a ({A_MIN}-{A_MAX}): ").strip()
        try:
            if raw.lower().startswith("0x"):
                a = int(raw, 16)
            else:
                a = int(raw, 10)
        except ValueError:
            print("  enter an integer")
            continue
        if not A_MIN <= a <= A_MAX:
            print(f"  must be {A_MIN}..{A_MAX} (13 bits)")
            continue
        return a


def send_a_word(ser: serial.Serial, a: int) -> None:
    """First UART word: loader latches a in SEL. Not audio."""
    ser.reset_input_buffer()
    ser.write((a & 0xFFFF).to_bytes(2, byteorder="little"))
    ser.flush()
    raw = ser.read(2)
    if len(raw) == 2:
        rx = int.from_bytes(raw, byteorder="little")
        print(
            f"  a command sent a={a}  "
            f"FPGA TX=0x{rx:04X} ({to_signed(rx)})  (ignored, not audio)"
        )
    else:
        print(f"  a command sent a={a}  (no FPGA TX, OK if TX is gated by loaded)")
    ser.reset_input_buffer()


def main():
    parser = argparse.ArgumentParser(
        description="UART-load a, stream WAV through voice_corruptor (no value check)"
    )
    parser.add_argument("port", nargs="?", help="COM port (e.g. COM9)")
    parser.add_argument("--baud", type=int, default=BAUD)
    parser.add_argument("--timeout", type=float, default=1.0)
    parser.add_argument(
        "--a",
        type=int,
        default=None,
        dest="a_val",
        help=f"Skip prompt; a in {A_MIN}..{A_MAX}",
    )
    parser.add_argument(
        "--wav",
        default=None,
        help="16-bit WAV to stream after loading a",
    )
    parser.add_argument(
        "--out",
        default="../audio/voice_corrupt.wav",
        help="WAV from FPGA TX (default ../audio/voice_corrupt.wav)",
    )
    parser.add_argument("--seconds", type=float, default=0.0)
    parser.add_argument("--max-samples", type=int, default=0)
    parser.add_argument(
        "--show",
        type=int,
        default=8,
        help="How many timeouts to print (default 8)",
    )
    args = parser.parse_args()

    if not args.port:
        list_ports()
        print("\nUsage: python voice_corruptor_wav.py COM9 --wav ../audio/clap_mono.wav")
        sys.exit(0)

    if not args.wav:
        print("Need --wav path to a 16-bit WAV")
        sys.exit(1)

    if args.a_val is None:
        a = ask_a()
    else:
        a = args.a_val
        if not A_MIN <= a <= A_MAX:
            print(f"--a must be {A_MIN}..{A_MAX}")
            sys.exit(1)

    xs, sample_rate = load_wav_words(args.wav)
    if args.seconds > 0:
        xs = xs[: int(args.seconds * sample_rate)]
        print(f"  limited to {args.seconds}s = {len(xs)} samples")
    if args.max_samples > 0:
        xs = xs[: args.max_samples]
        print(f"  limited to {len(xs)} samples")

    n_total = len(xs)
    print(f"Using WAV {args.wav}  {n_total} samples @ {sample_rate} Hz  a={a}")
    print(f"Opening {args.port} at {args.baud}...")
    try:
        ser = serial.Serial(
            port=args.port,
            baudrate=args.baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=args.timeout,
        )
    except serial.SerialException as e:
        print(f"Failed to open port: {e}")
        sys.exit(1)

    ser.reset_input_buffer()
    ser.reset_output_buffer()

    received = timed_out = 0
    shown = 0
    rx_arr: list[int] = []

    try:
        print(f"Loading a={a} into FPGA...")
        send_a_word(ser, a)

        print("Streaming WAV (no value check)...")
        for n, tx in enumerate(xs):
            rx = echo_word(ser, tx)

            if (n + 1) % 1024 == 0 or n + 1 == n_total:
                print(
                    f"  ... {n + 1}/{n_total}  "
                    f"ok={received}  timeout={timed_out}"
                )

            if rx is None:
                timed_out += 1
                rx_arr.append(0)
                if shown < args.show:
                    print(f"  [{n}] TIMEOUT  TX=0x{tx:04X} ({to_signed(tx):6d})")
                    shown += 1
                continue

            received += 1
            rx_arr.append(rx)
    except KeyboardInterrupt:
        print("\nStopped early.")
    finally:
        ser.close()

    if rx_arr:
        write_wav_words(args.out, rx_arr, sample_rate)

    print("\nsummary")
    print(f"  a={a}")
    print(f"  sent     {n_total}")
    print(f"  received {received}  (OK)")
    print(f"  timeout  {timed_out}  (FAIL)")
    if timed_out == 0 and received == n_total:
        print(f"  PASS  every sample echoed → {args.out}")
    else:
        print("  FAIL  some samples timed out (those are silence in the output WAV)")
        print("  Press FPGA reset before running again (loader stays in STAY).")


if __name__ == "__main__":
    main()
