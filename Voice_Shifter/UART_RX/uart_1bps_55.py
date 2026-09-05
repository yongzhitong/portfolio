"""
Interactive UART sender for Tang Nano 9K (115200 8N1).

Type a hex value and press Enter to send it once.
Examples: 55   0x55   A5   0xff

Usage:
  python uart_1bps_55.py COM9
"""

import argparse
import sys

import serial
import serial.tools.list_ports

BAUD = 115200


def list_ports():
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return
    print("Available ports:")
    for p in ports:
        print(f"  {p.device}: {p.description}")


def parse_hex_byte(text: str) -> int:
    """Parse a hex byte from user input. Accepts '55', '0x55', '0X55'."""
    s = text.strip().lower()
    if not s:
        raise ValueError("empty")
    if s.startswith("0x"):
        value = int(s, 16)
    else:
        value = int(s, 16)
    if not 0 <= value <= 0xFF:
        raise ValueError("must be a single byte (0x00 .. 0xFF)")
    return value


def show_and_send(ser: serial.Serial, data: int) -> None:
    bits_msb = f"{data:08b}"
    bits_lsb = " ".join(str((data >> i) & 1) for i in range(8))
    print(f"  hex:    0x{data:02X}")
    print(f"  binary: 0b{bits_msb}  (MSB left)")
    print(f"  wire:   {bits_lsb}  (LSB first on UART)")
    ser.write(bytes([data]))
    ser.flush()
    print("  sent once.\n")


def main():
    parser = argparse.ArgumentParser(description="Type hex bytes to send at 115200 8N1")
    parser.add_argument("port", nargs="?", help="Serial port (e.g. COM9)")
    args = parser.parse_args()

    if not args.port:
        list_ports()
        print("\nUsage: python uart_1bps_55.py COM9")
        sys.exit(0)

    print(f"Opening {args.port} at {BAUD} 8N1...")
    try:
        ser = serial.Serial(port=args.port, baudrate=BAUD, timeout=1)
    except serial.SerialException as e:
        print(f"Failed to open port: {e}")
        sys.exit(1)

    print(f"Port reports baud = {ser.baudrate}")
    print("Enter a hex byte (e.g. 55 or 0xA5) and press Enter to send once.")
    print("Empty line or 'q' to quit.\n")

    try:
        while True:
            try:
                text = input("hex> ")
            except EOFError:
                break

            if text.strip() == "" or text.strip().lower() in ("q", "quit", "exit"):
                break

            try:
                data = parse_hex_byte(text)
            except ValueError as e:
                print(f"  invalid input ({e}). Try e.g. 55 or 0xA5\n")
                continue

            show_and_send(ser, data)
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        ser.close()


if __name__ == "__main__":
    main()
