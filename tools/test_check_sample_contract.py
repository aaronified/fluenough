import unittest

import check_sample_contract as c

KINDS = {"vocab", "layer", "path"}


def index(version=1, schema=1, kinds=("vocab",), **extra):
    return {"version": version, "schema": schema, "bundled": [],
            "languages": [{"code": "zz", "files": [{"kind": k} for k in kinds]}], **extra}


class SampleContract(unittest.TestCase):
    def test_same_format_passes(self):
        errors, _ = c.check(index(), index(), KINDS)
        self.assertEqual(errors, [])

    def test_a_newer_index_version_fails(self):
        errors, _ = c.check(index(), index(version=2), KINDS)
        self.assertTrue(any("version" in e for e in errors))

    def test_a_newer_schema_fails(self):
        errors, _ = c.check(index(), index(schema=2), KINDS)
        self.assertTrue(any("schema" in e for e in errors))

    def test_a_new_top_level_key_fails(self):
        errors, _ = c.check(index(), index(extra_key=[]), KINDS)
        self.assertTrue(any("extra_key" in e for e in errors))

    def test_an_unknown_kind_fails(self):
        errors, _ = c.check(index(), index(kinds=("vocab", "mystery")), KINDS)
        self.assertTrue(any("mystery" in e for e in errors))

    def test_kinds_the_sample_lacks_are_only_noted(self):
        errors, notes = c.check(index(), index(), KINDS)
        self.assertEqual(errors, [])
        self.assertTrue(any("layer" in n and "path" in n for n in notes))


if __name__ == "__main__":
    unittest.main()
