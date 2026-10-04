import unittest

from build_baseline_manifest import analyze_profile, remove_line_comments


class RemoveLineCommentsTests(unittest.TestCase):
    def test_removes_rules_inside_comments(self) -> None:
        text = "(deny default)\n; (allow network*)\n(allow file-read*)\n"

        analysis = analyze_profile(text)

        self.assertEqual(analysis.allow_count, 1)
        self.assertFalse(analysis.has_global_network)
        self.assertTrue(analysis.has_global_file_read)

    def test_preserves_semicolons_and_escaped_quotes_inside_strings(self) -> None:
        text = '(import "literal;\\\"name.sb")\n(deny default)\n'

        uncommented_text = remove_line_comments(text)

        self.assertIn('literal;\\\"name.sb', uncommented_text)
        self.assertTrue(analyze_profile(text).has_deny_default)


if __name__ == "__main__":
    unittest.main()
