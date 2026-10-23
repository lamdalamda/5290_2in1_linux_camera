#!/usr/bin/env python3
"""Talk to the Realtek register-access extension unit of the 5290 IR camera.

The IR camera (USB 0bda:551a) has a Realtek extension unit with GUID
1229a78c-47b4-4094-b0ce-db07386fb938 and two 8-byte controls:

  selector 0x0a  command/address: SET_CUR "00 a1 a2 a3 len 00 00 00" selects a
                 register address and length, "ff 00 .." runs a command
  selector 0x0b  data: GET_CUR reads the selected register, SET_CUR writes it

Protocol from https://github.com/SeeleVolleri/research_0jcxg0 (USB capture of
the Windows driver on a Dell Realtek camera).

Usage:
  rtk-ir.py probe [DEVICE]    read identification registers and 0x9f00 (no writes
                              to data registers)
"""
import ctypes
import fcntl
import glob
import os
import struct
import sys

UVCIOC_CTRL_QUERY = 0xC0107521
SET_CUR = 0x01
GET_CUR = 0x81
GET_LEN = 0x85

XU_GUID = "1229a78c-47b4-4094-b0ce-db07386fb938"
SEL_ADDR = 0x0A
SEL_DATA = 0x0B


def find_device():
    for path in sorted(glob.glob("/dev/v4l/by-id/*Integrated_Webcam_HD*-video-index0")):
        return path
    sys.exit("IR camera not found under /dev/v4l/by-id")


def find_unit(dev):
    """Return the unit ID of the Realtek XU from the USB descriptor in sysfs."""
    real = os.path.realpath(dev)
    intf = os.path.realpath(f"/sys/class/video4linux/{os.path.basename(real)}/device")
    usbdev = os.path.dirname(intf)
    with open(os.path.join(usbdev, "descriptors"), "rb") as f:
        desc = f.read()
    guid = bytes.fromhex(XU_GUID.replace("-", ""))
    # GUIDs are stored little-endian for the first three fields
    guid = guid[3::-1] + guid[5:3:-1] + guid[7:5:-1] + guid[8:]
    i = 0
    while i + 2 < len(desc):
        length, dtype = desc[i], desc[i + 1]
        if length == 0:
            break
        # CS_INTERFACE (0x24), VC_EXTENSION_UNIT (0x06)
        if dtype == 0x24 and desc[i + 2] == 0x06 and desc[i + 4:i + 20] == guid:
            return desc[i + 3]
        i += length
    sys.exit(f"Extension unit {XU_GUID} not found on {dev}")


class Xu:
    def __init__(self, dev):
        self.dev = dev
        self.unit = find_unit(dev)
        self.fd = os.open(dev, os.O_RDWR)

    def query(self, sel, q, data=None, size=8):
        buf = ctypes.create_string_buffer(bytes(data) if data else bytes(size), size)
        arg = struct.pack("BBBxHxxP", self.unit, sel, q, size, ctypes.addressof(buf))
        fcntl.ioctl(self.fd, UVCIOC_CTRL_QUERY, bytearray(arg))
        return buf.raw

    def select(self, addr_bytes, length):
        self.query(SEL_ADDR, SET_CUR, [0x00, *addr_bytes, length, 0, 0, 0][:8])

    def read(self, addr_bytes, length):
        self.select(addr_bytes, length)
        return self.query(SEL_DATA, GET_CUR)[:length]


def hexs(b):
    return " ".join(f"{x:02x}" for x in b)


def probe(dev):
    xu = Xu(dev)
    print(f"device {dev} -> {os.path.realpath(dev)}, extension unit {xu.unit}")
    for sel in (SEL_ADDR, SEL_DATA):
        print(f"selector 0x{sel:02x} length {struct.unpack('<H', xu.query(sel, GET_LEN, size=2))[0]}")
    print(f"0x0a current      {hexs(xu.query(SEL_ADDR, GET_CUR))}   (research: 00 08 00 bb bb bb bb bb)")

    # Same order as the Windows driver: reset the command register, then read.
    xu.query(SEL_ADDR, SET_CUR, [0xFF, 0, 0, 0, 0, 0, 0, 0])
    regs = [
        ("cd00 device id", (0xCD, 0x00, 0x00), 8, "da 0b 75 58 22 42 10 10"),
        ("cd01 hw version", (0xCD, 0x01, 0x00), 8, "07 12 01 c0 00 00 01 00"),
        ("cd02 fw date", (0xCD, 0x02, 0x00), 8, "30 38 2f 31 38 2f 31 35"),
        ("cd04 config", (0xCD, 0x04, 0x00), 8, "01 00 10 01 00 00 00 00"),
        ("cd08 ext caps", (0xCD, 0x08, 0x00), 8, "11 80 01 10 22 42 81 81"),
        ("d000 vendor", (0xD0, 0x00, 0x00), 8, "52 45 41 4c 53 49 4c 00"),
        ("9f00 ir mode", (0x9F, 0x00, 0x00), 1, "(not read by Windows)"),
    ]
    for name, addr, length, ref in regs:
        try:
            val = xu.read(addr, length)
        except OSError as e:
            print(f"{name:16s} error {e.errno} ({e.strerror})")
            continue
        text = "".join(chr(c) if 32 <= c < 127 else "." for c in val)
        print(f"{name:16s} {hexs(val):24s} {text!r:12s} research: {ref}")


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__)
        return
    cmd = sys.argv[1]
    dev = sys.argv[2] if len(sys.argv) > 2 else find_device()
    if cmd == "probe":
        probe(dev)
    else:
        sys.exit(f"unknown command {cmd}")


if __name__ == "__main__":
    main()
