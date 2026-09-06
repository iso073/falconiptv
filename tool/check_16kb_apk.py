#!/usr/bin/env python3
"""Fail if a 64-bit .so inside an APK has PT_LOAD alignment below 16 KB."""

from __future__ import annotations

import struct
import sys
import zipfile
from pathlib import Path

PT_LOAD = 1
MIN_ALIGN = 16384
CHECKED_ABIS = ("arm64-v8a", "x86_64")


def load_alignments(data: bytes) -> list[int]:
    if data[:4] != b"\x7fELF":
        raise ValueError("not an ELF file")
    elf64 = data[4] == 2
    little = data[5] == 1
    endian = "<" if little else ">"
    if elf64:
        e_phoff = struct.unpack_from(f"{endian}Q", data, 32)[0]
        e_phentsize, e_phnum = struct.unpack_from(f"{endian}HH", data, 54)
        align_off = 48
        align_fmt = "Q"
    else:
        e_phoff = struct.unpack_from(f"{endian}I", data, 28)[0]
        e_phentsize, e_phnum = struct.unpack_from(f"{endian}HH", data, 42)
        align_off = 28
        align_fmt = "I"
    aligns: list[int] = []
    for index in range(e_phnum):
        offset = e_phoff + index * e_phentsize
        p_type = struct.unpack_from(f"{endian}I", data, offset)[0]
        if p_type != PT_LOAD:
            continue
        p_align = struct.unpack_from(f"{endian}{align_fmt}", data, offset + align_off)[0]
        aligns.append(p_align)
    return aligns


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_16kb_apk.py <apk>", file=sys.stderr)
        return 2
    apk_path = Path(sys.argv[1])
    if not apk_path.is_file():
        print(f"APK yok: {apk_path}", file=sys.stderr)
        return 2

    failed: list[str] = []
    checked = 0
    with zipfile.ZipFile(apk_path) as archive:
        for name in archive.namelist():
            if not name.startswith("lib/") or not name.endswith(".so"):
                continue
            parts = name.split("/")
            if len(parts) < 3 or parts[1] not in CHECKED_ABIS:
                continue
            data = archive.read(name)
            aligns = load_alignments(data)
            checked += 1
            bad = [align for align in aligns if align < MIN_ALIGN]
            status = "OK" if not bad else "FAIL"
            print(f"{status} {name} align={aligns}")
            if bad:
                failed.append(name)

    if checked == 0:
        print("64-bit .so bulunamadı.", file=sys.stderr)
        return 2
    if failed:
        print("16 KB hizası bozuk: " + ", ".join(failed), file=sys.stderr)
        return 1
    print(f"16 KB hizası uygun ({checked} kütüphane).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
