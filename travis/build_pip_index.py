#!/usr/bin/env python3
"""Builds a PEP 503 "simple" pip index of the wheels attached to this repository's GitHub releases.

pip (and uv) then pick the right wheel for the machine:
    pip install vosk --index-url https://<owner>.github.io/<repo>/simple/
Needs the GitHub CLI (`gh`) with a token in GH_TOKEN.

Usage: build_pip_index.py <owner/repo> <output_dir>
"""
import html
import json
import subprocess
import sys
from pathlib import Path


def release_wheels(repo):
    """Yield (filename, download_url, sha256) of every wheel of every release."""
    output = subprocess.run(
        ["gh", "api", "--paginate", f"repos/{repo}/releases"],
        check=True, capture_output=True, text=True).stdout
    # --paginate prints one JSON array per page, back to back
    decoder, pos = json.JSONDecoder(), 0
    while pos < len(output):
        releases, pos = decoder.raw_decode(output, pos)
        while pos < len(output) and output[pos].isspace():
            pos += 1
        for release in releases:
            for asset in release["assets"]:
                if asset["name"].endswith(".whl"):
                    sha256 = asset["digest"].removeprefix("sha256:")
                    yield asset["name"], asset["browser_download_url"], sha256


def page(title, links):
    body = "\n".join(f'<a href="{html.escape(url)}">{html.escape(text)}</a><br>' for text, url in links)
    return f"<!DOCTYPE html>\n<html><head><meta name=\"pypi:repository-version\" content=\"1.0\">" \
           f"<title>{title}</title></head><body>\n{body}\n</body></html>\n"


def main(repo, output_dir):
    wheels = sorted(release_wheels(repo))
    if not wheels:
        sys.exit(f"no wheel found in the releases of {repo}")
    out = Path(output_dir)
    (out / "simple" / "vosk").mkdir(parents=True, exist_ok=True)
    (out / "simple" / "index.html").write_text(page("Simple index", [("vosk", "vosk/")]))
    (out / "simple" / "vosk" / "index.html").write_text(
        page("Links for vosk", [(name, f"{url}#sha256={sha256}") for name, url, sha256 in wheels]))
    print(f"{len(wheels)} wheels indexed")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
