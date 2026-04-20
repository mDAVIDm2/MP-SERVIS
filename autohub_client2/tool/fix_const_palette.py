import pathlib

root = pathlib.Path(__file__).resolve().parent.parent / "lib"
subs = [
    ("const TextStyle(", "TextStyle("),
    ("const Icon(", "Icon("),
    ("const BorderSide(", "BorderSide("),
    ("const Divider(", "Divider("),
    ("const BoxDecoration(", "BoxDecoration("),
    ("const Center(", "Center("),
    ("const SnackBar(", "SnackBar("),
    ("const OutlineInputBorder(", "OutlineInputBorder("),
    ("const TextSelectionThemeData(", "TextSelectionThemeData("),
    ("const InputDecoration(", "InputDecoration("),
    ("const Border(", "Border("),
]
for path in root.rglob("*.dart"):
    t = path.read_text(encoding="utf-8")
    lines = t.splitlines(True)
    changed = False
    out = []
    for line in lines:
        if "context.palette" in line:
            nl = line
            for a, b in subs:
                nl = nl.replace(a, b)
            if nl != line:
                changed = True
            line = nl
        out.append(line)
    if changed:
        path.write_text("".join(out), encoding="utf-8")
        print("fixed", path)
