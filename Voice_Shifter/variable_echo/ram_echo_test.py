"""
Test RAM delay line: word = ram_out.

write addr = read addr + DELAY  (circular, 8192)
read addr increments once per sample

Model:
  n <  DELAY:  y[n] = 0              (unread / INIT zeros)
  n >= DELAY:  y[n] = x[n-DELAY]

Default DELAY=3000.

Usage:
  python ram_echo_test.py COM9
  python ram_echo_test.py COM9 --delay 3000 --extra 64
  python ram_echo_test.py COM9 --wav audio/clap_mono.wav
"""

from __future__ import annotations

import argparse
import sys
import wave
from pathlib import Path

import serial
import serial.tools.list_ports

BAUD = 115200
DELAY = 3000


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


def to_u16(s: int) -> int:
    return s & 0xFFFF


def expected_y(n: int, xs: list[int], delay: int) -> int:
    if n < delay:
        return 0
    return xs[n - delay] & 0xFFFF


def synth_samples(n: int) -> list[int]:
    out = []
    for i in range(n):
        if i % 8 == 0:
            s = 1000
        elif i % 8 == 1:
            s = -1000
        elif i % 8 == 2:
            s = 20000
        elif i % 8 == 3:
            s = -20000
        else:
            s = ((i * 37) % 4000) - 2000
        out.append(to_u16(s))
    return out


def load_wav_words(path: str | Path, max_n: int) -> list[int]:
    import numpy as np

    with wave.open(str(path), "rb") as wf:
        n_ch = wf.getnchannels()
        width = wf.getsampwidth()
        raw = wf.readframes(wf.getnframes())
    if width != 2:
        raise ValueError("need 16-bit WAV")
    samples = np.frombuffer(raw, dtype=np.int16)
    if n_ch > 1:
        samples = samples.reshape(-1, n_ch)[:, 0]
    return samples.astype(np.uint16).tolist()[:max_n]


def echo_word(ser: serial.Serial, tx: int) -> int | None:
    payload = tx.to_bytes(2, byteorder="little")
    ser.reset_input_buffer()
    ser.write(payload)
    ser.flush()
    raw = ser.read(2)
    if len(raw) < 2:
        return None
    return int.from_bytes(raw, byteorder="little")


def main():
    parser = argparse.ArgumentParser(
        description="Test y[n] = ram_out with delay (default 3000)"
    )
    parser.add_argument("port", nargs="?", help="COM port (e.g. COM9)")
    parser.add_argument("--baud", type=int, default=BAUD)
    parser.add_argument("--timeout", type=float, default=1.0)
    parser.add_argument("--delay", type=int, default=DELAY, help="Read/write address offset")
    parser.add_argument(
        "--extra",
        type=int,
        default=32,
        help="Samples to print/check after the delay (default 32)",
    )
    parser.add_argument("--wav", default=None, help="Optional 16-bit WAV instead of synth")
    parser.add_argument("--seconds", type=float, default=0.0)
    parser.add_argument(
        "--show",
        type=int,
        default=8,
        help="How many fill mismatches to print (default 8)",
    )
    args = parser.parse_args()

    if not args.port:
        list_ports()
        print("\nUsage: python ram_echo_test.py COM9")
        sys.exit(0)

    delay = args.delay
    n_total = delay + args.extra
    if args.wav:
        max_n = n_total
        if args.seconds > 0:
            max_n = max(n_total, int(args.seconds * 16000))
        xs = load_wav_words(args.wav, max_n)
        if len(xs) < n_total:
            print(f"WAV too short ({len(xs)} < {n_total})")
            sys.exit(1)
        xs = xs[:n_total]
        print(f"Using WAV {args.wav}  {n_total} samples")
    else:
        xs = synth_samples(n_total)
        print(f"Using synthetic samples  {n_total} = {delay} fill + {args.extra} check")

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

    pre_ok = pre_fail = post_ok = post_fail = timed_out = 0
    shown = 0

    try:
        for n, tx in enumerate(xs):
            rx = echo_word(ser, tx)
            exp = expected_y(n, xs, delay)
            phase = "FILL" if n < delay else "ECHO"

            if (n + 1) % 1024 == 0 or n + 1 == delay:
                print(f"  ... {n + 1}/{n_total}  ({phase})")
            if n == delay:
                print("  echo  delayed x[n-D] = EXP      vs RX")

            if rx is None:
                timed_out += 1
                if n < delay:
                    pre_fail += 1
                else:
                    post_fail += 1
                print(f"  [{n}] {phase} TIMEOUT  TX=0x{tx:04X}")
                continue

            ok = rx == exp
            if n < delay:
                pre_ok += ok
                pre_fail += not ok
                if not ok and shown < args.show:
                    print(
                        f"  [{n}] FILL FAIL  "
                        f"TX=0x{tx:04X} ({to_signed(tx):6d})  "
                        f"RX=0x{rx:04X} ({to_signed(rx):6d})  "
                        f"EXP=0x0000 (     0)"
                    )
                    shown += 1
            else:
                post_ok += ok
                post_fail += not ok
                delayed = xs[n - delay]
                mark = "OK" if ok else "FAIL"
                print(
                    f"  [{n}] {mark:4}  "
                    f"x[{n - delay}]=0x{delayed:04X} ({to_signed(delayed):7d})  "
                    f"EXP=0x{exp:04X} ({to_signed(exp):7d})  "
                    f"RX=0x{rx:04X} ({to_signed(rx):7d})"
                )
    except KeyboardInterrupt:
        print("\nStopped early.")
    finally:
        ser.close()

    print("\nsummary")
    print(f"  fill  n=0..{delay - 1}:     ok={pre_ok}  fail={pre_fail}")
    print(f"  echo  n={delay}..{n_total - 1}: ok={post_ok}  fail={post_fail}")
    print(f"  timeout: {timed_out}")
    if pre_fail == 0 and post_fail == 0 and timed_out == 0:
        print(f"  PASS  RX=0 for {delay} samples, then x[0], x[1], ...")
    else:
        print("  FAIL  FPGA TX does not match word = ram_out")
        print(f"  (fill should be 0; after {delay}, y[n] should equal x[n-{delay}])")


if __name__ == "__main__":
    main()
