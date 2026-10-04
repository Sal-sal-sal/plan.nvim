"""Render the captured terminal cells to a demo GIF (requires Pillow)."""
from pathlib import Path
import re
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CAPTURES = ROOT / "target/tui"
CELL, ROW, PAD = 10, 24, 16
WIDTH, HEIGHT = 96 * CELL + PAD * 2, 22 * ROW + PAD * 2
SGR = re.compile(r"\x1b\[([0-9;]*)m")
FG, BG = (224, 226, 234), (20, 22, 27)
PALETTE = [BG, (243, 139, 168), (166, 227, 161), (249, 226, 175),
           (137, 180, 250), (203, 166, 247), (140, 248, 247), FG]


def fonts():
    candidates = ["/System/Library/Fonts/Menlo.ttc",
                  "/System/Library/Fonts/Supplemental/Menlo.ttc",
                  "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"]
    for path in candidates:
        if Path(path).exists():
            normal = ImageFont.truetype(path, 16)
            bold = ImageFont.truetype(path, 16, index=1) if path.endswith("ttc") else normal
            return normal, bold
    raise RuntimeError("Install Menlo or DejaVu Sans Mono to render the demo")


def attributes(values, state):
    values = [int(value or 0) for value in values.split(";")]
    index = 0
    while index < len(values):
        value = values[index]
        if value == 0:
            state.update(fg=FG, bg=BG, bold=False, strike=False, inverse=False)
        elif value in (1, 22):
            state["bold"] = value == 1
        elif value in (9, 29):
            state["strike"] = value == 9
        elif value in (7, 27):
            state["inverse"] = value == 7
        elif value in (39, 49):
            state["fg" if value == 39 else "bg"] = FG if value == 39 else BG
        elif 30 <= value <= 37:
            state["fg"] = PALETTE[value - 30]
        elif 40 <= value <= 47:
            state["bg"] = PALETTE[value - 40]
        elif value in (38, 48) and index + 4 < len(values) and values[index + 1] == 2:
            state["fg" if value == 38 else "bg"] = tuple(values[index + 2:index + 5])
            index += 4
        index += 1


def render(capture, normal, bold):
    image = Image.new("RGB", (WIDTH, HEIGHT), BG)
    draw = ImageDraw.Draw(image)
    state = dict(fg=FG, bg=BG, bold=False, strike=False, inverse=False)
    for row, line in enumerate(capture.splitlines()[:22]):
        column, offset = 0, 0
        for match in list(SGR.finditer(line)) + [None]:
            end = match.start() if match else len(line)
            for char in line[offset:end]:
                foreground, background = state["fg"], state["bg"]
                if state["inverse"]:
                    foreground, background = background, foreground
                x, y = PAD + column * CELL, PAD + row * ROW
                draw.rectangle((x, y, x + CELL, y + ROW), fill=background)
                draw.text((x, y + 2), char, font=bold if state["bold"] else normal, fill=foreground)
                if state["strike"]:
                    draw.line((x, y + 12, x + CELL, y + 12), fill=foreground)
                column += 1
            if match:
                attributes(match.group(1), state)
                offset = match.end()
        background = state["fg"] if state["inverse"] else state["bg"]
        draw.rectangle((PAD + column * CELL, PAD + row * ROW, WIDTH - PAD, PAD + (row + 1) * ROW), fill=background)
    return image


def main():
    normal, bold = fonts()
    frames = [render(path.read_text(), normal, bold) for path in sorted(CAPTURES.glob("*.ansi"))]
    assert frames, "Run scripts/tui_smoke.py first"
    output = ROOT / "doc/assets"
    output.mkdir(parents=True, exist_ok=True)
    frames[-1].save(CAPTURES / "completion.png")
    frames[0].save(output / "demo.gif", save_all=True, append_images=frames[1:],
                   duration=[900] + [75] * (len(frames) - 2) + [900], loop=0)
    print(output / "demo.gif")


if __name__ == "__main__":
    main()
