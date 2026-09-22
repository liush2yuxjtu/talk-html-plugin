"""Exercise the publishing verifier through its public CLI, without platform writes."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("verify-publishing.py")


class PublishingVerifierTests(unittest.TestCase):
    def run_draft(self, body):
        with tempfile.TemporaryDirectory() as folder:
            draft = Path(folder) / "draft.md"
            draft.write_text("# Draft\nSource Airtable record: fixture\n" + body, encoding="utf-8")
            return subprocess.run([sys.executable, str(SCRIPT), "--rednote", str(draft)], capture_output=True, text=True)

    def test_rejects_placeholder_words(self):
        for placeholder in ("TODO", "TBD", "todo", "(TBD)", "正文待补", "待补充"):
            with self.subTest(placeholder=placeholder):
                result = self.run_draft("Finished content. " * 10 + "\n" + placeholder)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn("placeholder", result.stdout)

    def test_accepts_finished_text_and_non_placeholder_substrings(self):
        result = self.run_draft("Finished content about a TODOLIST identifier. " * 5)
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_whitespace_does_not_count_as_readable_content(self):
        with tempfile.TemporaryDirectory() as folder:
            payload = Path(folder) / "payload.html"
            payload.write_text("<p>" + ("a" + "\t\n " * 60) * 3 + "</p>", encoding="utf-8")
            result = subprocess.run([sys.executable, str(SCRIPT), "--wechat", str(payload), "--title", "Test"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stdout)
            self.assertIn("too little readable text", result.stdout)


if __name__ == "__main__":
    unittest.main()
