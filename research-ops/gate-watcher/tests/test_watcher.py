import json, os, sys, tempfile, unittest
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import watcher
CFG = {"human_login": "jiminc77", "verdict_marker": "## HUMAN 판정", "resume_token": "[RESUME]",
       "armed_substrings": ["human_blocked", "blocker_classified"]}
def comment(cid, login, body): return {"id": cid, "user": {"login": login}, "body": body}
VALID_BODY = "## HUMAN 판정 — M3R 게이트 (2026-07-09)\n\n판정: ...\n\n[RESUME]\n"
class TestContract(unittest.TestCase):
    def test_valid_verdict_passes(self):
        ok, reason = watcher.evaluate_comment(comment(100, "jiminc77", VALID_BODY), CFG, 50)
        self.assertTrue(ok, reason)
    def test_c1_impostor_with_marker_and_resume_rejected(self):
        ok, reason = watcher.evaluate_comment(comment(101, "attacker", VALID_BODY), CFG, 50)
        self.assertFalse(ok); self.assertIn("C1", reason)
    def test_c1_agent_account_rejected(self):
        ok, reason = watcher.evaluate_comment(comment(102, "jiminc77-agent", VALID_BODY), CFG, 50)
        self.assertFalse(ok); self.assertIn("C1", reason)
    def test_c2_wrong_first_line_rejected(self):
        body = "M3R 결과 보고\n\n## HUMAN 판정 스타일 인용\n[RESUME]"
        ok, reason = watcher.evaluate_comment(comment(103, "jiminc77", body), CFG, 50)
        self.assertFalse(ok); self.assertIn("C2", reason)
    def test_c2_blockquoted_marker_rejected(self):
        body = "> ## HUMAN 판정 — 인용\n\n보고 본문 [RESUME]"
        ok, reason = watcher.evaluate_comment(comment(104, "jiminc77", body), CFG, 50)
        self.assertFalse(ok); self.assertIn("C2", reason)
    def test_c3_no_resume_token_rejected(self):
        body = "## HUMAN 판정 — 중간 질문\n\n이건 논의용 코멘트."
        ok, reason = watcher.evaluate_comment(comment(105, "jiminc77", body), CFG, 50)
        self.assertFalse(ok); self.assertIn("C3", reason)
    def test_c4_old_comment_rejected(self):
        ok, reason = watcher.evaluate_comment(comment(40, "jiminc77", VALID_BODY), CFG, 50)
        self.assertFalse(ok); self.assertIn("C4", reason)
    def test_c4_equal_id_rejected(self):
        ok, reason = watcher.evaluate_comment(comment(50, "jiminc77", VALID_BODY), CFG, 50)
        self.assertFalse(ok); self.assertIn("C4", reason)
    def test_empty_body_rejected(self):
        ok, reason = watcher.evaluate_comment(comment(106, "jiminc77", ""), CFG, 50)
        self.assertFalse(ok)
    def test_leading_whitespace_tolerated(self):
        ok, _ = watcher.evaluate_comment(comment(107, "jiminc77", "\n  " + VALID_BODY), CFG, 50)
        self.assertTrue(ok)
class TestLedger(unittest.TestCase):
    def _write(self, lines):
        f = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
        f.write("\n".join(lines)); f.close(); return f.name
    def test_tail_last_nonempty(self):
        p = self._write([json.dumps({"event": "checkpoint"}), "", json.dumps({"event": "human_blocked", "note": "gate"}), ""])
        tail = watcher.ledger_tail(p)
        self.assertIn("human_blocked", tail); self.assertTrue(watcher.is_blocked(tail, CFG)); os.unlink(p)
    def test_not_blocked_on_normal_tail(self):
        p = self._write([json.dumps({"event": "human_blocked"}), json.dumps({"event": "goal_resumed"})])
        self.assertFalse(watcher.is_blocked(watcher.ledger_tail(p), CFG)); os.unlink(p)
    def test_missing_file_safe(self):
        self.assertEqual(watcher.ledger_tail("/nonexistent/ledger.jsonl"), "")

class TestIssueDiscovery(unittest.TestCase):
    def test_choose_first_open_issue(self):
        items = [{"number": 31, "title": "gate"}, {"number": 12, "title": "old"}]
        self.assertEqual(watcher.choose_issue(items, CFG), 31)

    def test_skip_pull_requests(self):
        items = [{"number": 33, "pull_request": {"url": "x"}}, {"number": 31}]
        self.assertEqual(watcher.choose_issue(items, CFG), 31)

    def test_none_on_empty(self):
        self.assertIsNone(watcher.choose_issue([], CFG))
        self.assertIsNone(watcher.choose_issue(None, CFG))


if __name__ == "__main__":
    unittest.main(verbosity=2)
