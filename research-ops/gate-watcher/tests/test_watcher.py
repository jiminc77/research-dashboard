import json, os, sys, tempfile, unittest
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import watcher
CFG = {"human_login": "jiminc77", "verdict_marker": "### GATE VERDICT", "verdict_field": "choice:",
       "request_marker": "### GATE REQUEST", "repo": "jiminc77/DGCC",
       "armed_substrings": ["human_blocked", "blocker_classified"]}
def comment(cid, login, body): return {"id": cid, "user": {"login": login}, "body": body}
VALID_BODY = "### GATE VERDICT\nid: P1-M3R-G1\nchoice: B\nrationale: ...\n"
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
        body = "M3R 결과 보고\n\n### GATE VERDICT 스타일 인용\nchoice: B"
        ok, reason = watcher.evaluate_comment(comment(103, "jiminc77", body), CFG, 50)
        self.assertFalse(ok); self.assertIn("C2", reason)
    def test_c2_blockquoted_marker_rejected(self):
        body = "> ### GATE VERDICT — 인용\n\n보고 본문 choice: B"
        ok, reason = watcher.evaluate_comment(comment(104, "jiminc77", body), CFG, 50)
        self.assertFalse(ok); self.assertIn("C2", reason)
    def test_c3_no_resume_token_rejected(self):
        body = "### GATE VERDICT\nid: x\nrationale: choice 필드 없음"
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



class TestLedgerDiscovery(unittest.TestCase):
    def test_choose_newest_mtime(self):
        paths = [("/a/ledger.jsonl", 100.0), ("/b/ledger.jsonl", 200.0), ("/c/ledger.jsonl", 150.0)]
        self.assertEqual(watcher.choose_ledger(paths), "/b/ledger.jsonl")

    def test_none_on_empty(self):
        self.assertIsNone(watcher.choose_ledger([]))

    def test_resolve_glob_prefers_newest(self):
        import time as _t
        d = tempfile.mkdtemp()
        old_dir = os.path.join(d, "_session-old", "ultragoal"); os.makedirs(old_dir)
        new_dir = os.path.join(d, "_session-new", "ultragoal"); os.makedirs(new_dir)
        p_old = os.path.join(old_dir, "ledger.jsonl"); open(p_old, "w").write("{}")
        p_new = os.path.join(new_dir, "ledger.jsonl"); open(p_new, "w").write("{}")
        os.utime(p_old, (1000, 1000)); os.utime(p_new, (2000, 2000))
        cfg = {"ledger_glob": os.path.join(d, "_session-*", "ultragoal", "ledger.jsonl"), "ledger_path": ""}
        path, src = watcher.resolve_ledger(cfg)
        self.assertEqual(path, p_new); self.assertEqual(src, "glob")

    def test_resolve_fallback(self):
        path, src = watcher.resolve_ledger({"ledger_glob": "/nonexistent/_s-*/l.jsonl", "ledger_path": "/x/l.jsonl"})
        self.assertEqual((path, src), ("/x/l.jsonl", "fallback"))



class TestHermeticOverrides(unittest.TestCase):
    """리허설/목업 계약: 자동 발견을 비우면 fallback만 쓴다 (v2.3 회귀 방지)."""

    def test_empty_glob_uses_ledger_path(self):
        path, src = watcher.resolve_ledger({"ledger_glob": "", "ledger_path": "/mock/ledger.jsonl"})
        self.assertEqual((path, src), ("/mock/ledger.jsonl", "fallback"))

    def test_empty_labels_uses_issue_number(self):
        class _NoNetLog:
            def write(self, msg): pass
        n, src = watcher.resolve_issue({"issue_labels": [], "issue_number": 99, "repo": "x/y"}, "tok", _NoNetLog())
        self.assertEqual((n, src), (99, "fallback"))


