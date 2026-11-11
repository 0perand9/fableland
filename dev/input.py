#!/usr/bin/env python3
"""A virtual pointer and keyboard for the headless compositor used by dev/shot.

A headless compositor has no input devices, so its clients never see a pointer
or keyboard. This connects as a Wayland client, creates one of each through the
wlr-virtual-pointer and virtual-keyboard protocols and keeps them alive, then
performs the actions it reads from stdin (one per line, answering "ok"):

    move X Y | click X Y | rclick X Y | mclick X Y | hold X Y SECONDS | drag X1 Y1 X2 Y2
    scroll N | type TEXT | key [mod+...]NAME

It speaks the wire protocol directly, so it needs nothing but Python.
usage: input.py <wayland-display> <width> <height>
"""

import array
import os
import socket
import struct
import subprocess
import sys
import time

BUTTONS = {"left": 0x110, "right": 0x111, "middle": 0x112}
MODIFIERS = {"shift": (42, 1), "ctrl": (29, 4), "alt": (56, 8), "super": (125, 64)}
NAMED_KEYS = {
    "escape": 1, "backspace": 14, "tab": 15, "return": 28, "enter": 28, "space": 57,
    "home": 102, "up": 103, "page_up": 104, "left": 105, "right": 106, "end": 107,
    "down": 108, "page_down": 109, "insert": 110, "delete": 111,
    **{f"f{n}": 58 + n for n in range(1, 11)}, "f11": 87, "f12": 88,
}
# Evdev key codes of a US keyboard: plain characters and the ones typed with shift.
PLAIN = dict(zip("1234567890-=", range(2, 14))) | dict(zip("qwertyuiop[]", range(16, 28))) \
    | dict(zip("asdfghjkl;'`", range(30, 42))) | dict(zip("\\zxcvbnm,./", range(43, 54))) | {" ": 57, "\n": 28, "\t": 15}
SHIFTED = dict(zip('!@#$%^&*()_+', range(2, 14))) | dict(zip("QWERTYUIOP{}", range(16, 28))) \
    | dict(zip('ASDFGHJKL:"~', range(30, 42))) | dict(zip("|ZXCVBNM<>?", range(43, 54)))


def wl_string(text):
    data = text.encode() + b"\0"
    return struct.pack("<I", len(data)) + data + b"\0" * (-len(data) % 4)


