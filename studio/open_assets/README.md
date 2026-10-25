# Open Assets

A curated 30-model, medium-to-high-poly 3D kit for Code Cinema, downloaded from
[Poly Haven](https://polyhaven.com/models) at **2K texture resolution**.

All assets are **CC0 1.0** (public domain dedication). Attribution is not
required, but each asset keeps its author, source URL, and license in
`<asset>/LICENSE.txt` and `<asset>/asset.json`. The machine-readable inventory is
`manifest.json`.

## Layout

```
open_assets/
  manifest.json
  CREDITS.md
  README.md
  OpenSource_3D_Asset_Directory_2026.pdf
  pdf_2026/                 # downloaded PDF pack archive
  animations/zombies/       # Mixamo zombie animation clips
  characters/
    grab3d/                 # kexxy, girl, zombie, attack test resources
    crying/                 # legacy child model + textures
    quaternius_zombie/      # low-poly zombie character kit
    zombie_officer/         # Mixamo officer model + textures
    legacy/                 # unused scan/crawl source files
  <polyhaven_asset_id>/     # 30 Poly Haven models at 2K
    <asset_id>.gltf
    <asset_id>.bin
    textures/*.jpg
    thumbnail.png
    asset.json
    LICENSE.txt
```

The glTF files use external `.bin` and texture files. Keep each asset folder
intact when moving it. Units are metres; Poly Haven exports are ready for a
Godot scale factor of 1.0.

## Import into Godot

1. Keep `open_assets/` inside the studio project (already done).
2. Drag a `<asset_id>/<asset_id>.gltf` into a scene, or instantiate it from
   `res://open_assets/<asset_id>/<asset_id>.gltf`.
3. Godot imports the textures and material automatically. For dark scenes,
   enable emission on lamps/windows manually; Poly Haven materials are neutral.
4. Some modular pieces (facade, fire escape, pipes, duct) are kit pieces, not
   complete rooms. Combine them in a location scene.

## Inventory

| Asset | Category | Triangles | Size |
|---|---|---:|---:|
| GothicBed_01 | furniture | 18,741 | 2.1 MB |
| vintage_cabinet_01 | furniture | 61,096 | 4.8 MB |
| old_bed_frame | furniture | 49,990 | 9.7 MB |
| industrial_coffee_table | furniture | 41,300 | 7.9 MB |
| painted_wooden_sofa | furniture | 5,826 | 6.8 MB |
| vintage_radio_transceiver | props / electronics | 42,350 | 17.5 MB |
| vintage_telephone_wall_clock | props / wall decor | 15,864 | 8.8 MB |
| portable_cassette_player | props / electronics | 13,307 | 7.5 MB |
| old_gas_mask | props / industrial | 18,900 | 6.7 MB |
| vintage_suitcase | props | 16,474 | 15.0 MB |
| wine_bottles_01 | props / containers | 28,848 | 11.7 MB |
| wheelchair_01 | props | 40,252 | 2.8 MB |
| hanging_industrial_lamp | lighting | 9,530 | 11.4 MB |
| vintage_oil_lamp | lighting | 7,208 | 6.3 MB |
| industrial_caged_sconce | lighting | 26,576 | 8.1 MB |
| street_lamp_01 | lighting | 30,610 | 5.6 MB |
| large_castle_door | architecture | 12,640 | 11.0 MB |
| large_iron_gate | architecture | 38,140 | 8.4 MB |
| modular_fire_escape | architecture | 11,322 | 16.0 MB |
| modular_pipes | architecture | 47,428 | 17.6 MB |
| modular_airduct_rectangular_01 | architecture | 45,090 | 4.6 MB |
| modular_urban_apartments_facade | architecture | 118,215 | 39.5 MB |
| dead_tree_trunk | nature | 101,802 | 10.8 MB |
| tree_stump_01 | nature | 41,046 | 10.8 MB |
| rock_face_01 | nature | 20,174 | 9.7 MB |
| moss_01 | nature | 246,170 | 3.1 MB |
| coastal_cliff_01 | nature | 865,917 | 19.9 MB |
| gothic_statue | decor | 27,739 | 10.6 MB |
| ornate_mirror_01 | decor | 14,246 | 1.3 MB |
| street_rat | creature | 14,286 | 9.2 MB |

Total: ~305 MB including 2K textures and thumbnails.

## Refetching / extending

The downloader lives in the skill at
`scripts/fetch_open_assets.py`. Example:

```powershell
py -3.11 scripts/fetch_open_assets.py `
  --dest D:\code-cinema\studio\open_assets `
  --resolution 2k `
  --ids GothicBed_01,vintage_radio_transceiver
```

Poly Haven also publishes 1K and 4K texture variants. Re-run with `--force
--resolution 4k` to upgrade an asset; keep an eye on project size and Godot
import time.
