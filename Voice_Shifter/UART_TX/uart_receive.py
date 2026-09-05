"""
Receive UART bytes from Tang Nano 9K (FPGA uart_tx -> USB-UART -> PC).

FPGA side:
  - uart_tx.tx  -> board pin 17 (FPGA_TX)
  - BAUD_RATE   = 115200
  - CLOCK_FREQ  = 27_000_000   # Tang Nano 9K crystal (not 50 MHz!)

PC side: pyserial opens the COM port; the USB-UART chip already decodes
start/data/stop bits. This script just reads bytes and prints them.

Usage:
  python uart_receive.py COM9
  python uart_receive.py COM9 --baud 115200
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


def decode_byte(b: int) -> None:
    bits_msb = f"{b:08b}"
    bits_lsb = " ".join(str((b >> i) & 1) for i in range(8))
    ch = chr(b) if 32 <= b < 127 else "."
    print(
        f"RX  0x{b:02X}  {b:3d}  '{ch}'  "
        f"bin={bits_msb}  LSB-first: {bits_lsb}",
        flush=True,
    )


def main():
    parser = argparse.ArgumentParser(description="Receive UART from Tang Nano 9K")
    parser.add_argument("port", nargs="?", help="Serial port (e.g. COM9)")
    parser.add_argument("--baud", type=int, default=BAUD, help="Baud rate (default 115200)")
    args = parser.parse_args()

    if not args.port:
        list_ports()
        print("\nUsage: python uart_receive.py COM9")
        sys.exit(0)

    print(f"Opening {args.port} at {args.baud} 8N1...")
    try:
        ser = serial.Serial(
            port=args.port,
            baudrate=args.baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.5,
        )
    except serial.SerialException as e:
        print(f"Failed to open port: {e}")
        sys.exit(1)

    print(f"Port reports baud = {ser.baudrate}")
    print("Listening (Ctrl+C to stop)...\n")

    try:
        while True:
            data = ser.read(1)  # blocks up to timeout, returns 0 or 1 byte
            if not data:
                continue
            decode_byte(data[0])
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        ser.close()


if __name__ == "__main__":
    main()
