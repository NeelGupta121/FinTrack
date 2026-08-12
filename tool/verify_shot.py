#!/usr/bin/env python3
"""Numerically verify a Flutter-web screenshot rendered real content.

Reading screenshots back into the agent transfers megabytes of base64 and, in a
long session, blows the response-stream limit. It is also unreliable evidence:
judging a scaled-down render by eye already produced one multi-turn chase after
a "ghost nav" that a row-brightness profile later proved never existed.

So verify with numbers instead. For each capture this reports:

  bands      how many horizontal bands (of 60) differ from the modal background
             -> a blank or single-colour screen has ~0; a populated screen has many
  spread     max-min band brightness; near-zero means a flat/blank surface
  err_px     pixels matching the fatal-error screen's coral (#FF6B6B) within
             tolerance -> non-trivial count means the screen crashed into
             _FatalErrorScreen rather than rendering
  canvas_px  pixels matching the dark canvas (#0A0A0C) -> sanity that the theme
             actually applied

Usage: verify_shot.py <png> [<png> ...]
"""
import subprocess
import sys


def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()


def band_profile(path, bands=60):
    out = run(
        f"convert {path} -colorspace Gray -resize 1x{bands}! txt:- 2>/dev/null"
    )
    vals = []
    for line in out.splitlines()[1:]:
        # format: 0,0: (r,g,b)  #RRGGBB  gray(N)
        if "gray(" in line:
            try:
                vals.append(float(line.split("gray(")[1].split(")")[0].rstrip("%")))
            except (IndexError, ValueError):
                pass
        elif "(" in line:
            try:
                vals.append(float(line.split("(")[1].split(",")[0]))
            except (IndexError, ValueError):
                pass
    return vals


def colour_count(path, hexcode, fuzz=12):
    out = run(
        f"convert {path} -fuzz {fuzz}% -fill white -opaque '{hexcode}' "
        f"-fill black +opaque white -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null"
    )
    try:
        return float(out)
    except ValueError:
        return -1.0


def main():
    print(f"{'file':<26} {'bands':>6} {'spread':>7} {'fatalbg%':>9} {'canvas%':>8}  verdict")
    for path in sys.argv[1:]:
        vals = band_profile(path)
        if not vals:
            print(f"{path.split('/')[-1]:<26} {'-':>6} {'-':>7} {'-':>9} {'-':>8}  UNREADABLE")
            continue
        # Modal background = most common rounded value.
        rounded = [round(v, 1) for v in vals]
        modal = max(set(rounded), key=rounded.count)
        bands = sum(1 for v in rounded if abs(v - modal) > 0.6)
        spread = max(vals) - min(vals)

        # Crash discriminator: _FatalErrorScreen paints the WHOLE surface
        # #0E0F1A, which is a different colour from the app canvas #0A0A0C.
        # Keying on its coral icon instead was wrong -- at any usable fuzz the
        # coral also matches the theme's error red (#EF4444), which appears
        # legitimately on every screen with a negative amount, so every screen
        # falsely read as crashed. Area dominance of the fatal background is
        # unambiguous; a real screen keeps canvas% high.
        fatalpct = colour_count(path, "#0E0F1A", fuzz=3) * 100
        canvpct = colour_count(path, "#0A0A0C", fuzz=3) * 100

        if fatalpct > 50 and canvpct < 20:
            verdict = "CRASHED (error screen)"
        elif bands >= 8 and spread > 3:
            verdict = "POPULATED"
        elif bands >= 3:
            verdict = "SPARSE"
        else:
            verdict = "BLANK/FLAT"
        print(
            f"{path.split('/')[-1]:<26} {bands:>6} {spread:>7.2f} "
            f"{fatalpct:>9.2f} {canvpct:>8.2f}  {verdict}"
        )


if __name__ == "__main__":
    main()
