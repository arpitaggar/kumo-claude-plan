#!/usr/bin/env python3
"""Decodes screenshots captured by integration_test/promo_screenshots_test.dart.

The test prints each screenshot as base64, chunked, between
SCREENSHOT_BEGIN:<name> and SCREENSHOT_END:<name> markers rather than
writing to on-device storage — see that file's header comment for why (the
app's data container can vanish before a host script gets a chance to pull
a file out of it). This reads the captured `flutter test` log and decodes
each one back into a PNG.

Usage:
    flutter test integration_test/promo_screenshots_test.dart -d <device> \
        --dart-define-from-file=env.local.json \
        --dart-define-from-file=integration_test/test_account.json \
        > promo_run.log 2>&1
    python3 scripts/extract_promo_screenshots.py promo_run.log <output-dir>
"""
import base64
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <log_file> <output_dir>", file=sys.stderr)
        sys.exit(1)

    log_path = Path(sys.argv[1])
    out_dir = Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)

    current_name = None
    chunks: list[str] = []
    saved = []

    for line in log_path.read_text(errors="replace").splitlines():
        line = line.strip()
        if line.startswith("SCREENSHOT_BEGIN:"):
            current_name = line[len("SCREENSHOT_BEGIN:") :]
            chunks = []
        elif line.startswith("SCREENSHOT_CHUNK:") and current_name is not None:
            chunks.append(line[len("SCREENSHOT_CHUNK:") :])
        elif line.startswith("SCREENSHOT_END:") and current_name is not None:
            data = base64.b64decode("".join(chunks))
            dest = out_dir / f"{current_name}.png"
            dest.write_bytes(data)
            saved.append(dest)
            current_name = None
            chunks = []

    if not saved:
        print("No screenshots found in log — did the test reach any _capture() "
              "calls? Check the log for test failures.", file=sys.stderr)
        sys.exit(1)

    for path in saved:
        print(f"Saved {path} ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
