# Assets

## Naming
- One folder per game system (`assets/<system>/`), shared UI in `assets/ui/`.
- Files: lowercase snake_case, general → specific: `<subject>_<variant>_<state>.<ext>` (e.g. `assets/combat/unit_spearman_damaged.glb`).
- Source files in `art-src/<system>/` keep the subject name (e.g. `art-src/combat/unit_spearman.blend`).

## Formats
- 3D models: `.glb` (glTF 2.0), 1 unit = 1 m, +Y up, front faces +Z (`Vector3.MODEL_FRONT`), pivot at the bottom center; animations as named actions inside the `.glb`.
- Textures: `.png`, power-of-two sizes, at most 1024×1024 (Steam Deck memory budget); prefer one shared palette texture for low-poly models.
- UI: `.svg` for icons, `.png` for raster art; design at 1920×1080.
- Audio: `.ogg` for music and ambience, `.wav` for short sound effects.

## Style
- Stylized low-poly 3D, faceted scenery and softly shaded characters, warm daylight, three-quarter camera.
- Combat uses the supplied medieval illustration references: rounded proportions, blue/gold lilies and red/white crosses. These are prototype team markings, not historical house heraldry.
- AI base prompt: "low-poly 3D game asset, flat shading, limited muted color palette, historical Germanic setting, three-quarter top-down view, soft daylight, plain neutral background"

## Sources & licenses
- One line per external pack or AI tool: folder — source — license.
- `assets/combat/` — original Blender meshes based on user-supplied style references; no third-party meshes or textures.

## After adding or renaming
- Run `godot --headless --import` (or open the editor) and commit the generated `.import`/`.uid` files with the asset.