class Wayland:
    def __init__(self, display):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], display))
        self.last_id = 1
        self.pending = b""
        self.globals = {}

    def new_id(self):
        self.last_id += 1
        return self.last_id

    def send(self, obj, opcode, payload=b"", fd=None):
        message = struct.pack("<IHH", obj, opcode, 8 + len(payload)) + payload
        if fd is None:
            self.sock.sendall(message)
        else:
            self.sock.sendmsg([message], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", [fd]))])

    def events(self):
        """Read whatever the compositor sent: yields (object, opcode, payload)."""
        self.pending += self.sock.recv(65536)
        while len(self.pending) >= 8:
            obj, opcode, size = struct.unpack("<IHH", self.pending[:8])
            if len(self.pending) < size:
                break
            payload, self.pending = self.pending[8:size], self.pending[size:]
            yield obj, opcode, payload

    def roundtrip(self, registry=None):
        """Wait until the compositor has processed everything sent so far."""
        callback = self.new_id()
        self.send(1, 0, struct.pack("<I", callback))  # wl_display.sync
        while True:
            for obj, opcode, payload in self.events():
                if obj == callback:
                    return
                if obj == 1 and opcode == 0:  # wl_display.error
                    length = struct.unpack("<I", payload[8:12])[0]
                    sys.exit("wayland error: " + payload[12:12 + length - 1].decode())
                if obj == registry and opcode == 0:  # wl_registry.global
                    name, length = struct.unpack("<II", payload[:8])
                    interface = payload[8:8 + length - 1].decode()
                    version = struct.unpack("<I", payload[8 + length + (-length % 4):][:4])[0]
                    self.globals[interface] = (name, version)

    def bind(self, registry, interface, version=1):
        if interface not in self.globals:
            sys.exit(f"the compositor does not support {interface}")
        obj = self.new_id()
        self.send(registry, 0, struct.pack("<I", self.globals[interface][0]) + wl_string(interface) + struct.pack("<II", version, obj))
        return obj


class Input:
    def __init__(self, display, width, height):
        self.width, self.height = width, height
        self.wl = wl = Wayland(display)
        registry = wl.new_id()
        wl.send(1, 1, struct.pack("<I", registry))  # wl_display.get_registry
        wl.roundtrip(registry)

        # Object ids must be handed out in order, so each object is created right after its id.
        seat = wl.bind(registry, "wl_seat")
        pointers = wl.bind(registry, "zwlr_virtual_pointer_manager_v1")
        keyboards = wl.bind(registry, "zwp_virtual_keyboard_manager_v1")
        self.pointer = wl.new_id()
        wl.send(pointers, 0, struct.pack("<II", seat, self.pointer))
        self.keyboard = wl.new_id()
        wl.send(keyboards, 0, struct.pack("<II", seat, self.keyboard))

        keymap = subprocess.run(["xkbcli", "compile-keymap", "--layout", "us"], capture_output=True, check=True).stdout + b"\0"
        fd = os.memfd_create("keymap")
        os.write(fd, keymap)
        wl.send(self.keyboard, 0, struct.pack("<II", 1, len(keymap)), fd=fd)  # keymap(xkb_v1, fd, size)
        os.close(fd)
        wl.roundtrip()

    @staticmethod
    def now():
        return int(time.monotonic() * 1000) & 0xFFFFFFFF

    def flush(self):
        self.wl.roundtrip()
        time.sleep(0.03)

    # ── pointer ──

    def move(self, x, y):
        self.wl.send(self.pointer, 1, struct.pack("<IIIII", self.now(), int(x), int(y), self.width, self.height))  # motion_absolute
        self.wl.send(self.pointer, 4)  # frame
        self.flush()

    def button(self, name, pressed):
        self.wl.send(self.pointer, 2, struct.pack("<III", self.now(), BUTTONS[name], 1 if pressed else 0))
        self.wl.send(self.pointer, 4)
        self.flush()

    def click(self, name, x, y):
        self.move(x, y)
        self.button(name, True)
        self.button(name, False)

    def hold(self, x, y, seconds):
        self.move(x, y)
        self.button("left", True)
        time.sleep(seconds)
        self.button("left", False)

    def drag(self, x1, y1, x2, y2):
        self.move(x1, y1)
        self.button("left", True)
        for step in range(1, 9):
            self.move(x1 + (x2 - x1) * step / 8, y1 + (y2 - y1) * step / 8)
        self.button("left", False)

    def scroll(self, notches):
        step = 1 if notches > 0 else -1
        for _ in range(abs(notches)):
            self.wl.send(self.pointer, 5, struct.pack("<I", 0))  # axis_source(wheel)
            self.wl.send(self.pointer, 7, struct.pack("<IIii", self.now(), 0, step * 15 * 256, step))  # axis_discrete(vertical)
            self.wl.send(self.pointer, 4)
            self.flush()

    # ── keyboard ──

    def press(self, code, mods=()):
        mask = 0
        for mod in mods:
            key, bit = MODIFIERS[mod]
            mask |= bit
            self.wl.send(self.keyboard, 1, struct.pack("<III", self.now(), key, 1))
        self.wl.send(self.keyboard, 2, struct.pack("<IIII", mask, 0, 0, 0))  # modifiers
        self.wl.send(self.keyboard, 1, struct.pack("<III", self.now(), code, 1))
        self.wl.send(self.keyboard, 1, struct.pack("<III", self.now(), code, 0))
        for mod in mods:
            self.wl.send(self.keyboard, 1, struct.pack("<III", self.now(), MODIFIERS[mod][0], 0))
        self.wl.send(self.keyboard, 2, struct.pack("<IIII", 0, 0, 0, 0))
        self.flush()

    def type(self, text):
        for char in text:
            if char in PLAIN:
                self.press(PLAIN[char])
            elif char in SHIFTED:
                self.press(SHIFTED[char], ["shift"])
            else:
                sys.exit(f"cannot type {char!r} (US keyboard characters only)")

    def key(self, spec):
        *mods, name = spec.split("+")
        code = NAMED_KEYS.get(name.lower()) or PLAIN.get(name.lower())
        if code is None or any(m.lower() not in MODIFIERS for m in mods):
            sys.exit(f"unknown key {spec!r}")
        self.press(code, [m.lower() for m in mods])


def main():
    inp = Input(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
    print("ok", flush=True)
    for line in sys.stdin:
        action, _, rest = line.rstrip("\n").partition(" ")
        args = rest.split()
        if action == "move":
            inp.move(float(args[0]), float(args[1]))
        elif action in ("click", "rclick", "mclick"):
            inp.click({"click": "left", "rclick": "right", "mclick": "middle"}[action], float(args[0]), float(args[1]))
        elif action == "hold":
            inp.hold(*map(float, args[:3]))
        elif action == "drag":
            inp.drag(*map(float, args[:4]))
        elif action == "scroll":
            inp.scroll(int(args[0]))
        elif action == "type":
            inp.type(rest)
        elif action == "key":
            inp.key(args[0])
        else:
            sys.exit(f"unknown action {action!r}")
        print("ok", flush=True)


if __name__ == "__main__":
    main()
