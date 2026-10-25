"""Download curated CC0 models from Poly Haven into studio/open_assets.

Poly Haven publishes its models under CC0 1.0. This script keeps the source,
author, polycount and license next to every asset so the kit stays auditable.

Usage:
  python fetch_open_assets.py --dest D:/code-cinema/studio/open_assets \
      --resolution 2k --ids GothicBed_01,vintage_radio_transceiver,...
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from cc_common import SKILL_ROOT

API = "https://api.polyhaven.com"
LICENSE_URL = "https://creativecommons.org/publicdomain/zero/1.0/"
DEFAULT_DEST = SKILL_ROOT.parent.parent.parent / "studio" / "open_assets"


def _request_json(url: str, timeout: int = 60) -> dict:
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            request = urllib.request.Request(
                url,
                headers={"User-Agent": "code-cinema-asset-fetcher/0.1"},
            )
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return json.loads(response.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last_error = exc
            if attempt < 2:
                time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"Could not fetch {url}: {last_error}")


def _download(url: str, target: Path, expected_md5: str = "") -> int:
    target.parent.mkdir(parents=True, exist_ok=True)
    part = target.with_suffix(target.suffix + ".part")
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            request = urllib.request.Request(
                url,
                headers={"User-Agent": "code-cinema-asset-fetcher/0.1"},
            )
            with urllib.request.urlopen(request, timeout=120) as response, part.open("wb") as handle:
                while True:
                    chunk = response.read(1024 * 512)
                    if not chunk:
                        break
                    handle.write(chunk)
            digest = hashlib.md5(part.read_bytes()).hexdigest()
            if expected_md5 and digest.lower() != expected_md5.lower():
                raise RuntimeError(f"MD5 mismatch for {target.name}")
            part.replace(target)
            return target.stat().st_size
        except (urllib.error.URLError, TimeoutError, OSError, RuntimeError) as exc:
            last_error = exc
            if part.exists():
                part.unlink(missing_ok=True)
            if attempt < 2:
                time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"Could not download {url}: {last_error}")


def _pick_gltf(files: dict, resolution: str) -> tuple[str, dict]:
    gltf = files.get("gltf") if isinstance(files.get("gltf"), dict) else {}
    for candidate in (resolution, "2k", "1k", "4k"):
        if candidate in gltf and isinstance(gltf[candidate], dict):
            return candidate, gltf[candidate].get("gltf") or {}
    raise RuntimeError("No glTF variant available")


def _asset_license(asset_id: str, info: dict) -> str:
    authors = info.get("authors") if isinstance(info.get("authors"), dict) else {}
    author_text = ", ".join(authors.keys()) or "Poly Haven contributors"
    return (
        f"Asset: {info.get('name', asset_id)} ({asset_id})\n"
        f"Author: {author_text}\n"
        f"Source: https://polyhaven.com/a/{asset_id}\n"
        f"License: CC0 1.0 Universal (public domain dedication)\n"
        f"{LICENSE_URL}\n\n"
        "Downloaded via the Poly Haven API. Poly Haven assets are CC0; "
        "attribution is not required but this record is kept for provenance.\n"
    )


def fetch_asset(asset_id: str, dest: Path, resolution: str, force: bool, thumb: bool) -> dict:
    asset_dir = dest / asset_id
    manifest_path = asset_dir / "asset.json"
    if manifest_path.exists() and not force:
        print(f"skip {asset_id} (exists)")
        return json.loads(manifest_path.read_text(encoding="utf-8"))

    info = _request_json(f"{API}/info/{urllib.parse.quote(asset_id)}")
    files = _request_json(f"{API}/files/{urllib.parse.quote(asset_id)}")
    used_resolution, gltf = _pick_gltf(files, resolution)
    gltf_url = gltf.get("url")
    if not gltf_url:
        raise RuntimeError(f"No glTF URL for {asset_id}")

    asset_dir.mkdir(parents=True, exist_ok=True)
    downloaded: list[dict] = []

    gltf_target = asset_dir / f"{asset_id}.gltf"
    size = _download(gltf_url, gltf_target, str(gltf.get("md5", "")))
    downloaded.append({"path": gltf_target.name, "bytes": size, "role": "gltf"})

    include = gltf.get("include") if isinstance(gltf.get("include"), dict) else {}
    for rel_path, meta in sorted(include.items()):
        target = asset_dir / rel_path
        size = _download(str(meta["url"]), target, str(meta.get("md5", "")))
        downloaded.append({"path": rel_path.replace("\\", "/"), "bytes": size, "role": "include"})

    thumb_name = ""
    if thumb:
        thumbnail_url = info.get("thumbnail_url")
        if thumbnail_url:
            suffix = Path(urllib.parse.urlparse(thumbnail_url).path).suffix or ".png"
            thumb_target = asset_dir / f"thumbnail{suffix}"
            try:
                _download(str(thumbnail_url), thumb_target)
                thumb_name = thumb_target.name
            except RuntimeError as exc:
                print(f"  thumbnail warning: {exc}")

    (asset_dir / "LICENSE.txt").write_text(_asset_license(asset_id, info), encoding="utf-8")
    record = {
        "id": asset_id,
        "name": info.get("name", asset_id),
        "description": info.get("description", ""),
        "categories": info.get("categories", []),
        "tags": info.get("tags", []),
        "authors": info.get("authors", {}),
        "polycount": info.get("polycount", 0),
        "dimensions": info.get("dimensions", []),
        "license": "CC0-1.0",
        "license_url": LICENSE_URL,
        "source": f"https://polyhaven.com/a/{asset_id}",
        "resolution": used_resolution,
        "thumbnail": thumb_name,
        "gltf": gltf_target.name,
        "files": downloaded,
        "downloaded_at": datetime.now(timezone.utc).isoformat(),
    }
    manifest_path.write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    total_mb = sum(f["bytes"] for f in downloaded) / (1024 * 1024)
    print(f"ok   {asset_id}  {record['polycount']:,} tris  {total_mb:.1f} MB")
    return record


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Fetch CC0 Poly Haven models for Code Cinema.")
    parser.add_argument("--dest", default=str(DEFAULT_DEST), help="open_assets directory.")
    parser.add_argument("--resolution", default="2k", choices=["1k", "2k", "4k"])
    parser.add_argument("--ids", default="", help="Comma-separated Poly Haven asset ids.")
    parser.add_argument("--ids-file", help="Text file with one asset id per line.")
    parser.add_argument("--force", action="store_true", help="Redownload existing assets.")
    parser.add_argument("--no-thumb", action="store_true", help="Skip thumbnails.")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    ids: list[str] = []
    if args.ids:
        ids.extend(x.strip() for x in args.ids.split(",") if x.strip())
    if args.ids_file:
        ids.extend(
            line.strip()
            for line in Path(args.ids_file).read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.strip().startswith("#")
        )
    ids = list(dict.fromkeys(ids))
    if not ids:
        parser.error("Pass --ids or --ids-file.")

    dest = Path(args.dest).expanduser().resolve()
    dest.mkdir(parents=True, exist_ok=True)
    print(f"Destination: {dest}")
    print(f"Assets: {len(ids)} @ {args.resolution}")
    if args.dry_run:
        for asset_id in ids:
            print(f"  {asset_id}")
        return 0

    records: list[dict] = []
    failures: list[tuple[str, str]] = []
    for index, asset_id in enumerate(ids, start=1):
        print(f"[{index}/{len(ids)}] {asset_id}")
        try:
            records.append(fetch_asset(asset_id, dest, args.resolution, args.force, not args.no_thumb))
        except Exception as exc:  # noqa: BLE001 - report and continue the batch
            print(f"FAIL {asset_id}: {exc}")
            failures.append((asset_id, str(exc)))

    manifest = {
        "source": "Poly Haven",
        "license": "CC0-1.0",
        "license_url": LICENSE_URL,
        "resolution": args.resolution,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "assets": records,
    }
    (dest / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    total = sum(
        f.get("bytes", 0)
        for record in records
        for f in record.get("files", [])
    )
    print(f"\nDownloaded {len(records)} assets, {total / (1024 * 1024):.1f} MB")
    if failures:
        print(f"{len(failures)} failed:")
        for asset_id, reason in failures:
            print(f"  {asset_id}: {reason}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
