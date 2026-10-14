#!/usr/bin/env python3
"""Pack an Apple iconset into a PNG-backed ICNS file when iconutil is unavailable."""

import argparse
from pathlib import Path
import struct


# Retina representations have their own ICNS types, even when pixel sizes overlap.
ICON_REPRESENTATIONS = (
    (b"icp4", "icon_16x16.png"),
    (b"icp5", "icon_32x32.png"),
    (b"ic07", "icon_128x128.png"),
    (b"ic08", "icon_256x256.png"),
    (b"ic09", "icon_512x512.png"),
    (b"ic10", "icon_512x512@2x.png"),
    (b"ic11", "icon_16x16@2x.png"),
    (b"ic12", "icon_32x32@2x.png"),
    (b"ic13", "icon_128x128@2x.png"),
    (b"ic14", "icon_256x256@2x.png"),
)


def pack_iconset(iconset: Path, output: Path) -> None:
    """Validate PNG signatures and write the ICNS container."""
    chunks = []
    for kind, filename in ICON_REPRESENTATIONS:
        png = (iconset / filename).read_bytes()
        if not png.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError(f"{filename} is not a PNG")
        chunks.append(kind + struct.pack(">I", len(png) + 8) + png)

    body = b"".join(chunks)
    output.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("iconset", type=Path, help="Directory containing icon_<size>.png files")
    parser.add_argument("output", type=Path, help="Destination .icns file")
    args = parser.parse_args()
    pack_iconset(args.iconset, args.output)


if __name__ == "__main__":
    main()
