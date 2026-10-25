#!/usr/bin/env python3
"""Download the curated Open-Source 3D Asset Directory 2026 pack list.

Usage:
  python fetch_asset_directory.py --dest D:/code-cinema/studio/open_assets/pdf_2026

Behavior:
- Downloads directly parseable pack archives.
- Records unknown/manual sources in manifest.json instead of failing silently.
- Never deletes or overwrites a completed archive without --force.
- Poly Haven entries are API-based and remain available through fetch_open_assets.py.
"""

from __future__ import annotations

import argparse
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from cc_common import SKILL_ROOT, ensure_dir, fail, log, tail

USER_AGENT = "code-cinema-asset-directory/1.0"
CATALOG = SKILL_ROOT / "assets" / "pdf_asset_directory_2026.json"
ARCHIVE_EXTENSIONS = (".zip", ".7z", ".rar", ".tar.gz", ".tgz", ".blend")
ARCHIVE_RE = re.compile(
    r"https?://[^'\"<> ]+?(?:\.zip|\.7z|\.rar|\.tar\.gz|\.tgz|\.blend)",
    re.IGNORECASE,
)
KENNEY_RE = re.compile(
    r"https://kenney\.nl/media/pages/assets/[^'\"<> ]+?\.zip",
    re.IGNORECASE,
)
BLENDER_RE = re.compile(
    r"(?:https://studio\.blender\.org)?/download-source/files/[^'\"<> ]+?\.(?:zip|blend)",
    re.IGNORECASE,
)
OPEN_GAME_ART_RE = re.compile(
    r"https://opengameart\.org/sites/default/files/[^'\"<> ]+?(?:\.zip|\.7z|\.rar|\.tar\.gz|\.tgz|\.blend|\.glb|\.gltf|\.fbx|\.obj)",
    re.IGNORECASE,
)
DRIVE_RE = re.compile(
    r"https://drive\.google\.com/drive/folders/[^'\"<> ]+",
    re.IGNORECASE,
)
ITCH_DOWNLOAD_RE = re.compile(
    r"https?://[^'\"<> ]*itch\.io[^'\"<> ]*?/download/[^'\"<> ]+",
    re.IGNORECASE,
)


def request_bytes(url: str, timeout: int = 180) -> tuple[bytes, int]:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return response.read(), response.status


def fetch_text(url: str, timeout: int = 60) -> str:
    raw, _ = request_bytes(url, timeout=timeout)
    return raw.decode("utf-8", "replace")


def clean_url(value: str) -> str:
    value = value.replace("&amp;", "&")
    return value.rstrip("\\").rstrip()


def safe_filename(value: str, fallback: str) -> str:
    parsed = urllib.parse.urlparse(value)
    name = Path(parsed.path).name
    suffix = Path(name).suffix.lower()
    if not name or suffix not in {".zip", ".7z", ".rar", ".gz", ".tgz", ".blend", ".glb", ".gltf", ".fbx", ".obj"}:
        name = fallback
    name = re.sub(r"[^A-Za-z0-9._-]+", "_", name)
    return name[:180] or fallback


