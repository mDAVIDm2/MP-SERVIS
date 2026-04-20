import pathlib

root = pathlib.Path(__file__).resolve().parent.parent / "lib"
patterns = [
    ("const TextStyle(", "TextStyle("),
    ("const BoxDecoration(", "BoxDecoration("),
    ("const InputDecoration(", "InputDecoration("),
    ("const LinearGradient(", "LinearGradient("),
    ("const OutlineInputBorder(", "OutlineInputBorder("),
    ("const RoundedRectangleBorder(", "RoundedRectangleBorder("),
    ("const Border(", "Border("),
    ("const Padding(", "Padding("),
    ("const SizedBox(", "SizedBox("),
    ("const DecoratedBox(", "DecoratedBox("),
    ("const Column(", "Column("),
    ("const Row(", "Row("),
]
for path in root.rglob("*.dart"):
    t = path.read_text(encoding="utf-8")
    if "context.palette" not in t:
        continue
    o = t
    for a, b in patterns:
        t = t.replace(a, b)
    if t != o:
        path.write_text(t, encoding="utf-8")
        print(path)
