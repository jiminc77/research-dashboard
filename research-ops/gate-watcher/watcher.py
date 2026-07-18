#!/usr/bin/env python3
"""research-ops gate-watcher (v3.2, 2026-07-15).

v3.2: resolve_issue 가 진행 중 사이클의 active_issue 를 최우선 조회 — 사람이 판정을
      게시하면 gate-notify 가 라벨을 blocked-human→ready 로 즉시 전환해 라벨 검색이
      빈손이 되고 nudge 가 영영 막히던 경합 제거 (2026-07-15 실사고; issue_number
      하드코딩 임시방편 불필요). WAIT_ACK 의 최종 escalation(2×ack_timeout)을 재전달
      분기보다 먼저 검사해 도달 불가 버그 수정, 재전달은 성공/실패 무관 1회 제한.
v2.1: 게이트 issue 자동 발견 — issue_labels(우선) → issue_number(fallback).
v3.0: 판정 계약을 PROTOCOL.md §2 GATE VERDICT 스키마로 통합 (구 "## HUMAN 판정
      + [RESUME]" 계약 폐지). C2=첫 줄 "### GATE VERDICT", C3=choice: 필드 존재.
v3.1: 판정을 PENDING ### GATE REQUEST에 바인딩 — C5=id 일치, C6=verdict.created_at
      > request.created_at (재생/스푸핑 방지). REQUEST 없으면 LEGACY MODE(C1–C4만
      + 경고). 코멘트 스캔을 newest-first로 페이지네이션(Link rel=last, 최대 5쪽).
v2.2: ledger 자동 발견 — ledger_glob에서 최신 mtime 선택 (gjc는 세션별
      _session-<id>/ 디렉토리에 ledger를 두므로 phase/세션이 바뀌어도 추적).

HUMAN GATE에서 사람 판정 코멘트를 감지해 라이브 gjc tmux 세션에
"가서 읽어라" nudge만 전달한다. 판정 본문은 절대 주입하지 않는다.

- stdlib 전용 (원격 머신에서 venv 불필요)
- 상태 기계: DISARMED → ARMED → WAIT_ACK → DISARMED (spec §3)
- 판정 계약 C1–C4: evaluate_comment(); C5/C6(gate 바인딩)은 find_verdict()가 강제
  (spec §2) — tests/test_watcher.py가 잠금
"""
import glob
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

DEFAULT_CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")


def utcnow() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class Log:
    def __init__(self, path: str):
        self.path = path
        os.makedirs(os.path.dirname(path), exist_ok=True)

    def write(self, msg: str) -> None:
        line = f"[{utcnow()}] {msg}"
        print(line, flush=True)
        with open(self.path, "a", encoding="utf-8") as f:
            f.write(line + "\n")


