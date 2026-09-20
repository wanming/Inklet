#!/usr/bin/env python3
"""Release note and workflow regression checks using synthetic releases only."""

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
CHECKER = ROOT / "scripts/check-release-notes.py"
TAG = "v1.2.0-20"
NOTES = """# Inklet 1.2.0 (20)

## 中文

- 改善选区翻译的稳定性。

## English

- Improve selection translation reliability.

**Full changelog / 完整改动**: https://github.com/example/Inklet/compare/v1.1.0-18...v1.2.0-20
"""
RELEASES = [
    {"tag_name": "v1.1.0-18", "draft": False, "prerelease": False,
     "published_at": "2026-09-10T10:00:00Z"},
    {"tag_name": "v1.0.0-4", "draft": False, "prerelease": False,
     "published_at": "2026-08-10T10:00:00Z"},
    {"tag_name": "v1.2.0-19", "draft": True, "prerelease": False,
     "published_at": None},
    {"tag_name": "v1.3.0-21", "draft": False, "prerelease": True,
     "published_at": "2026-09-19T10:00:00Z"},
]


class ReleaseNotesTests(unittest.TestCase):
    def check_notes(self, notes=NOTES, releases=RELEASES):
        self.assertTrue(CHECKER.is_file(), "Release notes validation is missing")
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            path = root / "notes.md"
            if notes is not None:
                path.write_text(notes, encoding="utf-8")
            history = root / "releases.json"
            history.write_text(json.dumps(releases), encoding="utf-8")
            return subprocess.run(
                [sys.executable, str(CHECKER), str(path), str(history), TAG, "example/Inklet"],
                text=True, capture_output=True,
            )

    def test_accepts_bilingual_notes_against_latest_stable_not_draft_or_prerelease(self):
        result = self.check_notes(releases=list(reversed(RELEASES)))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_missing_empty_or_wrong_version_notes(self):
        for notes in (None, "", NOTES.replace("1.2.0 (20)", "1.2.0 (19)")):
            with self.subTest(notes=notes):
                self.assertNotEqual(self.check_notes(notes).returncode, 0)

    def test_rejects_missing_language_or_empty_language_section(self):
        for notes in (
            NOTES.replace("## 中文", "## Changes"),
            NOTES.replace("## English", "## Changes"),
            NOTES.replace("- 改善选区翻译的稳定性。", ""),
            NOTES.replace("- Improve selection translation reliability.", ""),
            NOTES.replace("改善选区翻译的稳定性。", "Improve selection reliability."),
            NOTES.replace("Improve selection translation reliability.", "改善稳定性。"),
            NOTES.replace("## 中文", "## English").replace("## English\n\n- Improve", "## 中文\n\n- Improve"),
        ):
            with self.subTest(notes=notes):
                self.assertNotEqual(self.check_notes(notes).returncode, 0)

    def test_rejects_placeholder_and_workflow_boilerplate(self):
        for placeholder in ("TODO", "TBD", "待填写", "<English summary>",
                            "macOS DMG build 1.2.0 (20) from workflow run 100."):
            with self.subTest(placeholder=placeholder):
                self.assertNotEqual(self.check_notes(NOTES + placeholder).returncode, 0)

    def test_rejects_wrong_comparison_baseline_target_or_repository(self):
        for old, new in (("v1.1.0-18...", "v1.0.0-4..."),
                         ("...v1.2.0-20", "...v1.2.0-19"),
                         ("example/Inklet", "other/Inklet")):
            with self.subTest(new=new):
                self.assertNotEqual(self.check_notes(NOTES.replace(old, new)).returncode, 0)

    def test_first_release_links_to_release_tree(self):
        result = self.check_notes(
            NOTES.replace("compare/v1.1.0-18...v1.2.0-20", "tree/v1.2.0-20"), []
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_malformed_history(self):
        for history in ({}, [None], [{"tag_name": "v1.1.0-18"}]):
            with self.subTest(history=history):
                self.assertNotEqual(self.check_notes(releases=history).returncode, 0)


class ReleaseWorkflowTests(unittest.TestCase):
    def setUp(self):
        result = subprocess.run(
            ["/usr/bin/ruby", "-ryaml", "-rjson", "-e",
             "puts JSON.generate(YAML.load_file(ARGV.fetch(0)))",
             str(ROOT / ".github/workflows/build-dmg.yml")],
            check=True, text=True, capture_output=True,
        )
        self.workflow = json.loads(result.stdout)
        self.steps = self.workflow["jobs"]["build-dmg"]["steps"]

    def step(self, name):
        steps = [step for step in self.steps if step.get("name") == name]
        self.assertEqual(len(steps), 1, f"Missing workflow step: {name}")
        return steps[0]

    def test_defaults_to_draft(self):
        # Ruby YAML 1.1 parses the unquoted `on` key as true.
        trigger = self.workflow.get("on", self.workflow.get("true"))
        self.assertIs(trigger["workflow_dispatch"]["inputs"]["draft"]["default"], True)

    def test_rejects_non_main_before_signing(self):
        guard = self.step("Check release source")
        self.assertLess(self.steps.index(guard), self.steps.index(self.step("Import Developer ID certificate")))
        for ref in ("refs/heads/main", "refs/heads/feature", "refs/tags/v1.2.0-20"):
            with self.subTest(ref=ref):
                result = subprocess.run(["/bin/bash", "-c", guard["run"]],
                                        env=dict(os.environ, GITHUB_REF=ref), capture_output=True)
                self.assertEqual(result.returncode == 0, ref == "refs/heads/main")

    def test_checks_committed_notes_before_signing_and_fails_on_fetch_error(self):
        guard = self.step("Check release notes")
        self.assertLess(self.steps.index(guard), self.steps.index(self.step("Import Developer ID certificate")))
        for missing, fetch_error in ((False, False), (True, False), (False, True)):
            with self.subTest(missing=missing, fetch_error=fetch_error), tempfile.TemporaryDirectory() as directory:
                root = pathlib.Path(directory)
                (root / "scripts").symlink_to(ROOT / "scripts")
                (root / "docs/releases").mkdir(parents=True)
                if not missing:
                    (root / f"docs/releases/{TAG}.md").write_text(NOTES, encoding="utf-8")
                gh = root / "gh"
                gh.write_text("#!/bin/bash\nset -eu\n" +
                              '[[ "$*" == *"--paginate"* && "$*" == *"--slurp"* ]]\n' +
                              '[[ "$*" != *"--jq"* ]]\n' +
                              ("exit 1\n" if fetch_error else
                               "cat <<'JSON'\n" + json.dumps([RELEASES[:2], RELEASES[2:]]) + "\nJSON\n"))
                gh.chmod(0o755)
                result = subprocess.run(
                    ["/bin/bash", "-c", guard["run"]], cwd=root, capture_output=True, text=True,
                    env=dict(os.environ, PATH=f"{root}:{os.environ['PATH']}", RUNNER_TEMP=str(root),
                             GITHUB_REPOSITORY="example/Inklet", TAG_NAME=TAG),
                )
                self.assertEqual(result.returncode == 0, not missing and not fetch_error, result.stderr)

    def test_uploads_before_publishing_and_uses_tracked_notes_for_all_modes(self):
        publish = self.step("Publish GitHub release")["run"]
        for existing, draft, prerelease, upload_fails in (
            (False, "false", "false", False), (True, "false", "false", False),
            (False, "true", "false", False), (False, "false", "true", False),
            (False, "false", "false", True),
        ):
            with self.subTest(existing=existing, draft=draft, prerelease=prerelease, upload_fails=upload_fails):
                with tempfile.TemporaryDirectory() as directory:
                    root = pathlib.Path(directory)
                    gh = root / "gh"
                    gh.write_text("#!/usr/bin/env python3\nimport json, os, sys\n"
                                  "with open(os.environ['CALLS'], 'a') as out: out.write(json.dumps(sys.argv[1:]) + '\\n')\n"
                                  "if sys.argv[1:3] == ['release', 'view']: sys.exit(0 if os.environ['EXISTING'] == '1' else 1)\n"
                                  "if sys.argv[1:3] == ['release', 'upload']: sys.exit(int(os.environ['UPLOAD_FAILS']))\n")
                    gh.chmod(0o755)
                    calls_path = root / "calls.jsonl"
                    result = subprocess.run(
                        ["/bin/bash", "-c", publish], cwd=root, capture_output=True, text=True,
                        env=dict(os.environ, PATH=f"{root}:{os.environ['PATH']}", CALLS=str(calls_path),
                                 EXISTING=str(int(existing)), UPLOAD_FAILS=str(int(upload_fails)),
                                 TAG_NAME=TAG, RELEASE_NAME="Inklet 1.2.0 (20)", DRAFT=draft,
                                 PRERELEASE=prerelease, GITHUB_SHA="fixture-sha", APP_VERSION="1.2.0",
                                 BUILD_NUMBER="20", GITHUB_RUN_NUMBER="100"),
                    )
                    self.assertEqual(result.returncode == 0, not upload_fails, result.stderr)
                    calls = [json.loads(line) for line in calls_path.read_text().splitlines()]
                    prepare = next(call for call in calls if call[1] in ("create", "edit"))
                    self.assertIn("--notes-file", prepare)
                    self.assertEqual(prepare[prepare.index("--notes-file") + 1], f"docs/releases/{TAG}.md")
                    if not existing:
                        self.assertIn("--draft", prepare)
                    public_edits = [call for call in calls if "--draft=false" in call]
                    if upload_fails or draft == "true":
                        self.assertFalse(public_edits)
                    else:
                        self.assertEqual(len(public_edits), 1)
                        upload = next(call for call in calls if call[1] == "upload")
                        self.assertLess(calls.index(upload), calls.index(public_edits[0]))
                        self.assertIn(f"--prerelease={prerelease}", public_edits[0])
                        self.assertIn(f"--latest={'false' if prerelease == 'true' else 'true'}", public_edits[0])


if __name__ == "__main__":
    unittest.main()
