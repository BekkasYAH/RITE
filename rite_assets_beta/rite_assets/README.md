# RITE beta art pack
Grid: **16 px**. All PNGs are RGBA, nearest-neighbour only (disable filtering/mipmaps). Light comes from the upper-left.
Per-file frame sizes, orders, anchors and FPS are in `assets_manifest.json`.

| Folder | Contents |
|---|---|
| `environment/` | `ground_base` (grass x3, dirt x2, cobble) + 4x4 autotile overlays (dirt road, cobble, water f0/f1, stone wall top, wood fence, iron cemetery fence) |
| `landmarks/` | house (modules + assembled + chimney), well, chapel, pine and dead trees |
| `characters/` | `player_sheet` 16x24 (rows down/left/right/up; cols idle0-1, walk0-3), `ghost_sheet` 32x32 (rows idle/move/pursuit/contained, 4 frames) |
| `ritual/` | chalk strokes, containment circle (chalk + 4-frame active), iron nail, tether stable/strained/snapped, containment effect |
| `props/` | lantern, light glow, crates, barrels, abandoned objects, grave markers |
| `ui/` | grimoire/chalk/nail/lantern/key icons, stability bar frame + 3 fills |
| `preview/` | assembly test only (3x scale), not a game asset |

**Autotiles**: 4x4 grid, index = N*1 + E*2 + S*4 + W*8 (neighbour present). Overlay them on `grass_*` base tiles.
Dirt/wall/fence = thin line connections; cobble/water = filled areas (index 15 = interior).
Ritual circle: nail points are listed in the manifest (5 nails on the star tips).
Ghost faces right; flip X for left. Stability fill: crop width to stability % (stable > 50, strained 25-50, critical < 25).
