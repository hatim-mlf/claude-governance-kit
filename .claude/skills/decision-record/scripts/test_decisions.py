"""Tests for decisions.py. Run: python3 -m pytest .claude/skills/decision-record/scripts -q"""
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import decisions  # noqa: E402

DATA = """\
### D-1 — Keep the speed prior off until the held-out rides
- **Date:** 2026-11-26
- **Kind:** data
- **Door:** two-way
- **Decided by:** debate 2026-W48-65
- **Decision:** P2 stays off by default.
- **Prediction:** H1 and H2 keep P2 on all five conditions.
- **Confidence:** 60 %
- **Overturn if:** within 5 rpm falls by more than 0 s, or over-reads rise.
- **Checked by:** `H1`, `H2`
- **Status:** awaiting check
- **Record:** reports/logs/x/decision.md
"""

VALUES = """\
### D-2 — Microphone for the freehub test
- **Date:** 2026-11-27
- **Kind:** values
- **Door:** one-way
- **Decision:** not decided.
- **Premortem:** a rider finds the app listening and leaves.
- **Status:** awaiting operator
- **Record:** reports/logs/y/brief.md
"""

CHEAP = """\
### D-3 — Name of the pipeline command
- **Date:** 2026-11-27
- **Kind:** reversible
- **Door:** two-way
- **Decision:** call it ride_pipeline.py.
- **Status:** held
- **Check:** 2026-11-27, used in 22 tests; information missed: no.
- **Record:** scripts/sensors/ride_pipeline.py
"""


def register(*entries):
    return "# Decision register\n\nIntro text.\n\n" + "\n".join(entries)


def problems(text):
    return decisions.lint(decisions.parse(text))


class LintTests(unittest.TestCase):
    def test_a_complete_register_passes(self):
        self.assertEqual(problems(register(DATA, VALUES, CHEAP)), [])

    def test_a_data_decision_without_a_number_in_overturn_if_fails(self):
        bad = DATA.replace("within 5 rpm falls by more than 0 s, or over-reads rise.", "it looks worse.")
        self.assertTrue(any("number" in p for p in problems(register(bad))))

    def test_a_data_decision_without_an_event_fails(self):
        bad = DATA.replace("`H1`, `H2`", "after some rides")
        self.assertTrue(any("event" in p for p in problems(register(bad))))

    def test_a_data_decision_needs_a_confidence_between_1_and_99(self):
        for value in ("", "100 %", "likely"):
            bad = DATA.replace("60 %", value)
            self.assertTrue(any("Confidence" in p for p in problems(register(bad))), value)

    def test_a_confidence_may_say_who_gave_it(self):
        ok = DATA.replace("60 %", "60 % (Claude, at seeding)")
        self.assertEqual(problems(register(ok)), [])

    def test_a_one_way_door_needs_a_premortem(self):
        bad = VALUES.replace("- **Premortem:** a rider finds the app listening and leaves.\n", "")
        self.assertTrue(any("Premortem" in p for p in problems(register(bad))))

    def test_a_values_decision_needs_the_operators_answer_or_to_be_waiting_for_it(self):
        bad = VALUES.replace("awaiting operator", "held")
        self.assertTrue(any("Principle" in p for p in problems(register(bad))))

    def test_an_unknown_status_fails(self):
        bad = DATA.replace("awaiting check", "probably fine")
        self.assertTrue(any("Status" in p for p in problems(register(bad))))

    def test_a_resolved_decision_needs_its_check(self):
        bad = CHEAP.replace("- **Check:** 2026-11-27, used in 22 tests; information missed: no.\n", "")
        self.assertTrue(any("Check" in p for p in problems(register(bad))))

    def test_superseded_must_name_an_existing_decision(self):
        ok = DATA.replace("awaiting check", "superseded by D-3")
        self.assertEqual(problems(register(ok, VALUES, CHEAP)), [])
        bad = DATA.replace("awaiting check", "superseded by D-9")
        self.assertTrue(any("D-9" in p for p in problems(register(bad, VALUES, CHEAP))))

    def test_duplicate_ids_fail(self):
        self.assertTrue(any("duplicate" in p for p in problems(register(DATA, DATA))))

    def test_a_missing_field_is_named(self):
        bad = DATA.replace("- **Record:** reports/logs/x/decision.md\n", "")
        self.assertTrue(any("Record" in p for p in problems(register(bad))))


