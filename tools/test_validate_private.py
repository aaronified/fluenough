#!/usr/bin/env python3
"""`validate_decks.py --private`: the author's check of a private language
package (#1017). It shares the app's fixture, test/fixtures/private/qaa-tiny,
so a package that passes here imports without an error, and the validator
refuses such ids anywhere in `decks/`.

Stdlib `unittest` plus PyYAML, like the validator itself.
"""

from __future__ import annotations

import io
import shutil
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks
import validate_private

TOOLS = Path(__file__).resolve().parent
FIXTURE = TOOLS.parent / "test" / "fixtures" / "private" / "qaa-tiny"


def fixture_files() -> dict[str, bytes]:
    return {p.relative_to(FIXTURE).as_posix(): p.read_bytes()
            for p in sorted(FIXTURE.rglob("*")) if p.is_file()}


def edited(**changes: tuple[str, str]) -> dict[str, bytes]:
    """The fixture with `old` replaced by `new` in each named file; the key is
    the file's name with `/`, `.` and `-` written as `_`."""
    files = fixture_files()
    for name, (old, new) in changes.items():
        target = next(n for n in files
                      if n.replace("/", "_").replace(".", "_").replace("-", "_") == name)
        text = files[target].decode("utf-8")
        assert old in text, (name, old)
        files[target] = text.replace(old, new, 1).encode("utf-8")
    return files


class PackageChecks(unittest.TestCase):
    def test_the_fixture_is_a_good_package(self) -> None:
        files = fixture_files()
        self.assertEqual(validate_private.check_files(files, None), [])
        errors, warnings, manifest = validate_private.check_package(files)
        self.assertEqual(errors, [])
        self.assertEqual(warnings, [])
        self.assertEqual(manifest["package"], "fnpd-qaa")

    def test_a_zip_reads_as_its_folder(self) -> None:
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp, True)
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as z:
            for name, data in fixture_files().items():
                z.writestr(name, data)
        archive = tmp / "tiny.fnzip"
        archive.write_bytes(buffer.getvalue())
        files, size, errors = validate_private.load(archive)
        self.assertEqual(errors, [])
        self.assertEqual(size, len(buffer.getvalue()))
        self.assertEqual(files, fixture_files())
        self.assertEqual(validate_private.check_files(files, size), [])

    def test_an_id_without_the_prefix_is_an_error(self) -> None:
        files = edited(qaa_fnpd_qaa_home_yaml=('id: "fnpd-qaa-0001"', 'id: "qaa-0001"'))
        errors, _, _ = validate_private.check_package(files)
        self.assertTrue(any("must start with 'fnpd-qaa-'" in e for e in errors), errors)

    def test_a_card_id_written_twice_is_an_error(self) -> None:
        files = edited(qaa_fnpd_qaa_home_yaml=('id: "fnpd-qaa-0002"', 'id: "fnpd-qaa-0001"'))
        errors, _, _ = validate_private.check_package(files)
        self.assertTrue(any("is also in" in e for e in errors), errors)

    def test_a_layer_key_without_the_prefix_is_an_error(self) -> None:
        files = edited(qaa_en_fnpd_qaa_en_home_yaml=('"fnpd-qaa-0001":', '"qaa-0001":'))
        errors, _, _ = validate_private.check_package(files)
        self.assertTrue(any("'qaa-0001' must start with" in e for e in errors), errors)

    def test_a_path_unit_must_name_a_deck_the_package_has(self) -> None:
        files = edited(qaa_path_yaml=('"fnpd-qaa-food"', '"fnpd-qaa-drinks"'))
        errors, _, _ = validate_private.check_package(files)
        self.assertTrue(any("fnpd-qaa-drinks" in e for e in errors), errors)

    def test_a_new_language_needs_a_private_use_code(self) -> None:
        files = edited(
            manifest_yaml=('package: "fnpd-qaa"', 'package: "fnpd-te"'),
        )
        text = files["manifest.yaml"].decode("utf-8").replace('code: "qaa"', 'code: "te"')
        files["manifest.yaml"] = text.encode("utf-8")
        errors, _, _ = validate_private.check_package(files)
        self.assertTrue(any("private-use code" in e for e in errors), errors)

    def test_a_built_in_private_use_code_is_taken(self) -> None:
        text = fixture_files()["manifest.yaml"].decode("utf-8")
        text = text.replace("fnpd-qaa", "fnpd-qgh").replace('code: "qaa"', 'code: "qgh"')
        files = {**fixture_files(), "manifest.yaml": text.encode("utf-8")}
        errors, _, _ = validate_private.check_package(files)
        self.assertTrue(any("private-use code" in e for e in errors), errors)

    def test_a_wrong_licence_is_an_error(self) -> None:
        files = edited(manifest_yaml=('license: "CC-BY-SA-4.0"', 'license: "MIT"'))
        errors, _, _ = validate_private.check_package(files)
        self.assertTrue(any("license" in e for e in errors), errors)

    def test_no_manifest_is_an_error(self) -> None:
        files = fixture_files()
        del files["manifest.yaml"]
        errors, _, manifest = validate_private.check_package(files)
        self.assertIsNone(manifest)
        self.assertTrue(any("no manifest" in e for e in errors), errors)

    def test_the_built_in_private_use_codes_match_the_languages_file(self) -> None:
        import yaml

        raw = yaml.safe_load((TOOLS.parent / "assets" / "languages.yaml").read_text(encoding="utf-8"))
        taken = {entry["code"] for entry in raw["languages"]
                 if validate_private.PRIVATE_USE_RE.fullmatch(entry["code"])}
        self.assertEqual(taken, validate_private.BUILT_IN_PRIVATE_USE)


