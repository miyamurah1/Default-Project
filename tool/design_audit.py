"""Temporary design audit: WCAG contrast for the Daily Bloom palette."""

def srgb(c):
    c = c / 255
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

def lum(hexstr):
    h = hexstr.lstrip('#')
    r, g, b = (int(h[i:i+2], 16) for i in (0, 2, 4))
    return 0.2126 * srgb(r) + 0.7152 * srgb(g) + 0.0722 * srgb(b)

def ratio(fg, bg):
    a, b = lum(fg), lum(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)

themes = {
    'Midnight Tokyo': dict(background='#14121E', surface='#1E1A2E', primary='#E84A6B',
                           ink='#F2EFFA', inkSoft='#A79FC4', inkFaint='#6E6591',
                           cardBorder='#3A3355', navInactive='#4A4365', heat0='#241F33'),
    'Edo Period': dict(background='#FAF9F6', surface='#FFFFFF', primary='#C41E3A',
                       ink='#2D2D2D', inkSoft='#8A7F83', inkFaint='#B9AEB2',
                       cardBorder='#F9E2E7', navInactive='#E3CBD1', heat0='#F9E0E6'),
    'Kyoto Garden': dict(background='#F3F5EA', surface='#FDFEFA', primary='#3E7C4F',
                         ink='#2A3325', inkSoft='#6F7A63', inkFaint='#A3AD94',
                         cardBorder='#DCE5CB', navInactive='#C3CDB2', heat0='#E4E9D2'),
    'Kamogawa Blue': dict(background='#F0F5FA', surface='#FBFDFF', primary='#1565A0',
                          ink='#1E2A38', inkSoft='#5D7285', inkFaint='#93A8BC',
                          cardBorder='#C9DCEC', navInactive='#B4C9DC', heat0='#DCE8F3'),
}

# role -> (token, typical fontSize used in the codebase, bold?)
roles = [
    ('inkFaint  (9-11px uppercase labels)', 'inkFaint', 10, True),
    ('inkFaint  (11px body captions)', 'inkFaint', 11, False),
    ('inkSoft   (12-13px body)', 'inkSoft', 12.5, False),
    ('primary   (11-12px labels/links)', 'primary', 11.5, True),
    ('ink       (13-16px body)', 'ink', 14, False),
    ('navInactive (22px icon, unselected tab)', 'navInactive', 22, False),
    ('heat0     (empty heatmap cell vs bg)', 'heat0', 14, False),
]

print('WCAG CONTRAST AUDIT  (AA needs 4.5 normal / 3.0 for >=18.66px bold or >=24px)')
print('=' * 78)
fails = 0
for tname, t in themes.items():
    print(f'\n### {tname}   (background {t["background"]} / surface {t["surface"]})')
    for label, token, size, bold in roles:
        fg = t[token]
        # cards sit on `surface`; page-level text sits on `background`
        worst = min(ratio(fg, t['surface']), ratio(fg, t['background']))
        need = 3.0 if (size >= 18.66 and bold) or size >= 24 else 4.5
        ok = worst >= need
        if not ok:
            fails += 1
        print(f'  {"PASS" if ok else "FAIL"}  {worst:5.2f}:1 (need {need})  {label}  [{fg}]')

print('\n' + '=' * 78)
print(f'{fails} of {len(themes)*len(roles)} token/role pairs FAIL AA.')
