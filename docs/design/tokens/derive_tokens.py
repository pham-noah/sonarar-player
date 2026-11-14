"""Derives the three missing colour tokens for every Sonarar theme.

Rule set (from the audit):
  textMuted   = textSecondary blended toward textPrimary until it reaches 4.5:1 on bg
  accentInk   = accent blended toward textPrimary until it reaches 4.5:1 on bg
                (the colour to use when the accent is TEXT, not a surface)
  borderStrong= textSecondary at the lowest alpha that reaches 3.0:1 on bg
                (the only border allowed to delimit a control)

Every value printed here is what the doc asks the implementer to hardcode.
"""


def srgb_to_lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    if len(h) == 8:
        h = h[2:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexof(t) -> str:
    return "#" + "".join(f"{round(v):02x}" for v in t)


def lum(h: str) -> float:
    r, g, b = (c / 255 for c in rgb(h))
    return 0.2126 * srgb_to_lin(r) + 0.7152 * srgb_to_lin(g) + 0.0722 * srgb_to_lin(b)


def ratio(a: str, b: str) -> float:
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def mix(a: str, b: str, t: float) -> str:
    ca, cb = rgb(a), rgb(b)
    return hexof([ca[i] + (cb[i] - ca[i]) * t for i in range(3)])


def blend_to(fg: str, bg: str, toward: str, target: float, alpha: bool = False) -> str:
    """Smallest step toward `toward` that reaches `target` contrast on bg.

    With alpha=True the blend is a translucent fg over bg (alpha ladder), which
    is how the app actually paints muted text today.
    """
    lo, hi = 0.0, 1.0
    best = mix(fg, toward, 1.0)
    for _ in range(40):
        mid = (lo + hi) / 2
        cand = (
            mix(bg, fg, mid) if alpha else mix(fg, toward, mid)
        )
        if ratio(cand, bg) >= target:
            best = cand
            hi = mid
        else:
            lo = mid
    return best


def alpha_for(fg: str, bg: str, target: float) -> float:
    lo, hi = 0.0, 1.0
    for _ in range(50):
        mid = (lo + hi) / 2
        if ratio(mix(bg, fg, mid), bg) >= target:
            hi = mid
        else:
            lo = mid
    return hi


THEMES = {
    "abyss":   dict(bg="#04080F", tp="#FFFFFF", ts="#E2EEFA", ac="#3CE0D0"),
    "amber":   dict(bg="#000000", tp="#FFFFFF", ts="#FDFDFD", ac="#F3DF0C"),
    "crimson": dict(bg="#0A0A0C", tp="#FFFFFF", ts="#E8E8EE", ac="#E60012"),
    "minimal": dict(bg="#E9E4DC", tp="#2B2A28", ts="#5C5955", ac="#E8927C"),
    "mono":    dict(bg="#121213", tp="#FFFFFF", ts="#9A9AA2", ac="#D8D8DC"),
    "bloom":   dict(bg="#F4E4DA", tp="#33272B", ts="#665459", ac="#D98BA6"),
    "solid/midnight": dict(bg="#0B1020", tp="#F2F6FF", ts="#A9B6D0", ac="#4C8DFF"),
    "glass/aurora":   dict(bg="#0E1116", tp="#F7F9FC", ts="#B4BEC9", ac="#7FD1FF"),
    "solid/forest":   dict(bg="#0A1410", tp="#F0FBF4", ts="#A9C6B7", ac="#4ADE80"),
}

print(f"{'theme':15} {'textMuted':9} {'r':>5}  {'accentInk':9} {'r':>5}  "
      f"{'borderStrong':12} {'a':>4} {'r':>5}")
for name, t in THEMES.items():
    tm = blend_to(t["ts"], t["bg"], t["tp"], 4.5)
    ai = blend_to(t["ac"], t["bg"], t["tp"], 4.5)
    a = alpha_for(t["ts"], t["bg"], 3.0)
    bs = mix(t["bg"], t["ts"], a)
    print(f"{name:15} {tm:9} {ratio(tm, t['bg']):5.2f}  {ai:9} "
          f"{ratio(ai, t['bg']):5.2f}  {bs:12} {a:4.2f} {ratio(bs, t['bg']):5.2f}")

print()
print("alpha needed for each text role (replaces the 28-value ladder):")
print(f"{'theme':15} {'muted(text)':>12} {'subtle(3:1)':>12} {'border(3:1)':>12}")
for name, t in THEMES.items():
    print(f"{name:15} {alpha_for(t['ts'], t['bg'], 4.5):12.2f} "
          f"{alpha_for(t['ts'], t['bg'], 3.0):12.2f} "
          f"{alpha_for(t['ts'], t['bg'], 3.0):12.2f}")