class UnsafeFiles(unittest.TestCase):
    def test_names_that_could_leave_the_folder_are_refused(self) -> None:
        for name in ("../evil.yaml", "/abs.yaml", "a\\b.yaml", ".hidden.yaml", "a//b.yaml", "c:x.yaml"):
            with self.subTest(name=name):
                errors = validate_private.check_files({name: b"a: 1\n"}, None)
                self.assertTrue(errors, name)

    def test_a_name_used_twice_ignoring_case_is_refused(self) -> None:
        errors = validate_private.check_files(
            {"manifest.yaml": b"a: 1\n", "Manifest.yaml": b"a: 1\n"}, None)
        self.assertTrue(any("used twice" in e for e in errors), errors)

    def test_only_yaml_and_json_files(self) -> None:
        errors = validate_private.check_files({"font.ttf": b"x"}, None)
        self.assertTrue(any("only .yaml and .json" in e for e in errors), errors)

    def test_size_limits(self) -> None:
        big = b"a: " + b"x" * validate_private.FILE_MAX + b"\n"
        errors = validate_private.check_files({"big.yaml": big}, None)
        self.assertTrue(any("big.yaml" in e for e in errors), errors)
        errors = validate_private.check_files({}, validate_private.ARCHIVE_MAX + 1)
        self.assertTrue(any("the archive is" in e for e in errors), errors)

    def test_text_that_is_not_utf8_is_refused(self) -> None:
        errors = validate_private.check_files({"a.yaml": b"\xff\xfe"}, None)
        self.assertTrue(any("not UTF-8" in e for e in errors), errors)


class RefusedUnderDecks(unittest.TestCase):
    """The repository never holds a private package: the validator, outside
    `--private`, refuses its ids and its manifest."""

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def test_a_private_deck_is_refused(self) -> None:
        path = self.tmp / "fnpd-qaa-home.yaml"
        path.write_bytes(fixture_files()["qaa/fnpd-qaa-home.yaml"])
        report = validate_decks.validate(path)
        self.assertTrue(any("private id" in e for e in report.errors), report.errors)

    def test_a_private_layer_is_refused(self) -> None:
        path = self.tmp / "fnpd-qaa-en-home.yaml"
        path.write_bytes(fixture_files()["qaa/en/fnpd-qaa-en-home.yaml"])
        report = validate_decks.validate(path)
        self.assertTrue(any("private id" in e for e in report.errors), report.errors)

    def test_a_private_manifest_is_refused(self) -> None:
        path = self.tmp / "manifest.yaml"
        path.write_bytes(fixture_files()["manifest.yaml"])
        report = validate_decks.validate(path)
        self.assertTrue(any("private package" in e for e in report.errors), report.errors)

    def test_private_mode_does_not_leak(self) -> None:
        validate_private.check_decks(fixture_files(), "qaa")
        self.assertFalse(validate_decks.PRIVATE_MODE)


class DeckChecks(unittest.TestCase):
    def test_ids_are_written_as_the_repository_writes_them(self) -> None:
        self.assertEqual(
            validate_private.translate('id: "fnpd-qaa-0001"\ncore: "fnpd-qaa-home"', "qaa"),
            'id: "qaa-0001"\ncore: "qaa-home"',
        )
        # Another language's private id is not touched.
        self.assertEqual(validate_private.translate('id: "fnpd-qab-0001"', "qaa"),
                         'id: "fnpd-qab-0001"')

    def test_each_deck_and_layer_is_checked_under_the_package_name(self) -> None:
        reports = validate_private.check_decks(fixture_files(), "qaa")
        self.assertEqual(
            [r.path.as_posix() for r in reports],
            ["qaa/en/fnpd-qaa-en-food.yaml", "qaa/en/fnpd-qaa-en-home.yaml",
             "qaa/fnpd-qaa-food.yaml", "qaa/fnpd-qaa-home.yaml"],
        )
        for report in reports:
            for error in report.errors:
                self.assertNotIn("fnpd-", error, f"{report.path}: {error}")


class Command(unittest.TestCase):
    def test_a_missing_package_is_a_bad_argument(self) -> None:
        self.assertEqual(validate_private.main(["no-such-package-here"]), 2)

    def test_no_argument_is_a_bad_argument(self) -> None:
        self.assertEqual(validate_private.main([]), 2)

    def test_a_package_with_an_error_exits_one(self) -> None:
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp, True)
        for name, data in edited(manifest_yaml=('license: "CC-BY-SA-4.0"', 'license: "MIT"')).items():
            target = tmp / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        self.assertEqual(validate_private.main([str(tmp)]), 1)


if __name__ == "__main__":
    unittest.main()
