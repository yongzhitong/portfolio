"""
Verify voice_corruptor UART TX against

    y = (GA * x[n-KA] + GB * x[n-KB]) / (2*a - 1)

which is the integer form of y = GA*x[n-KA] + GB*x[n-KB] with
GA+GB = 2*a-1 (the hardware never stores a 0..1 fraction).

Protocol (same as delay_loader / voice_corruptor_wav.py):
  1. Optional prompt for a (13-bit)
  2. Send a as one little-endian 16-bit word  (IDLE -> SEL -> STAY)
  3. Stream samples; each FPGA reply is compared to the model

The model follows KG_controller + down_counter + updown_counter:
  four regions of 2*a samples: RAMP_GA, ONE_GA, RAMP_GB, ONE_GB
  KA, KB fall by 0.5 per sample (subtract 0,1,0,1,...)
  unread RAM is 0 (cleared)

Usage:
  python voice_corruptor_test.py COM9 --a 64 --n 256
  python voice_corruptor_test.py COM9 --a 64 --wav ../audio/clap_mono.wav
  python voice_corruptor_test.py --model-only --a 8 --n 64
"""

from __future__ import annotations

import argparse
import sys
import wave
from pathlib import Path

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    serial = None

BAUD = 115200
A_MIN = 1
A_MAX = 8191
DEPTH = 8192


def list_ports():
    if serial is None:
        print("pyserial is not installed (pip install pyserial)")
        return
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return
    print("Available ports:")
    for p in ports:
        print(f"  {p.device}: {p.description}")


def to_signed(u: int, bits: int = 16) -> int:
    u &= (1 << bits) - 1
    sign = 1 << (bits - 1)
    return u - (1 << bits) if u >= sign else u


def to_u16(s: int) -> int:
    return s & 0xFFFF


def div_towards_zero(num: int, den: int) -> int:
    """Verilog signed / truncates toward 0 (Python // floors)."""
    if den == 0:
        return 0
    q = abs(num) // abs(den)
    return -q if (num < 0) ^ (den < 0) else q


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


class VoiceCorruptorModel:
    """Cycle-accurate enough for one UART sample per KG/RAM step."""

    STATES = ("RAMP_GA", "ONE_GA", "RAMP_GB", "ONE_GB")

    def __init__(self, a: int):
        if a < 1:
            raise ValueError("a must be >= 1")
        self.a = a
        self.den = 2 * a - 1
        self.region_len = 2 * a
        self.xs: list[int] = []
        self.KA = 3 * a - 1
        self.KB = a - 1
        self.GA = 0
        self.GB = self.den
        self.dec_a = 0
        self.dec_b = 0
        self.state = "RAMP_GA"
        self.in_region = 0
        self.n = 0

    def _sample(self, idx: int) -> int:
        if idx < 0 or idx >= len(self.xs):
            return 0
        return to_signed(self.xs[idx], 16)

    def peek(self) -> dict:
        return {
            "n": self.n,
            "state": self.state,
            "KA": self.KA,
            "KB": self.KB,
            "GA": self.GA,
            "GB": self.GB,
        }

    def _step_delay(self, k: int, dec: int) -> tuple[int, int]:
        if k != 0:
            k = k - dec
            if k < 0:
                k = 0
        return k, dec ^ 1

    def _step_gains(self) -> None:
        max_g = self.den
        if self.state in ("RAMP_GA", "ONE_GA"):
            if self.GA < max_g:
                self.GA += 1
            if self.GB > 0:
                self.GB -= 1
        else:
            if self.GA > 0:
                self.GA -= 1
            if self.GB < max_g:
                self.GB += 1

    def _enter(self, state: str) -> None:
        self.state = state
        self.in_region = 0
        if state == "RAMP_GA":
            self.KA = 3 * self.a - 1
            self.KB = self.a - 1
            self.dec_a = 0
            self.dec_b = 0
            self.GA = 0
            self.GB = self.den
        elif state == "RAMP_GB":
            self.KB = 3 * self.a - 1
            self.dec_b = 0

    def step(self, x_u16: int) -> tuple[int, dict]:
        info = self.peek()
        self.xs.append(x_u16)
        xa = self._sample(self.n - self.KA)
        xb = self._sample(self.n - self.KB)
        info["xa"] = xa
        info["xb"] = xb

        ga = to_signed(self.GA, 13)
        gb = to_signed(self.GB, 13)
        acc = ga * xa + gb * xb
        y = to_u16(div_towards_zero(acc, self.den))
        info["exp"] = y

        self.n += 1

        self.KA, self.dec_a = self._step_delay(self.KA, self.dec_a)
        self.KB, self.dec_b = self._step_delay(self.KB, self.dec_b)
        self._step_gains()

        self.in_region += 1
        if self.in_region >= self.region_len:
            i = self.STATES.index(self.state)
            self._enter(self.STATES[(i + 1) % 4])

        return y, info


def echo_word(ser: serial.Serial, tx: int) -> int | None:
    payload = tx.to_bytes(2, byteorder="little")
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
            a = int(raw, 16) if raw.lower().startswith("0x") else int(raw, 10)
        except ValueError:
            print("  enter an integer")
            continue
        if not A_MIN <= a <= A_MAX:
            print(f"  must be {A_MIN}..{A_MAX} (13 bits)")
            continue
        return a


def send_a_word(ser: serial.Serial, a: int) -> None:
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