# ---------------------------------------------------------------------------
# v3.1 harness: gate binding (C5/C6), legacy mode, pagination, id parser.
# ---------------------------------------------------------------------------
class _NoNetLog:
    """Log 대체 — write 캡처만 (네트워크/파일 없음)."""
    def __init__(self): self.lines = []
    def write(self, msg): self.lines.append(msg)


def rq(cid, ident, created, login="gjc-bot"):
    """GATE REQUEST 코멘트 팩토리."""
    body = f"### GATE REQUEST\nid: {ident}\nclass: hard\nquestion: pick one\n"
    return {"id": cid, "user": {"login": login}, "body": body, "created_at": created}


def vd(cid, ident, created, login="jiminc77", choice="B"):
    """GATE VERDICT 코멘트 팩토리."""
    body = f"### GATE VERDICT\nid: {ident}\nchoice: {choice}\nrationale: ok\n"
    return {"id": cid, "user": {"login": login}, "body": body, "created_at": created}


class TestGateIdParser(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(watcher.parse_gate_id("### GATE VERDICT\nid: P1-M3-G1\nchoice: B"), "P1-M3-G1")
    def test_extra_spaces(self):
        self.assertEqual(watcher.parse_gate_id("id  :   P2-M1-G7   \n"), "P2-M1-G7")
    def test_crlf_and_leading_ws(self):
        self.assertEqual(watcher.parse_gate_id("### GATE REQUEST\r\n   id:\tP4-G2\r\nclass: soft\r\n"), "P4-G2")
    def test_case_insensitive_key(self):
        self.assertEqual(watcher.parse_gate_id("ID: P9-G9"), "P9-G9")
    def test_first_match_wins(self):
        self.assertEqual(watcher.parse_gate_id("id: FIRST\nid: SECOND"), "FIRST")
    def test_none_when_absent(self):
        self.assertIsNone(watcher.parse_gate_id("### GATE VERDICT\nchoice: B\nno identifier here"))


class TestFindPendingRequest(unittest.TestCase):
    def test_newest_request_wins(self):
        # newest-first 목록: 최신 요청(다른 id)이 먼저 → 그것이 채택돼야.
        comments = [rq(300, "P1-G2", "2026-07-07T03:00:00Z"),
                    vd(250, "P1-G1", "2026-07-07T02:30:00Z"),
                    rq(200, "P1-G1", "2026-07-07T02:00:00Z")]
        p = watcher.find_pending_request(comments, CFG)
        self.assertEqual(p["id"], "P1-G2"); self.assertEqual(p["comment_id"], 300)
    def test_none_when_no_request(self):
        comments = [vd(250, "P1-G1", "2026-07-07T02:30:00Z")]
        self.assertIsNone(watcher.find_pending_request(comments, CFG))
    def test_blockquoted_request_ignored(self):
        # 첫 줄이 인용(> )이면 GATE REQUEST로 인정 안 함.
        c = {"id": 9, "user": {"login": "x"}, "body": "> ### GATE REQUEST\nid: Q", "created_at": "z"}
        self.assertIsNone(watcher.find_pending_request([c], CFG))


class TestParseLinkLast(unittest.TestCase):
    def test_extracts_last_page(self):
        h = ('<https://api.github.com/repositories/1/issues/20/comments?per_page=100&page=2>; rel="next", '
             '<https://api.github.com/repositories/1/issues/20/comments?per_page=100&page=4>; rel="last"')
        self.assertEqual(watcher.parse_link_last_page(h), 4)
    def test_none_when_no_last(self):
        self.assertIsNone(watcher.parse_link_last_page(''))
        self.assertIsNone(watcher.parse_link_last_page('<...>; rel="next"'))


class _FakeResp:
    """urlopen 컨텍스트매니저 목업 — .read()/.headers 제공."""
    def __init__(self, payload, link=""):
        self._raw = json.dumps(payload).encode("utf-8")
        self.headers = {"Link": link} if link else {}
    def read(self): return self._raw
    def __enter__(self): return self
    def __exit__(self, *a): return False


class TestPagination(unittest.TestCase):
    def _install(self, pages_by_page, link_first):
        """urllib.request.urlopen을 page= 쿼리별 응답으로 목업. pages_by_page: {page_int: [comments]}"""
        import urllib.request as _u
        calls = []
        def fake(req, timeout=30):
            url = req.full_url if hasattr(req, "full_url") else req.get_full_url()
            calls.append(url)
            import re as _re
            m = _re.search(r'[?&]page=(\d+)', url)
            page = int(m.group(1)) if m else 1
            link = link_first if page == 1 else ""
            return _FakeResp(pages_by_page[page], link)
        self._orig = _u.urlopen; _u.urlopen = fake
        self.addCleanup(lambda: setattr(_u, "urlopen", self._orig))
        return calls

    def test_multi_page_newest_first_and_verdict_on_last_page(self):
        # page1 = 가장 오래된, page2 = 최신. request는 page1, verdict는 page2(최신 쪽).
        link = ('<https://api.github.com/x?per_page=100&page=2>; rel="next", '
                '<https://api.github.com/x?per_page=100&page=2>; rel="last"')
        req_c = rq(100, "P1-G1", "2026-07-07T01:00:00Z")
        verdict_c = vd(400, "P1-G1", "2026-07-07T05:00:00Z")
        pages = {1: [req_c, {"id": 101, "user": {"login": "gjc-bot"}, "body": "chatter", "created_at": "2026-07-07T01:05:00Z"}],
                 2: [{"id": 399, "user": {"login": "x"}, "body": "more", "created_at": "2026-07-07T04:00:00Z"}, verdict_c]}
        self._install(pages, link)
        got = watcher.fetch_comments_newest_first(CFG, "tok", 20)
        # newest-first: page2 뒤집힘(verdict먼저) → page1 뒤집힘. 첫 원소가 최신 verdict.
        self.assertEqual(got[0]["id"], 400)
        self.assertEqual([c["id"] for c in got], [400, 399, 101, 100])
        # find_verdict가 마지막 페이지의 verdict를 찾아야.
        log = _NoNetLog()
        cand = watcher.find_verdict(CFG, "tok", 20, 50, log)
        self.assertIsNotNone(cand); self.assertEqual(cand["id"], 400)

    def test_single_page_reversed(self):
        pages = {1: [rq(10, "G", "2026-07-07T01:00:00Z"), vd(20, "G", "2026-07-07T02:00:00Z")]}
        self._install(pages, "")  # Link 없음 → 단일 페이지
        got = watcher.fetch_comments_newest_first(CFG, "tok", 20)
        self.assertEqual([c["id"] for c in got], [20, 10])

    def test_page_cap_5(self):
        # last_page=8 이면 8..4 (5쪽)만 fetch, page1은 재요청 안 함(1쪽 밖).
        link = ('<https://api.github.com/x?per_page=100&page=8>; rel="last"')
        pages = {p: [{"id": p * 10, "user": {"login": "x"}, "body": "b", "created_at": f"t{p}"}] for p in range(1, 9)}
        calls = self._install(pages, link)
        got = watcher.fetch_comments_newest_first(CFG, "tok", 20)
        fetched_pages = sorted(int(__import__("re").search(r'[?&]page=(\d+)', u).group(1)) if __import__("re").search(r'[?&]page=\d+', u) else 1 for u in calls)
        # page1(초기) + page8,7,6,5,4 == {1,4,5,6,7,8}
        self.assertEqual(set(fetched_pages), {1, 4, 5, 6, 7, 8})
        self.assertEqual([c["id"] for c in got][0], 80)  # 최신(page8) 먼저


class TestVerdictBinding(unittest.TestCase):
    """find_verdict을 목업 코멘트 목록으로 직접 구동 (fetch_comments_newest_first 몽키패치)."""
    def _run(self, comments_newest_first, last_processed=50):
        orig = watcher.fetch_comments_newest_first
        watcher.fetch_comments_newest_first = lambda cfg, token, issue: list(comments_newest_first)
        self.addCleanup(lambda: setattr(watcher, "fetch_comments_newest_first", orig))
        log = _NoNetLog()
        return watcher.find_verdict(CFG, "tok", 20, last_processed, log), log

    def test_id_match_passes(self):
        comments = [vd(300, "P1-G1", "2026-07-07T05:00:00Z"),
                    rq(100, "P1-G1", "2026-07-07T01:00:00Z")]
        cand, _ = self._run(comments)
        self.assertIsNotNone(cand); self.assertEqual(cand["id"], 300)

    def test_id_mismatch_skipped(self):
        comments = [vd(300, "WRONG-ID", "2026-07-07T05:00:00Z"),
                    rq(100, "P1-G1", "2026-07-07T01:00:00Z")]
        cand, log = self._run(comments)
        self.assertIsNone(cand)
        self.assertTrue(any("C5 reject" in l for l in log.lines), log.lines)

    def test_created_at_before_request_skipped(self):
        # verdict가 request보다 먼저 생성 → C6 reject (재생/사전작성 방지).
        comments = [rq(300, "P1-G1", "2026-07-07T05:00:00Z"),
                    vd(200, "P1-G1", "2026-07-07T01:00:00Z")]
        cand, log = self._run(comments)
        self.assertIsNone(cand)
        self.assertTrue(any("C6 reject" in l for l in log.lines), log.lines)

    def test_created_at_after_request_passes(self):
        comments = [vd(300, "P1-G1", "2026-07-07T05:00:00Z"),
                    rq(100, "P1-G1", "2026-07-07T01:00:00Z")]
        cand, _ = self._run(comments)
        self.assertEqual(cand["id"], 300)

    def test_legacy_mode_no_request_c1_c4_only(self):
        # GATE REQUEST 없음 → C5/C6 미적용, C1–C4만. 유효 verdict 통과 + 경고 로그.
        comments = [vd(300, "ANY-ID", "2026-07-07T05:00:00Z")]
        cand, log = self._run(comments)
        self.assertIsNotNone(cand); self.assertEqual(cand["id"], 300)
        self.assertTrue(any("LEGACY GATE" in l for l in log.lines), log.lines)

    def test_legacy_mode_still_enforces_c1(self):
        # legacy여도 impostor(C1)는 거부.
        comments = [vd(300, "ANY", "2026-07-07T05:00:00Z", login="attacker")]
        cand, log = self._run(comments)
        self.assertIsNone(cand)
        self.assertTrue(any("C1 reject" in l for l in log.lines), log.lines)

    def test_multiple_requests_newest_binds(self):
        # 두 요청: 최신 요청(P1-G2)에 맞는 verdict만 통과, 구 요청(P1-G1) verdict는 C5 reject.
        comments = [vd(500, "P1-G2", "2026-07-07T09:00:00Z"),
                    rq(400, "P1-G2", "2026-07-07T08:00:00Z"),
                    vd(300, "P1-G1", "2026-07-07T05:00:00Z"),
                    rq(100, "P1-G1", "2026-07-07T01:00:00Z")]
        cand, log = self._run(comments)
        self.assertIsNotNone(cand); self.assertEqual(cand["id"], 500)

    def test_multiple_requests_stale_verdict_rejected(self):
        # 최신 요청은 P1-G2인데 사람이 아직 P1-G1 답만 올린 상태 → 통과 없음(C5 reject).
        comments = [rq(400, "P1-G2", "2026-07-07T08:00:00Z"),
                    vd(300, "P1-G1", "2026-07-07T05:00:00Z"),
                    rq(100, "P1-G1", "2026-07-07T01:00:00Z")]
        cand, log = self._run(comments)
        self.assertIsNone(cand)
        self.assertTrue(any("C5 reject" in l for l in log.lines), log.lines)


if __name__ == "__main__":
    unittest.main(verbosity=2)