def itch_download_link(text: str) -> tuple[str, str]:
    match = re.search(r'generate_download_url":"([^"]+)"', text)
    if not match:
        return "", ""
    endpoint = clean_url(match.group(1).replace("\\/", "/"))
    try:
        req = urllib.request.Request(
            endpoint,
            data=b"download=1",
            headers={"User-Agent": USER_AGENT, "Content-Type": "application/x-www-form-urlencoded"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=180) as response:
            payload = json.loads(response.read().decode("utf-8", "replace"))
        return str(payload.get("url", "")), ""
    except Exception as exc:  # noqa: BLE001 - report in manifest note
        return "", f"itch.io download_url failed: {exc}"


def source_direct_links(entry: dict) -> tuple[list[str], str]:
    page_url = entry["page_url"]
    host = urllib.parse.urlparse(page_url).netloc.lower()
    try:
        text = fetch_text(page_url)
    except Exception as exc:  # noqa: BLE001 - reported to manifest
        return [], f"Could not fetch page: {exc}"

    links: list[str] = []
    note = ""
    if "kenney.nl" in host:
        links = [clean_url(m.group(0)) for m in KENNEY_RE.finditer(text)]
    elif "studio.blender.org" in host:
        links = [
            urllib.parse.urljoin("https://studio.blender.org", clean_url(m.group(0)))
            for m in BLENDER_RE.finditer(text)
        ]
    elif "opengameart.org" in host:
        oga_links = [clean_url(m.group(0)) for m in OPEN_GAME_ART_RE.finditer(text)]
        archive_links = [
            link
            for link in oga_links
            if any(link.lower().split("?")[0].endswith(ext) for ext in (".zip", ".7z", ".tar.gz", ".tgz", ".rar"))
        ]
        links = archive_links if archive_links else oga_links
    elif "quaternius" in host or "kaylousberg.itch.io" in host:
        drive = [clean_url(m.group(0)) for m in DRIVE_RE.finditer(text)]
        direct = [
            clean_url(m.group(0))
            for m in ARCHIVE_RE.finditer(text)
            if not any(x in m.group(0) for x in ("itch.io/", "drive.google.com"))
        ]
        itch_signed, itch_note = itch_download_link(text)
        if itch_note:
            note = itch_note
        links = ([itch_signed] if itch_signed else []) + direct
        if drive and not links:
            note = "Google Drive folder found; automated download requires gdown or a browser."
    else:
        links = [
            clean_url(m.group(0))
            for m in ARCHIVE_RE.finditer(text)
        ]

    unique: list[str] = []
    for link in links:
        if link and link not in unique:
            unique.append(link)
    return unique, note


def download_archive(url: str, target: Path, force: bool = False) -> int:
    if target.exists() and not force:
        return target.stat().st_size

    part = target.with_suffix(target.suffix + ".part")
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=300) as response, part.open("wb") as handle:
                total = int(response.headers.get("Content-Length", "0") or 0)
                read = 0
                next_report = 20 * 1024 * 1024
                while True:
                    chunk = response.read(1024 * 512)
                    if not chunk:
                        break
                    handle.write(chunk)
                    read += len(chunk)
                    if total and read >= next_report:
                        print(f"    {read / 1024 / 1024:.1f} / {total / 1024 / 1024:.1f} MB", flush=True)
                        next_report += 20 * 1024 * 1024
            if target.exists():
                target.unlink(missing_ok=True)
            with part.open("rb") as handle:
                prefix = handle.read(512).lstrip()
            if prefix.startswith(b"<!DOCTYPE") or prefix.startswith(b"<html") or prefix.startswith(b'{"errors"'):
                part.unlink(missing_ok=True)
                raise RuntimeError("Download URL returned HTML/JSON instead of an archive.")
            part.replace(target)
            return target.stat().st_size
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            last_error = exc
            if part.exists():
                part.unlink(missing_ok=True)
            if attempt < 2:
                time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"Could not download {url}: {last_error}")


def write_entry_license(entry: dict, target: Path) -> None:
    target.write_text(
        (
            f"Pack: {entry['id']} - {entry['name']}\n"
            f"Author: {entry['author']}\n"
            f"Source: {entry['page_url']}\n"
            f"License: {entry['license']}\n"
            f"Attribution: {entry['attribution']}\n"
        ),
        encoding="utf-8",
    )


def process_entry(
    entry: dict,
    dest: Path,
    force: bool,
    files: list[dict],
    errors: list[dict],
) -> dict:
    entry_id = entry["id"]
    target_dir = ensure_dir(dest / entry_id)
    print(f"[{entry_id}] {entry['name']}")

    strategy = str(entry.get("download_strategy", "page"))
    if strategy == "polyhaven_api":
        note = entry.get("note", "Poly Haven API source.")
        print(f"  manual: {note}")
        return {
            **{k: entry[k] for k in ("id", "name", "author", "page_url", "license", "attribution")},
            "status": "manual",
            "files": [],
            "note": note,
        }

    links, note = source_direct_links(entry)
    if note:
        print(f"  note: {note}")
    if not links:
        reason = note or "No direct archive link found on the source page."
        print(f"  FAIL: {reason}")
        errors.append({"id": entry_id, "name": entry["name"], "reason": reason})
        return {
            **{k: entry[k] for k in ("id", "name", "author", "page_url", "license", "attribution")},
            "status": "failed",
            "files": [],
            "note": reason,
        }

    downloaded: list[dict] = []
    failures: list[dict] = []
    for index, url in enumerate(links, start=1):
        name = safe_filename(url, f"{entry_id}_{index}.zip")
        target = target_dir / name
        if target.exists() and not force:
            print(f"  skip {name} (exists)")
            downloaded.append({"url": url, "path": str(target.relative_to(dest)), "bytes": target.stat().st_size})
            continue
        try:
            size = download_archive(url, target, force=force)
            print(f"  ok   {name} ({size / 1024 / 1024:.1f} MB)")
            downloaded.append({"url": url, "path": str(target.relative_to(dest)), "bytes": size})
            files.append({"id": entry_id, "path": target})
        except Exception as exc:  # noqa: BLE001 - manifest reason
            reason = str(exc)
            print(f"  FAIL {name}: {reason}")
            failures.append({"url": url, "reason": reason})
            errors.append({"id": entry_id, "name": entry["name"], "reason": reason})

    write_entry_license(entry, target_dir / "LICENSE.txt")
    page_path = target_dir / "PAGE.html"
    if links and not page_path.exists():
        try:
            page_path.write_text(fetch_text(entry["page_url"]), encoding="utf-8")
        except Exception:
            page_path.write_text(entry["page_url"], encoding="utf-8")
    if failures:
        note = note or failures[0]["reason"]
    status = "downloaded" if downloaded and not failures else ("partial" if downloaded else "failed")
    return {
        **{k: entry[k] for k in ("id", "name", "author", "page_url", "license", "attribution")},
        "status": status,
        "files": downloaded,
        "failures": failures,
        "note": note,
    }


