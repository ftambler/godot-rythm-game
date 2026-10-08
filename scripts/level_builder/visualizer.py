import argparse
import json
from pathlib import Path

import matplotlib.pyplot as plt


WALL_ORIENTATIONS = {
    "HORIZONTAL": 0.0,
    "VERTICAL": 90.0,
    "DIAGONAL_DOWN": 45.0,
    "DIAGONAL_UP": -45.0,
}


def load_level(path: str | Path) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def draw_wall(ax, x: float, y: float, wall_type: str, label: str, scale: float = 120.0):
    angle_deg = WALL_ORIENTATIONS.get(wall_type, 0.0)
    angle_rad = angle_deg * 3.141592653589793 / 180.0

    half = scale / 2.0
    x1 = x - half * __import__("math").cos(angle_rad)
    y1 = y - half * __import__("math").sin(angle_rad)
    x2 = x + half * __import__("math").cos(angle_rad)
    y2 = y + half * __import__("math").sin(angle_rad)

    ax.plot([x1, x2], [y1, y2], color="tomato", linewidth=3)
    ax.scatter([x], [y], color="tomato", s=24)
    ax.text(x, y + 40, label, ha="center", va="bottom", fontsize=8, color="black")


def draw_orb(ax, x: float, y: float, label: str):
    ax.scatter([x], [y], s=160, color="dodgerblue", edgecolors="black", linewidths=0.8)
    ax.text(x, y + 30, label, ha="center", va="bottom", fontsize=8, color="black")


def visualize_level(level_path: str | Path, output_path: str | Path | None = None):
    level = load_level(level_path)
    objects = level.get("objects", [])

    fig, ax = plt.subplots(figsize=(10, 8))
    ax.set_aspect("equal")
    ax.invert_yaxis()
    ax.set_title(f"Level preview: {Path(level_path).name}")
    ax.grid(True, alpha=0.25)

    for index, obj in enumerate(objects, start=1):
        pos = obj.get("position", [0.0, 0.0])
        x, y = float(pos[0]), float(pos[1])
        obj_type = obj.get("type")
        label = f"{obj_type[0].upper()}{index}"

        if obj_type == "orb":
            draw_orb(ax, x, y, label)
        elif obj_type == "walls":
            wall_type = obj.get("wallType", "HORIZONTAL")
            draw_wall(ax, x, y, wall_type, label)

    player = level.get("player", {})
    player_pos = player.get("position", [0.0, 0.0])
    px, py = float(player_pos[0]), float(player_pos[1])
    ax.scatter([px], [py], s=200, color="limegreen", edgecolors="black", linewidths=1.2)
    ax.text(px, py + 35, "P", ha="center", va="bottom", fontsize=9, fontweight="bold")

    ax.set_xlabel("X")
    ax.set_ylabel("Y")
    ax.margins(0.25)

    if output_path is not None:
        fig.savefig(output_path, dpi=200, bbox_inches="tight")
        print(f"Saved level preview to {output_path}")
    else:
        plt.show()

    return ax


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Visualize a level JSON using walls and orbs labels in order.")
    parser.add_argument("level", nargs="?", default="../../levels/test.json", help="Path to the JSON level file.")
    parser.add_argument("--out", default=None, help="Optional path to save the preview as an image.")
    args = parser.parse_args()

    level_path = Path(args.level).resolve()
    out_path = Path(args.out).resolve() if args.out else None
    visualize_level(level_path, out_path)