def load_json(path: str, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return default


def save_json(path: str, obj) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def gh_api(url: str, token: str, method: str = "GET", body=None, timeout: int = 30):
    req = urllib.request.Request(url, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, data=data, timeout=timeout) as r:
        raw = r.read().decode("utf-8")
        return json.loads(raw) if raw else None


def gh_api_paged(url: str, token: str, timeout: int = 30):
    """gh_api와 동일하나 (payload, Link 헤더 문자열) 튜플을 반환 (페이지네이션용)."""
    req = urllib.request.Request(url, method="GET")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read().decode("utf-8")
        link = r.headers.get("Link", "") or ""
        return (json.loads(raw) if raw else None), link


def parse_link_last_page(link_header: str):
    """GitHub Link 헤더에서 rel="last"의 페이지 번호를 뽑는다 (없으면 None). 순수 함수 — 테스트 잠금."""
    if not link_header:
        return None
    for part in link_header.split(","):
        seg = part.strip()
        if 'rel="last"' not in seg:
            continue
        m = re.search(r'[?&]page=(\d+)', seg)
        if m:
            return int(m.group(1))
    return None


def fetch_comments_newest_first(cfg: dict, token: str, issue_number: int, max_pages: int = 5):
    """이슈 코멘트를 newest-first로 반환. per_page=100로 1쪽을 받고 Link rel=last를
    읽어 여러 쪽이면 마지막 쪽부터 뒤로(last, last-1, ...) 최대 max_pages쪽(=500개 최신)
    까지 모아 각 쪽 내부를 뒤집어 이어붙인다. GitHub은 코멘트를 오래된→최신 순으로 주므로
    마지막 쪽이 가장 최신이다. 에러 처리는 호출 측 백오프에 위임(gh_api_paged 예외 전파).
    """
    base = (
        f"https://api.github.com/repos/{cfg['repo']}/issues/"
        f"{issue_number}/comments?per_page=100"
    )
    first, link = gh_api_paged(base, token)
    first = first or []
    last_page = parse_link_last_page(link)
    if not last_page or last_page <= 1:
        # 단일 페이지: 그 안에서 최신이 뒤에 있으므로 뒤집어 반환.
        return list(reversed(first))
    result = []
    lowest = max(1, last_page - max_pages + 1)  # 최대 max_pages쪽만 (500개 최신 상한)
    for page in range(last_page, lowest - 1, -1):
        if page == 1:
            chunk = first  # 1쪽은 이미 받아둠 (재요청 회피)
        else:
            chunk, _ = gh_api_paged(base + f"&page={page}", token)
            chunk = chunk or []
        result.extend(reversed(chunk))  # 쪽 내부도 newest-first로
    return result


def parse_gate_id(body: str):
    r"""코멘트 본문에서 `id:` 값을 관대하게 추출. 첫 매치의 값(공백 strip)을 반환, 없으면 None.
    키는 대소문자 무관, 앞 공백 허용: `^\s*id\s*:\s*(\S+)`. 순수 함수 — 테스트 잠금.
    """
    for line in (body or "").splitlines():
        m = re.match(r'^\s*id\s*:\s*(\S+)', line, re.IGNORECASE)
        if m:
            return m.group(1).strip()
    return None


def choose_ledger(paths):
    """mtime 최신 경로 선택 (순수 로직 — 테스트 잠금). paths: [(path, mtime)]"""
    if not paths:
        return None
    return max(paths, key=lambda pm: pm[1])[0]


def resolve_ledger(cfg: dict):
    """감시 대상 ledger 결정: (1) ledger_glob 매치 중 최신 mtime → (2) ledger_path fallback.

    Returns (path | None, source_str)
    """
    pattern = cfg.get("ledger_glob") or ""
    if pattern:
        cands = []
        for p in glob.glob(pattern):
            try:
                cands.append((p, os.path.getmtime(p)))
            except OSError:
                continue
        chosen = choose_ledger(cands)
        if chosen:
            return chosen, "glob"
    p = cfg.get("ledger_path")
    if p:
        return p, "fallback"
    return None, "none"


def ledger_tail(path: str) -> str:
    """ledger.jsonl의 마지막 비어있지 않은 줄 (읽기 전용, 스키마 무관 문자열 매칭용)."""
    try:
        with open(path, "rb") as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            f.seek(max(0, size - 65536))
            chunk = f.read().decode("utf-8", errors="replace")
        lines = [ln for ln in chunk.splitlines() if ln.strip()]
        return lines[-1] if lines else ""
    except (FileNotFoundError, PermissionError):
        return ""


def is_blocked(tail: str, cfg: dict) -> bool:
    return any(s in tail for s in cfg["armed_substrings"])


def has_blocked_issue(cfg: dict, token: str, log: Log) -> bool:
    """gjc가 게이트를 ledger 핸드오프 없이 인라인 처리하면 ledger tail에 blocked 마커가
    남지 않아 무장되지 않던 버그(2026-07-16 진단) 보완: issue_labels(=state:blocked-human)가
    달린 open 이슈가 하나라도 있으면 무장 트리거로 본다. resolve_issue와 동일한 인증/요청
    기계(gh_api)를 재사용하며, 어떤 예외에서도 fail-safe(False 반환 + 로그) — 라벨 조회
    실패가 감시 루프를 죽이지 않도록 한다."""
    labels = cfg.get("issue_labels") or ["state:blocked-human"]
    q = urllib.parse.quote(",".join(labels))
    url = (
        f"https://api.github.com/repos/{cfg['repo']}/issues"
        f"?state=open&labels={q}&per_page=1"
    )
    try:
        for it in gh_api(url, token) or []:
            if "pull_request" in it:
                continue
            return True
        return False
    except Exception as e:  # noqa: BLE001
        log.write(f"has_blocked_issue API error (fail-safe False): {e}")
        return False


def evaluate_comment(comment: dict, cfg: dict, last_processed_id: int):
    """판정 계약 C1–C4 (author / 첫 줄 마커 / choice: 필드 / id > last_processed).
    C5(gate id 일치)·C6(created_at 순서)는 find_verdict()가 pending REQUEST 대비 강제.

    Returns (ok: bool, reason: str)
    """
    author = (comment.get("user") or {}).get("login", "")
    if author != cfg["human_login"]:
        return False, f"C1 reject: author={author!r}"
    body = comment.get("body") or ""
    stripped = body.lstrip()
    first_line = stripped.splitlines()[0] if stripped else ""
    if not first_line.startswith(cfg["verdict_marker"]):
        return False, f"C2 reject: first_line={first_line[:40]!r}"
    if cfg["verdict_field"] not in body:
        return False, f"C3 reject: no {cfg['verdict_field']!r} field"
    if int(comment["id"]) <= int(last_processed_id):
        return False, f"C4 reject: id {comment['id']} <= last_processed {last_processed_id}"
    return True, "ok"



def choose_issue(items, cfg):
    """라벨 질의 결과에서 게이트 issue 선택 (PR 제외, updated desc 첫 항목). 순수 함수 — 테스트 잠금."""
    for it in items or []:
        if "pull_request" in it:
            continue
        return int(it["number"])
    return None


def resolve_issue(cfg: dict, token: str, log: Log, active=None):
    """게이트 issue 결정: (0) 진행 중 사이클의 active issue → (1) issue_labels 매치
    (open, 최근 갱신순) → (2) issue_number fallback.

    (0)이 최우선인 이유: 사람이 GATE VERDICT 를 게시하면 gate-notify 의 verdict-label
    job 이 라벨을 blocked-human→ready 로 즉시 전환하므로, 라벨 검색만으로는 판정
    직후의 게이트 이슈를 다시 찾지 못한다. 사이클 동안 이슈를 고정하고, 고정이 다음
    게이트로 이월되지 않도록 새 사이클 진입(DISARMED→ARMED)에서 active 를 리셋한다.

    Returns (issue_number | None, source_str)
    """
    if active:
        return int(active), "active"
    labels = cfg.get("issue_labels") or []
    if labels:
        q = urllib.parse.quote(",".join(labels))
        url = (
            f"https://api.github.com/repos/{cfg['repo']}/issues"
            f"?state=open&labels={q}&sort=updated&direction=desc&per_page=10"
        )
        try:
            n = choose_issue(gh_api(url, token), cfg)
            if n is not None:
                return n, "label"
        except Exception as e:  # noqa: BLE001
            log.write(f"issue discovery API error (label path): {e}")
    n = cfg.get("issue_number")
    if n:
        return int(n), "fallback"
    return None, "none"


def find_pending_request(comments_newest_first, cfg: dict):
    """newest-first 코멘트 목록에서 PENDING GATE REQUEST = 첫 줄이 "### GATE REQUEST"인
    가장 최신 코멘트를 찾아 (id, created_at, comment_id) 튜플을 반환. 없으면 None.
    여러 요청이면 newest-first 특성상 첫 매치(=최신)가 채택된다. 순수 함수 — 테스트 잠금.
    """
    marker = cfg.get("request_marker", "### GATE REQUEST")
    for c in comments_newest_first or []:
        body = c.get("body") or ""
        stripped = body.lstrip()
        first_line = stripped.splitlines()[0] if stripped else ""
        if first_line.startswith(marker):
            return {
                "id": parse_gate_id(body),
                "created_at": c.get("created_at") or "",
                "comment_id": int(c.get("id", 0)),
            }
    return None


def find_verdict(cfg: dict, token: str, issue_number: int, last_processed_id: int, log: Log):
    """이슈에서 유효한 GATE VERDICT 코멘트를 찾는다 (newest-first 페이지네이션).

    바인딩(v3.1): PENDING ### GATE REQUEST를 먼저 찾고, 판정 후보는 C1–C4에 더해
      C5(id == request.id) · C6(verdict.created_at > request.created_at)을 만족해야 한다.
    LEGACY MODE: GATE REQUEST 코멘트가 없으면 C1–C4만 적용(경고 로그).
    """
    comments = fetch_comments_newest_first(cfg, token, issue_number)  # 최신 → 오래된 순
    pending = find_pending_request(comments, cfg)
    if pending is None:
        log.write(
            "WARNING: LEGACY GATE (no ### GATE REQUEST found) — "
            "id/created_at binding skipped (C5/C6 미적용, C1–C4만 강제)"
        )
    else:
        log.write(
            f"pending gate request: id={pending['id']!r} "
            f"created_at={pending['created_at']!r} comment={pending['comment_id']}"
        )
    # comments가 newest-first이므로 첫 통과분이 곧 최신 판정.
    for c in comments or []:
        ok, reason = evaluate_comment(c, cfg, last_processed_id)
        if ok and pending is not None:
            vid = parse_gate_id(c.get("body") or "")
            if vid != pending["id"]:
                ok, reason = False, (
                    f"C5 reject: verdict id={vid!r} != request id={pending['id']!r}"
                )
            elif (c.get("created_at") or "") <= pending["created_at"]:
                ok, reason = False, (
                    f"C6 reject: verdict created_at={c.get('created_at')!r} "
                    f"<= request created_at={pending['created_at']!r}"
                )
        if ok:
            return c  # newest-first → 첫 통과분이 최신
        if int(c.get("id", 0)) > int(last_processed_id):
            log.write(f"skip comment {c.get('id')}: {reason}")
    return None


def deliver_nudge(cfg: dict, issue_number: int, comment_id: int) -> None:
    msg = cfg["nudge_template"].format(issue=issue_number, cid=comment_id)
    subprocess.run(
        ["tmux", "send-keys", "-t", cfg["tmux_session"], msg, "Enter"],
        check=True,
        timeout=15,
    )


def react_eyes(cfg: dict, token: str, comment_id: int) -> None:
    url = (
        f"https://api.github.com/repos/{cfg['repo']}/issues/"
        f"comments/{comment_id}/reactions"
    )
    gh_api(url, token, method="POST", body={"content": "eyes"})


def notify_human(cfg: dict, log: Log, message: str) -> None:
    cmd = cfg.get("notify_cmd") or ""
    if not cmd:
        log.write(f"NOTIFY (no notify_cmd configured): {message}")
        return
    try:
        subprocess.run(
            ["bash", "-c", cmd],
            env={**os.environ, "GW_MESSAGE": message},
            timeout=60,
            check=False,
        )
        log.write(f"NOTIFY sent: {message}")
    except Exception as e:  # noqa: BLE001
        log.write(f"NOTIFY failed ({e}): {message}")


def default_state(cfg: dict) -> dict:
    return {
        "mode": "DISARMED",
        "last_processed_id": int(cfg.get("baseline_comment_id", 0)),
        "blocked_line": None,
        "delivered_id": None,
        "delivered_at": None,
        "redelivered": False,
        "active_issue": None,
        "active_ledger": None,
    }


def run(cfg_path: str) -> None:
    cfg = load_json(cfg_path, None)
    if cfg is None:
        sys.exit(f"config not found: {cfg_path} (config.example.json 참조)")
    token = os.environ.get(cfg.get("token_env", "GITHUB_TOKEN"), "")
    if not token:
        sys.exit(f"missing token env: {cfg.get('token_env', 'GITHUB_TOKEN')}")
    log = Log(cfg["log_path"])
    state = load_json(cfg["state_path"], default_state(cfg))
    log.write(
        f"start mode={state['mode']} last_processed_id={state['last_processed_id']} "
        f"labels={cfg.get('issue_labels')} fallback_issue={cfg.get('issue_number')} "
        f"session={cfg['tmux_session']!r}"
    )

    while True:
        ledger_path, ledger_src = resolve_ledger(cfg)
        if ledger_path is None:
            log.write("no ledger resolvable (ledger_glob/ledger_path both empty) — idle")
            time.sleep(cfg["disarmed_poll_s"])
            continue
        if state.get("active_ledger") != ledger_path:
            state.update(active_ledger=ledger_path)
            save_json(cfg["state_path"], state)
            log.write(f"ledger resolved: {ledger_path} (source={ledger_src})")
        tail = ledger_tail(ledger_path)
        blocked = is_blocked(tail, cfg)
        mode = state["mode"]

        if mode == "DISARMED":
            # ledger tail(우선) 또는 state:blocked-human 라벨 이슈로 무장 (soft/inline 게이트 보완)
            armed_by = "ledger" if blocked else ("label" if has_blocked_issue(cfg, token, log) else None)
            if armed_by:
                # 새 게이트 사이클 — 직전 사이클의 active_issue 고정을 리셋 (라벨로 재발견)
                state.update(mode="ARMED", blocked_line=tail, redelivered=False, active_issue=None)
                save_json(cfg["state_path"], state)
                log.write(f"ARMED via {armed_by} (blocked ledger tail: {tail[:120]!r})")
                continue
            time.sleep(cfg["disarmed_poll_s"])
            continue

        if mode == "ARMED":
            if not blocked and tail != state.get("blocked_line"):
                state.update(mode="DISARMED", blocked_line=None, active_issue=None)
                save_json(cfg["state_path"], state)
                log.write("DISARM (ledger resumed without delivery)")
                continue
            issue_no, issue_src = resolve_issue(cfg, token, log, active=state.get("active_issue"))
            if issue_no is None:
                if state.get("armed_since") is None:
                    state.update(armed_since=time.time(), unresolved_notified=False)
                    save_json(cfg["state_path"], state)
                log.write("ARMED but no gate issue resolvable (label 미부착? — PROTOCOL §2 위반 가능)")
                if (not state.get("unresolved_notified")) and time.time() - state["armed_since"] > cfg.get("unresolved_notify_s", 900):
                    notify_human(cfg, log, "gate-watcher: ledger는 blocked인데 state:blocked-human 이슈가 없음 — 게이트 요청의 라벨/마커 누락 여부 확인 필요")
                    state.update(unresolved_notified=True)
                    save_json(cfg["state_path"], state)
                time.sleep(cfg["armed_poll_s"])
                continue
            if state.get("armed_since") is not None:
                state.update(armed_since=None, unresolved_notified=False)
            if state.get("active_issue") != issue_no:
                state.update(active_issue=issue_no)
                save_json(cfg["state_path"], state)
                log.write(f"gate issue resolved: #{issue_no} (source={issue_src})")
            try:
                cand = find_verdict(cfg, token, issue_no, state["last_processed_id"], log)
            except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
                log.write(f"GitHub API error: {e}")
                time.sleep(cfg["armed_poll_s"])
                continue
            if cand is not None:
                cid = int(cand["id"])
                try:
                    deliver_nudge(cfg, issue_no, cid)
                    state.update(
                        mode="WAIT_ACK",
                        delivered_id=cid,
                        delivered_at=time.time(),
                        last_processed_id=cid,
                        redelivered=False,
                    )
                    save_json(cfg["state_path"], state)
                    log.write(f"DELIVERED nudge for comment {cid}")
                    try:
                        react_eyes(cfg, token, cid)
                    except Exception as e:  # noqa: BLE001
                        log.write(f"reaction failed (non-fatal): {e}")
                except Exception as e:  # noqa: BLE001
                    log.write(f"DELIVERY FAILED: {e}")
                    notify_human(cfg, log, f"gate-watcher delivery failed: {e}")
                    time.sleep(cfg["armed_poll_s"])
                continue
            time.sleep(cfg["armed_poll_s"])
            continue

        if mode == "WAIT_ACK":
            moved = tail != state.get("blocked_line")
            if moved and not blocked:
                state.update(mode="DISARMED", blocked_line=None, delivered_id=None, active_issue=None)
                save_json(cfg["state_path"], state)
                log.write("ACK (ledger resumed) → DISARMED")
                continue
            if moved and blocked:
                state.update(blocked_line=tail)
                save_json(cfg["state_path"], state)
                log.write("WAIT_ACK: ledger moved but still blocked (baseline updated)")
            elapsed = time.time() - (state.get("delivered_at") or time.time())
            # 최종 escalation 을 먼저 검사한다 — 재전달 분기가 앞서면(구 elif 구조)
            # 재전달이 계속 실패할 때 escalation 에 영영 도달하지 못한다.
            if elapsed > 2 * cfg["ack_timeout_s"]:
                notify_human(
                    cfg,
                    log,
                    f"gate-watcher: no ack {int(elapsed)}s after nudge "
                    f"(comment {state['delivered_id']}) — manual check needed",
                )
                state.update(mode="DISARMED", blocked_line=None, delivered_id=None, active_issue=None)
                save_json(cfg["state_path"], state)
                log.write("DISARM (no ack after redelivery — human notified)")
            elif elapsed > cfg["ack_timeout_s"] and not state.get("redelivered"):
                try:
                    deliver_nudge(cfg, state.get("active_issue") or int(cfg.get("issue_number") or 0), state["delivered_id"])
                    log.write(f"REDELIVERED nudge for comment {state['delivered_id']}")
                except Exception as e:  # noqa: BLE001
                    log.write(f"REDELIVERY FAILED: {e}")
                    notify_human(cfg, log, f"gate-watcher redelivery failed: {e}")
                # 성공/실패 무관 1회로 제한 — 실패 반복 스팸 방지, 종결은 2×timeout escalation 이 맡는다.
                state.update(redelivered=True)
                save_json(cfg["state_path"], state)
            time.sleep(cfg["disarmed_poll_s"])
            continue

        log.write(f"unknown mode {mode!r} — resetting to DISARMED")
        state = default_state(cfg)
        save_json(cfg["state_path"], state)


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CONFIG)