def build_credits(records: list[dict], path: Path) -> None:
    lines = [
        "# Code Cinema open asset credits",
        "",
        "Generated from the Open-Source 3D Asset Directory 2026.",
        "",
        "| ID | Pack | Author | License | Attribution / terms |",
        "|---|---|---|---|---|",
    ]
    for record in records:
        attribution = str(record.get("attribution", "")).replace("|", "/")
        lines.append(
            f"| {record['id']} | {record['name']} | {record['author']} | "
            f"{record['license']} | {attribution} |"
        )
    lines += ["", "Only CC-BY assets require an end-credit line."]
    path.write_text("\n".join(lines), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Download the curated 2026 open-source 3D asset pack directory.")
    parser.add_argument("--dest", default=str(SKILL_ROOT.parent.parent.parent / "studio" / "open_assets" / "pdf_2026"))
    parser.add_argument("--catalog", default=str(CATALOG))
    parser.add_argument("--only", default="", help="Comma-separated entry IDs.")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    catalog_path = Path(args.catalog).resolve()
    if not catalog_path.exists():
        parser.error(f"Catalog not found: {catalog_path}")
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    entries = catalog.get("entries", [])
    only = [x.strip().upper() for x in args.only.split(",") if x.strip()]
    if only:
        entries = [e for e in entries if str(e.get("id", "")).upper() in only]
        missing = set(only) - {str(e.get("id", "")).upper() for e in entries}
        if missing:
            parser.error(f"Unknown catalog IDs: {', '.join(sorted(missing))}")
    if not entries:
        parser.error("No entries selected.")

    dest = Path(args.dest).expanduser().resolve()
    ensure_dir(dest)
    log(f"Catalog: {catalog_path}")
    log(f"Destination: {dest}")
    log(f"Entries: {len(entries)}")

    if args.dry_run:
        for entry in entries:
            log(f"  {entry['id']}  {entry['name']}  {entry['page_url']}")
        return 0

    records: list[dict] = []
    files: list[dict] = []
    errors: list[dict] = []
    for entry in entries:
        try:
            records.append(process_entry(entry, dest, args.force, files, errors))
        except Exception as exc:  # noqa: BLE001 - keep batch running
            reason = f"Unhandled failure: {exc}"
            log(f"  FAIL: {reason}")
            records.append(
                {
                    **{k: entry[k] for k in ("id", "name", "author", "page_url", "license", "attribution")},
                    "status": "failed",
                    "files": [],
                    "note": reason,
                }
            )
            errors.append({"id": entry["id"], "name": entry["name"], "reason": reason})

    manifest = {
        "source": "Open-Source 3D Asset Directory 2026",
        "catalog": str(catalog_path),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "download_root": str(dest),
        "entries": records,
        "errors": errors,
    }
    (dest / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    build_credits(records, dest / "CREDITS.md")

    downloaded = [r for r in records if r["status"] in {"downloaded", "partial"}]
    manual = [r for r in records if r["status"] == "manual"]
    failed = [r for r in records if r["status"] in {"failed"}]
    log("")
    log(f"Downloaded: {len(downloaded)}")
    log(f"Manual/API: {len(manual)}")
    log(f"Failed: {len(failed)}")
    if failed:
        for record in failed:
            log(f"  {record['id']}: {record.get('note', '')}")
    log(f"Manifest: {dest / 'manifest.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