class ParseTests(unittest.TestCase):
    def test_indented_lines_and_sub_bullets_continue_the_field_above(self):
        wrapped = DATA.replace(
            "- **Prediction:** H1 and H2 keep P2 on all five conditions.\n",
            "- **Prediction:**\n  - H1 keeps P2;\n\n  - H2 keeps P2.\n").replace(
            "- **Overturn if:** within 5 rpm falls by more than 0 s, or over-reads rise.\n",
            "- **Overturn if:** within 5 rpm falls\n  by more than 0 s.\n")
        e = decisions.parse(register(wrapped))[0]
        self.assertIn("H2 keeps P2", e.get("Prediction"))
        self.assertIn("by more than 0 s", e.get("Overturn if"))
        self.assertEqual(decisions.lint([e]), [])

    def test_an_unindented_paragraph_ends_the_field(self):
        e = decisions.parse(DATA.replace("- **Record:** reports/logs/x/decision.md\n",
                                         "- **Record:** reports/logs/x/decision.md\nFree text.\n"))[0]
        self.assertEqual(e.get("Record"), "reports/logs/x/decision.md")


class DueTests(unittest.TestCase):
    def test_due_lists_only_open_decisions_checked_by_that_event(self):
        other = DATA.replace("D-1", "D-4").replace("`H1`, `H2`", "`Ride B`")
        done = DATA.replace("D-1", "D-5").replace("awaiting check", "held").replace(
            "- **Record:**", "- **Check:** 2026-12-01, held.\n- **Record:**")
        entries = decisions.parse(register(DATA, other, done))
        self.assertEqual([e.id for e in decisions.due(entries, "H1")], ["D-1"])
        self.assertEqual([e.id for e in decisions.due(entries, "Ride B")], ["D-4"])
        self.assertEqual(decisions.due(entries, "H"), [])  # whole event names only

    def test_due_also_lists_a_values_call_whose_data_question_the_event_answers(self):
        waiting = VALUES.replace("- **Status:** awaiting operator", "- **Checked by:** `H1`\n- **Status:** awaiting operator")
        entries = decisions.parse(register(DATA, waiting))
        self.assertEqual([e.id for e in decisions.due(entries, "H1")], ["D-1", "D-2"])


class ScoreTests(unittest.TestCase):
    def test_counts_and_brier_over_resolved_decisions_with_a_confidence(self):
        held = DATA.replace("D-1", "D-6").replace("60 %", "80 %").replace(
            "awaiting check", "held").replace("- **Record:**", "- **Check:** ok.\n- **Record:**")
        lost = DATA.replace("D-1", "D-7").replace("60 %", "70 %").replace(
            "awaiting check", "overturned").replace("- **Record:**", "- **Check:** no.\n- **Record:**")
        s = decisions.score(decisions.parse(register(DATA, held, lost, CHEAP)))
        self.assertEqual(s["counts"]["held"], 2)
        self.assertEqual(s["counts"]["overturned"], 1)
        self.assertEqual(s["counts"]["awaiting check"], 1)
        # (0.8 - 1)^2 = 0.04 and (0.7 - 0)^2 = 0.49; CHEAP has no confidence, so it is left out.
        self.assertAlmostEqual(s["brier"], (0.04 + 0.49) / 2)
        self.assertEqual(s["scored"], 2)

    def test_no_resolved_decision_gives_no_brier(self):
        self.assertIsNone(decisions.score(decisions.parse(register(DATA)))["brier"])


class CliTests(unittest.TestCase):
    def run_cli(self, text, *args):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write(text)
        try:
            return subprocess.run([sys.executable, os.path.join(HERE, "decisions.py"), *args,
                                   "--register", f.name], capture_output=True, text=True)
        finally:
            os.unlink(f.name)

    def test_lint_exit_codes(self):
        self.assertEqual(self.run_cli(register(DATA, VALUES, CHEAP), "lint").returncode, 0)
        bad = self.run_cli(register(DATA.replace("60 %", "")), "lint")
        self.assertEqual(bad.returncode, 1)
        self.assertIn("D-1", bad.stdout)

    def test_due_prints_the_ids(self):
        out = self.run_cli(register(DATA, VALUES), "due", "H2")
        self.assertEqual(out.returncode, 0)
        self.assertIn("D-1", out.stdout)
        self.assertNotIn("D-2", out.stdout)

    def test_a_missing_register_is_a_usage_error(self):
        out = subprocess.run([sys.executable, os.path.join(HERE, "decisions.py"), "lint",
                              "--register", "/nonexistent/REGISTER.md"], capture_output=True, text=True)
        self.assertEqual(out.returncode, 2)


if __name__ == "__main__":
    unittest.main()
