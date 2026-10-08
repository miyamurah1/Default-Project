# Colour contract checker for the Bloom design system.
# Verifies every text/background pair in a theme meets WCAG AA and that
# the momentum (heat) ramp is monotonic in relative luminance so "more
# work" always reads as "brighter". Also checks the two support accents
# separate from the loud one.
#
#   python tool/palette_check.py
#
# Keep this next to the palette: a new theme must pass before it ships.

import sys

HEAT = ["heat0", "heat1", "heat2", "heat3", "heat4", "heatPeak"]

THEMES = {
    "Midnight Tokyo": dict(
        canvas="#0E0A15", surface="#181327", raised="#221A33",
        ink="#F6F2FB", inkSoft="#BDB4D2", inkFaint="#948BAE",
        primary="#FF5C7C", primarySoft="#3A1B2C",
        tagBg="#2A2138", tagText="#F0A0B6",
        focus="#FFB454", success="#3ED598",
        heat0="#221B31", heat1="#4A2544", heat2="#8A2F55",
        heat3="#D14A70", heat4="#FF7D96", heatPeak="#FFC24B",
    ),
    "Edo Period": dict(
        canvas="#F5F1E9", surface="#FFFDF8", raised="#FAF6EE",
        ink="#221D1A", inkSoft="#6B6058", inkFaint="#8B8078",
        primary="#C22A44", primarySoft="#FBE4E8",
        tagBg="#F6E9E3", tagText="#A8465A",
        focus="#B36A12", success="#1F7A55",
        heat0="#F0E5E1", heat1="#F2C6C0", heat2="#EA8A85",
        heat3="#DC4A50", heat4="#B02033", heatPeak="#D99A2B",
    ),
    "Kyoto Garden": dict(
        canvas="#EFF2E6", surface="#FCFDF8", raised="#F4F7EC",
        ink="#1F2720", inkSoft="#5F6B5A", inkFaint="#838F77",
        primary="#3E7C4F", primarySoft="#E4EFDD",
        tagBg="#EBF2E1", tagText="#4A7355",
        focus="#B36A12", success="#1F7A6A",
        heat0="#E4E9D4", heat1="#C2D3A6", heat2="#8FB877",
        heat3="#4F8A54", heat4="#2C6B3E", heatPeak="#D99A2B",
    ),
    "Kamogawa Blue": dict(
        canvas="#EDF3F8", surface="#FCFDFF", raised="#F3F8FC",
        ink="#16212B", inkSoft="#55697A", inkFaint="#7C8FA0",
        primary="#13629C", primarySoft="#DFEBF6",
        tagBg="#E4EEF7", tagText="#2E6E9E",
        focus="#B36A12", success="#1C7F5E",
        heat0="#DCE7F1", heat1="#AFCDE4", heat2="#74A9CE",
        heat3="#2F7FB8", heat4="#12598C", heatPeak="#D99A2B",
    ),
}


def lum(hexstr):
    h = hexstr.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))

    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def ratio(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def check(label, fg, bg, need, fails):
    r = ratio(fg, bg)
    ok = r >= need
    if not ok:
        fails.append(f"{label} {r:.2f} < {need}")
    print(f"  {label:<40} {r:5.2f}  need {need:<4} {'ok' if ok else 'FAIL'}")
    return r


def run(theme, t):
    fails = []
    print(f"\n== {theme}")
    # Body copy and metadata must clear AA on every surface they use.
    check("ink / surface", t["ink"], t["surface"], 7.0, fails)
    check("ink / raised", t["ink"], t["raised"], 7.0, fails)
    check("inkSoft / surface", t["inkSoft"], t["surface"], 4.5, fails)
    check("inkFaint / surface", t["inkFaint"], t["surface"], 4.5, fails)
    check("inkFaint / raised", t["inkFaint"], t["raised"], 4.5, fails)
    check("primary / surface", t["primary"], t["surface"], 4.5, fails)
    check("primary / primarySoft", t["primary"], t["primarySoft"], 3.0, fails)
    check("tagText / tagBg", t["tagText"], t["tagBg"], 4.5, fails)
    # Support accents are icons/metrics, never small body copy.
    check("focus / surface", t["focus"], t["surface"], 3.0, fails)
    check("success / surface", t["success"], t["surface"], 3.0, fails)
    # Momentum cells must be visibly separable from the card they sit on.
    check("heat0 / surface (empty cell)", t["heat0"], t["surface"], 1.15, fails)
    check("heat4 / surface (full day)", t["heat4"], t["surface"], 1.6, fails)
    check("heatPeak / surface (peak day)", t["heatPeak"], t["surface"], 1.8, fails)
    check("heatPeak / heat4 (peak vs full)", t["heatPeak"], t["heat4"], 1.2, fails)

    ramp = [t[k] for k in HEAT]
    ls = [lum(c) for c in ramp]
    mono = all(ls[i + 1] - ls[i] > 0.004 for i in range(len(ls) - 1))
    print(f"  ramp {'monotonic' if mono else 'NOT MONOTONIC'}"
          f"  lums={[round(l, 3) for l in ls]}")
    if not mono:
        fails.append("heat ramp not monotonic")
    # Adjacent steps must be distinguishable from each other, not just
    # from the card, or the grid reads as flat blocks.
    for i in range(len(ramp) - 1):
        check(f"heat{i} vs heat{i + 1}", ramp[i], ramp[i + 1], 1.12, fails)
    return fails


total = []
for name, t in THEMES.items():
    total += [f"{name}: {f}" for f in run(name, t)]

print("\n" + ("ALL PASS" if not total else "FAILURES:\n  " + "\n  ".join(total)))
sys.exit(1 if total else 0)