#!/usr/bin/env python3
"""Validate the shared English release notes before building a DMG."""

import argparse
import json
import pathlib
import re
import sys
import unicodedata


def validate(notes_path, releases_path, tag, repository):
    match = re.fullmatch(r"v((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))-([1-9][0-9]*)", tag)
    if not match:
        raise ValueError("Release tag must use vX.Y.Z-N format.")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Repository must use owner/name format.")
    notes = notes_path.read_text(encoding="utf-8")
    title = f"# Inklet {match[1]} ({match[2]})"
    if not notes.strip().startswith(title + "\n"):
        raise ValueError(f"Release notes must start with {title}.")
    if re.search(r"\b(?:TODO|TBD)\b|待填写|在此填写|<[^>\n]+>|workflow run", notes, re.IGNORECASE):
        raise ValueError("Replace placeholders and workflow-run boilerplate with shipped changes.")

    sections = re.split(r"^## (.+)\s*$", notes, flags=re.MULTILINE)
    if sections[1::2] != ["Changes"]:
        raise ValueError("Release notes must contain ## Changes exactly once.")
    if any(character.isalpha() and "LATIN" not in unicodedata.name(character, "") for character in notes):
        raise ValueError("Release notes must use English only; remove translated sections and copy.")
    bullets = re.findall(r"^[-*] (.+)$", sections[2], re.MULTILINE)
    if not any(re.search(r"[A-Za-z]", bullet) for bullet in bullets):
        raise ValueError("Changes must include an English change bullet.")

    releases = json.loads(releases_path.read_text(encoding="utf-8"))
    if not isinstance(releases, list):
        raise ValueError("Release history must be a complete JSON array.")
    stable = []
    for release in releases:
        if (not isinstance(release, dict)
                or not isinstance(release.get("tag_name"), str)
                or not isinstance(release.get("draft"), bool)
                or not isinstance(release.get("prerelease"), bool)):
            raise ValueError("Release history contains incomplete release metadata.")
        if not release["draft"] and not release["prerelease"] and release["tag_name"] != tag:
            if not isinstance(release.get("published_at"), str) or not release["published_at"]:
                raise ValueError("Published stable releases must include published_at.")
            stable.append(release)
    if stable:
        previous = max(stable, key=lambda release: release["published_at"])["tag_name"]
        url = f"https://github.com/{repository}/compare/{previous}...{tag}"
    else:
        url = f"https://github.com/{repository}/tree/{tag}"
    if url not in re.findall(r"https://[^\s)<>]+", notes):
        raise ValueError(f"Release notes must link to the previous stable comparison: {url}")
    return f"English release notes verified: {tag}. Review English wording and shipped scope before publishing."


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("notes", type=pathlib.Path)
    parser.add_argument("releases", type=pathlib.Path)
    parser.add_argument("tag")
    parser.add_argument("repository")
    args = parser.parse_args()
    try:
        print(validate(args.notes, args.releases, args.tag, args.repository))
    except (OSError, ValueError) as error:
        print(f"Release notes check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