def print_ctrl_table(model: VoiceCorruptorModel, xs: list[int], n_show: int) -> None:
    print("  n  state     KA   KB   GA   GB     y")
    tmp = VoiceCorruptorModel(model.a)
    for i, tx in enumerate(xs[:n_show]):
        y, info = tmp.step(tx)
        print(
            f"{info['n']:3d}  {info['state']:8} "
            f"{info['KA']:4d} {info['KB']:4d} {info['GA']:4d} {info['GB']:4d}  "
            f"{to_signed(y):7d}"
        )


def main():
    parser = argparse.ArgumentParser(
        description="Check FPGA y against (GA*x[n-KA]+GB*x[n-KB])/(2a-1)"
    )
    parser.add_argument("port", nargs="?", help="COM port (e.g. COM9)")
    parser.add_argument("--baud", type=int, default=BAUD)
    parser.add_argument("--timeout", type=float, default=1.0)
    parser.add_argument("--a", type=int, default=None, dest="a_val")
    parser.add_argument("--n", type=int, default=256, help="Synth length if no --wav")
    parser.add_argument("--wav", default=None)
    parser.add_argument("--out", default=None, help="Optional WAV of FPGA RX")
    parser.add_argument("--seconds", type=float, default=0.0)
    parser.add_argument("--max-samples", type=int, default=0)
    parser.add_argument("--show", type=int, default=12, help="Mismatches to print")
    parser.add_argument(
        "--dump-ctrl",
        type=int,
        default=0,
        help="Print first N model (state,K,G,y) rows",
    )
    parser.add_argument(
        "--model-only",
        action="store_true",
        help="Run the golden model only (no serial)",
    )
    args = parser.parse_args()

    if not args.model_only and not args.port:
        list_ports()
        print("\nUsage: python voice_corruptor_test.py COM9 --a 64 --n 256")
        sys.exit(0)

    if args.a_val is None:
        if args.model_only:
            print("Need --a with --model-only")
            sys.exit(1)
        a = ask_a()
    else:
        a = args.a_val
        if not A_MIN <= a <= A_MAX:
            print(f"--a must be {A_MIN}..{A_MAX}")
            sys.exit(1)

    rate = 10000
    if args.wav:
        xs, rate = load_wav_words(args.wav)
        if args.seconds > 0:
            xs = xs[: int(args.seconds * rate)]
        if args.max_samples > 0:
            xs = xs[: args.max_samples]
        print(f"Using WAV {args.wav}  {len(xs)} samples @ {rate} Hz  a={a}")
    else:
        n_total = args.n
        if args.max_samples > 0:
            n_total = args.max_samples
        xs = synth_samples(n_total)
        print(f"Using synthetic  {len(xs)} samples  a={a}  region=2a={2 * a}")

    if 2 * a - 1 >= 4096:
        print("  note: 2a-1 >= 4096; 13-bit signed GA/GB wrap negative on FPGA")

    model = VoiceCorruptorModel(a)
    if args.dump_ctrl or args.model_only:
        n_show = args.dump_ctrl if args.dump_ctrl > 0 else min(len(xs), 4 * 2 * a)
        print_ctrl_table(model, xs, n_show)

    if args.model_only:
        out_path = args.out or "../audio/voice_corrupt_model.wav"
        tmp = VoiceCorruptorModel(a)
        ys = [tmp.step(x)[0] for x in xs]
        write_wav_words(out_path, ys, rate)
        print("  model-only done (no FPGA)")
        return

    if serial is None:
        print("pyserial is not installed (pip install pyserial)")
        sys.exit(1)

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

    ok = fail = timed_out = 0
    shown = 0
    rx_arr: list[int] = []

    try:
        print(f"Loading a={a} into FPGA...")
        send_a_word(ser, a)

        print("Streaming and checking y = (GA*xA + GB*xB)/(2a-1) ...")
        for n, tx in enumerate(xs):
            exp, info = model.step(tx)
            rx = echo_word(ser, tx)

            if (n + 1) % 1024 == 0 or n + 1 == len(xs):
                print(f"  ... {n + 1}/{len(xs)}  ok={ok}  fail={fail}  timeout={timed_out}")

            if rx is None:
                timed_out += 1
                fail += 1
                rx_arr.append(0)
                if shown < args.show:
                    print(f"  [{n}] TIMEOUT  TX=0x{tx:04X}")
                    shown += 1
                continue

            rx_arr.append(rx)
            if rx == exp:
                ok += 1
                continue

            fail += 1
            if shown < args.show:
                print(
                    f"  [{n}] FAIL {info['state']:8}  "
                    f"KA={info['KA']} KB={info['KB']} GA={info['GA']} GB={info['GB']}  "
                    f"xA={info['xa']:7d} xB={info['xb']:7d}  "
                    f"EXP={to_signed(exp):7d}  RX={to_signed(rx):7d}"
                )
                shown += 1
    except KeyboardInterrupt:
        print("\nStopped early.")
    finally:
        ser.close()

    if args.out and rx_arr:
        write_wav_words(args.out, rx_arr, rate)

    print("\nsummary")
    print(f"  a={a}  den=2a-1={2 * a - 1}  region=2a={2 * a}")
    print(f"  ok={ok}  fail={fail}  timeout={timed_out}  sent={len(xs)}")
    if fail == 0 and timed_out == 0 and ok == len(xs):
        print("  PASS  FPGA y matches (GA*x[n-KA] + GB*x[n-KB])/(2a-1)")
    else:
        print("  FAIL  RX != model")
        print("  Press FPGA reset before running again (loader stays in STAY).")


if __name__ == "__main__":
    main()
