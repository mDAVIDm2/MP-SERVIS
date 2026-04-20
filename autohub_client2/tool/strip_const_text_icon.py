import pathlib

root = pathlib.Path(__file__).resolve().parent.parent / "lib"
for path in root.rglob("*.dart"):
    t = path.read_text(encoding="utf-8")
    if "context.palette" not in t:
        continue
    o = t
    t = t.replace("const Text(", "Text(")
    t = t.replace("const Icon(", "Icon(")
    if t != o:
        path.write_text(t, encoding="utf-8")
        print(path)
