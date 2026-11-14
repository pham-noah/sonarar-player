"""WCAG contrast audit for Sonarar's palette tokens.

Reads nothing from the app: the hex values below are copied from
lib/theme/skin.dart and assets/themes/*.json so the numbers in the design doc
are reproducible without a Flutter build.
"""


def srgb_to_lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lum(hex_rgba: str) -> float:
    h = hex_rgba.lstrip("#")
    if len(h) == 8:
        h = h[2:]  # drop alpha, caller composites first
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return 0.2126 * srgb_to_lin(r) + 0.7152 * srgb_to_lin(g) + 0.0722 * srgb_to_lin(b)


def ratio(fg: str, bg: str) -> float:
    a, b = lum(fg), lum(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def rgb(hex_rgba: str) -> tuple[int, int, int]:
    h = hex_rgba.lstrip("#")
    if len(h) == 8:
        h = h[2:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def composite(fg: str, alpha: float, bg: str) -> str:
    """fg at `alpha` painted over bg -> the colour a screenshot would show."""
    h = fg.lstrip("#")
    a = alpha
    if len(h) == 8:
        a = int(h[0:2], 16) / 255 * alpha
    f, b = rgb(fg), rgb(bg)
    out = tuple(round(f[i] * a + b[i] * (1 - a)) for i in range(3))
    return "#" + "".join(f"{v:02x}" for v in out)


SKINS = {
    "abyss": dict(bg="#04080F", textPrimary="#FFFFFF", textSecondary="#E2EEFA",
                  accent="#3CE0D0", accentDeep="#2F6FD0", onAccent="#03121E",
                  panel="#16EBFF"),
    "amber": dict(bg="#000000", textPrimary="#FFFFFF", textSecondary="#FDFDFD",
                  accent="#F3DF0C", accentDeep="#EE8921", onAccent="#0A0A0A",
                  panel="#F3DF0C"),
    "crimson": dict(bg="#0A0A0C", textPrimary="#FFFFFF", textSecondary="#E8E8EE",
                    accent="#E60012", accentDeep="#A3000D", onAccent="#FFFFFF",
                    panel="#1C1C22"),
    "minimal": dict(bg="#E9E4DC", textPrimary="#2B2A28", textSecondary="#5C5955",
                    accent="#E8927C", accentDeep="#C96A52", onAccent="#2B2A28",
                    panel="#FFFFFF"),
    "mono": dict(bg="#121213", textPrimary="#FFFFFF", textSecondary="#9A9AA2",
                 accent="#D8D8DC", accentDeep="#6E6E76", onAccent="#121213",
                 panel="#1E1E20"),
    "bloom": dict(bg="#F4E4DA", textPrimary="#33272B", textSecondary="#665459",
                  accent="#D98BA6", accentDeep="#A85F79", onAccent="#33272B",
                  panel="#FFF9F6"),
}

LAYOUTS = {
    "solid/midnight": dict(bg="#0b1020", textPrimary="#f2f6ff",
                           textSecondary="#a9b6d0", accent="#4c8dff",
                           onAccent="#061024"),
    "glass/aurora": dict(bg="#0e1116", textPrimary="#f7f9fc",
                         textSecondary="#b4bec9", accent="#7fd1ff",
                         onAccent="#06121c"),
    "solid/forest": dict(bg="#0a1410", textPrimary="#f0fbf4",
                         textSecondary="#a9c6b7", accent="#4ade80",
                         onAccent="#04120a"),
}

# The alpha ladder as the code actually uses it (grep of withValues(alpha:)).
ALPHAS = [0.05, 0.06, 0.07, 0.08, 0.10, 0.12, 0.16, 0.18, 0.22, 0.24, 0.30,
          0.34, 0.35, 0.42, 0.45, 0.50, 0.52, 0.55, 0.60, 0.62, 0.72, 0.80, 0.85]


def verdict(r: float, large: bool = False) -> str:
    need = 3.0 if large else 4.5
    if r >= need:
        return "PASS"
    if r >= 3.0:
        return "large-only"
    return "FAIL"


print("== solid text tokens ==")
print(f"{'theme':16} {'pair':34} {'ratio':>6}  verdict")
for name, t in {**SKINS, **LAYOUTS}.items():
    for role in ("textPrimary", "textSecondary"):
        r = ratio(t[role], t["bg"])
        print(f"{name:16} {role + ' on bg':34} {r:6.2f}  {verdict(r)}")
    r = ratio(t["onAccent"], t["accent"])
    print(f"{name:16} {'onAccent on accent':34} {r:6.2f}  {verdict(r)}")

print()
print("== secondary text at the alpha ladder (body 14px, needs 4.5) ==")
print(f"{'theme':16} " + " ".join(f"{a:5.2f}" for a in ALPHAS))
for name, t in {**SKINS, **LAYOUTS}.items():
    cells = []
    for a in ALPHAS:
        c = composite(t["textSecondary"], a, t["bg"])
        cells.append(f"{ratio(c, t['bg']):5.2f}")
    print(f"{name:16} " + " ".join(cells))

print()
print("== accent as text / icon on bg (needs 3.0 for icons, 4.5 for text) ==")
for name, t in {**SKINS, **LAYOUTS}.items():
    r = ratio(t["accent"], t["bg"])
    print(f"{name:16} accent {t['accent']:8} on bg {r:6.2f}  {verdict(r)}")

print()
print("== accent band (section header) label on accent ==")
for name, t in {**SKINS, **LAYOUTS}.items():
    print(f"{name:16} onAccent on accent {ratio(t['onAccent'], t['accent']):6.2f}")

print()
print("== accent at low alpha used as a surface tint (panel borders) ==")
for name, t in {**SKINS, **LAYOUTS}.items():
    row = []
    for a in (0.12, 0.18, 0.24, 0.30):
        c = composite(t["accent"], a, t["bg"])
        row.append(f"{a:.2f}:{ratio(c, t['bg']):5.2f}")
    print(f"{name:16} " + "  ".join(row))

print()
print("== widget-level pairs ==")
def pair(label, fg, bg):
    print(f"{label:52} {ratio(fg, bg):6.2f}")

for name, t in {"abyss": SKINS["abyss"], "minimal": SKINS["minimal"], "mono": SKINS["mono"]}.items():
    bg = t["bg"]
    track = composite(t["accent"], 0.35, bg)
    pair(f"{name}: switch knob (accent) vs ON track (accent@.35)", t["accent"], track)
    pair(f"{name}: ON track (accent@.35) vs page background", track, bg)
    panel = composite(t["panel"], 1.0, bg) if name == "abyss" else t["panel"]
    pair(f"{name}: panel fill vs page background", panel, bg)

print()
print("== translucent panel fill (skin.panel carries its own alpha) ==")
for name, t, alpha in [("abyss", SKINS["abyss"], 0x26/255), ("mono", SKINS["mono"], 1.0)]:
    fill = composite(t["panel"], alpha, t["bg"])
    print(f"{name:8} panel {t['panel']} @{alpha:.2f} over bg -> {fill}  ratio {ratio(fill, t['bg']):.2f}")
