"""
Load a RAM delay over UART, then check word = ram_out.

Protocol:
  1. Prompt for delay D in 0..8191 (13 bits)
  2. Send D as one little-endian 16-bit word  (delay_loader: IDLE -> SEL -> STAY)
  3. RAM wr/rd is done_rx && loaded, so this first word is NOT audio
  4. Then stream samples. Expect:
       n <  D:  y[n] = 0
       n >= D:  y[n] = x[n-D]

Usage:
  python ram_delay_test.py COM9
  python ram_delay_test.py COM9 --delay 3000
  python ram_delay_test.py COM9 --wav audio/clap_mono.wav --out audio/clap_echo.wav
"""

from __future__ import annotations

import argparse
import sys
import wave
from pathlib import Path

import serial
import serial.tools.list_ports

BAUD = 115200
DELAY_MAX = 8191


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


def ask_delay() -> int:
    while True:
        raw = input(f"Delay in samples (0-{DELAY_MAX}): ").strip()
        try:
            if raw.lower().startswith("0x"):
                d = int(raw, 16)
            else:
                d = int(raw, 10)
        except ValueError:
            print("  enter an integer")
            continue
        if not 0 <= d <= DELAY_MAX:
            print(f"  must be 0..{DELAY_MAX} (13 bits)")
            continue
        return d


def send_delay_word(ser: serial.Serial, delay: int) -> None:
    """First UART word: delay_loader latches num. RAM is still disabled."""
    ser.reset_input_buffer()
    ser.write((delay & 0xFFFF).to_bytes(2, byteorder="little"))
    ser.flush()
    raw = ser.read(2)
    if len(raw) == 2:
        rx = int.from_bytes(raw, byteorder="little")
        print(
            f"  delay command sent D={delay}  "
            f"FPGA TX=0x{rx:04X} ({to_signed(rx)})  (ignored, not audio)"
        )
    else:
        print(f"  delay command sent D={delay}  (no FPGA TX, OK if TX is gated by loaded)")
    ser.reset_input_buffer()


def main():
    parser = argparse.ArgumentParser(
        description="UART-load RAM delay, then check y[n]=ram_out"
    )
    parser.add_argument("port", nargs="?", help="COM port (e.g. COM9)")
    parser.add_argument("--baud", type=int, default=BAUD)
    parser.add_argument("--timeout", type=float, default=1.0)
    parser.add_argument(
        "--delay",
        type=int,
        default=None,
        help=f"Skip prompt; delay 0..{DELAY_MAX}",
    )
    parser.add_argument(
        "--extra",
        type=int,
        default=32,
        help="Synth samples after the delay (default 32). Ignored with --wav.",
    )
    parser.add_argument("--wav", default=None, help="16-bit WAV to stream after loading D")
    parser.add_argument("--out", default="ram_delay_echo.wav", help="WAV from FPGA TX")
    parser.add_argument("--seconds", type=float, default=0.0)
    parser.add_argument("--max-samples", type=int, default=0)
    parser.add_argument(
        "--show",
        type=int,
        default=8,
        help="How many fill mismatches to print (default 8)",
    )
    args = parser.parse_args()

    if not args.port:
        list_ports()
        print("\nUsage: python ram_delay_test.py COM9")
        print("       python ram_delay_test.py COM9 --wav audio/clap_mono.wav")
        sys.exit(0)

    if args.delay is None:
        delay = ask_delay()
    else:
        delay = args.delay
        if not 0 <= delay <= DELAY_MAX:
            print(f"--delay must be 0..{DELAY_MAX}")
            sys.exit(1)

    sample_rate = 16000
    if args.wav:
        max_n = None
        xs, sample_rate = load_wav_words(args.wav)
        if args.seconds > 0:
            xs = xs[: int(args.seconds * sample_rate)]
        if args.max_samples > 0:
            xs = xs[: args.max_samples]
        print(f"Using WAV {args.wav}  {len(xs)} samples, expect delay {delay}")
    else:
        n_total = delay + args.extra
        xs = synth_samples(n_total)
        print(f"Using synthetic  {len(xs)} = {delay} fill + {args.extra} check")

    n_total = len(xs)
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
    rx_arr: list[int] = []

    try:
        print(f"Loading delay {delay} into FPGA...")
        send_delay_word(ser, delay)

        for n, tx in enumerate(xs):
            rx = echo_word(ser, tx)
            exp = expected_y(n, xs, delay)
            phase = "FILL" if n < delay else "ECHO"

            if (n + 1) % 1024 == 0 or (n + 1 == delay and delay > 0):
                print(f"  ... {n + 1}/{n_total}  ({phase})")
            if n == delay:
                print(f"  echo  y[n] should be x[n-{delay}]")

            if rx is None:
                timed_out += 1
                rx_arr.append(0)
                if n < delay:
                    pre_fail += 1
                else:
                    post_fail += 1
                print(f"  [{n}] {phase} TIMEOUT  TX=0x{tx:04X}")
                continue

            rx_arr.append(rx)
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
                if (not args.wav) or (not ok and shown < args.show):
                    delayed = xs[n - delay]
                    mark = "OK" if ok else "FAIL"
                    print(
                        f"  [{n}] {mark:4}  "
                        f"x[{n - delay}]=0x{delayed:04X} ({to_signed(delayed):7d})  "
                        f"EXP=0x{exp:04X} ({to_signed(exp):7d})  "
                        f"RX=0x{rx:04X} ({to_signed(rx):7d})"
                    )
                    if not ok:
                        shown += 1
    except KeyboardInterrupt:
        print("\nStopped early.")
    finally:
        ser.close()

    if args.wav and rx_arr:
        write_wav_words(args.out, rx_arr, sample_rate)

    print("\nsummary")
    if delay > 0:
        print(f"  fill  n=0..{delay - 1}:     ok={pre_ok}  fail={pre_fail}")
    print(f"  echo  n={delay}..{n_total - 1}: ok={post_ok}  fail={post_fail}")
    print(f"  timeout: {timed_out}")
    if pre_fail == 0 and post_fail == 0 and timed_out == 0:
        print(f"  PASS  D={delay}: RX=0 for {delay} samples, then x[0], x[1], ...")
    else:
        print("  FAIL  FPGA TX does not match word = ram_out")
        print(f"  (fill 0; after {delay}, y[n] == x[n-{delay}])")
        print("  Press FPGA reset before running again (loader stays in STAY).")


if __name__ == "__main__":
    main()
