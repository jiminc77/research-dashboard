#!/usr/bin/env python3
"""research-ops gate-watcher (spec v2.1, 2026-07-07).

v2.1: 게이트 issue 자동 발견 — issue_labels(우선) → issue_number(fallback).
phase가 바뀌어도 config 수정 없이 동작 (라벨 상태기계 도입 시 완전 자동).

HUMAN GATE에서 사람 판정 코멘트를 감지해 라이브 gjc tmux 세션에
"가서 읽어라" nudge만 전달한다. 판정 본문은 절대 주입하지 않는다.

- stdlib 전용 (원격 머신에서 venv 불필요)
- 상태 기계: DISARMED → ARMED → WAIT_ACK → DISARMED (spec §3)
- 판정 계약 C1–C5: evaluate_comment() (spec §2) — tests/test_watcher.py가 잠금
"""
import json
import os
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


def evaluate_comment(comment: dict, cfg: dict, last_processed_id: int):
    """판정 계약 C1–C4. C5(ARMED)는 호출 측 상태 기계가 보장.

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
    if cfg["resume_token"] not in body:
        return False, "C3 reject: no [RESUME] token"
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


def resolve_issue(cfg: dict, token: str, log: Log):
    """게이트 issue 결정: (1) issue_labels 매치 (open, 최근 갱신순) → (2) issue_number fallback.

    Returns (issue_number | None, source_str)
    """
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


def find_verdict(cfg: dict, token: str, issue_number: int, last_processed_id: int, log: Log):
    url = (
        f"https://api.github.com/repos/{cfg['repo']}/issues/"
        f"{issue_number}/comments?per_page=100"
    )
    comments = gh_api(url, token)  # 오래된 것 → 최신 순
    candidate = None
    for c in comments or []:
        ok, reason = evaluate_comment(c, cfg, last_processed_id)
        if ok:
            candidate = c  # 통과분 중 최신 것 채택
        elif int(c.get("id", 0)) > int(last_processed_id):
            log.write(f"skip comment {c.get('id')}: {reason}")
    return candidate


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
        tail = ledger_tail(cfg["ledger_path"])
        blocked = is_blocked(tail, cfg)
        mode = state["mode"]

        if mode == "DISARMED":
            if blocked:
                state.update(mode="ARMED", blocked_line=tail, redelivered=False)
                save_json(cfg["state_path"], state)
                log.write(f"ARMED (blocked ledger tail: {tail[:120]!r})")
                continue
            time.sleep(cfg["disarmed_poll_s"])
            continue

        if mode == "ARMED":
            if not blocked and tail != state.get("blocked_line"):
                state.update(mode="DISARMED", blocked_line=None)
                save_json(cfg["state_path"], state)
                log.write("DISARM (ledger resumed without delivery)")
                continue
            issue_no, issue_src = resolve_issue(cfg, token, log)
            if issue_no is None:
                log.write("ARMED but no gate issue resolvable (labels/fallback both empty)")
                time.sleep(cfg["armed_poll_s"])
                continue
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
                state.update(mode="DISARMED", blocked_line=None, delivered_id=None)
                save_json(cfg["state_path"], state)
                log.write("ACK (ledger resumed) → DISARMED")
                continue
            if moved and blocked:
                state.update(blocked_line=tail)
                save_json(cfg["state_path"], state)
                log.write("WAIT_ACK: ledger moved but still blocked (baseline updated)")
            elapsed = time.time() - (state.get("delivered_at") or time.time())
            if elapsed > cfg["ack_timeout_s"] and not state.get("redelivered"):
                try:
                    deliver_nudge(cfg, state.get("active_issue") or int(cfg.get("issue_number") or 0), state["delivered_id"])
                    state.update(redelivered=True)
                    save_json(cfg["state_path"], state)
                    log.write(f"REDELIVERED nudge for comment {state['delivered_id']}")
                except Exception as e:  # noqa: BLE001
                    log.write(f"REDELIVERY FAILED: {e}")
                    notify_human(cfg, log, f"gate-watcher redelivery failed: {e}")
            elif elapsed > 2 * cfg["ack_timeout_s"]:
                notify_human(
                    cfg,
                    log,
                    f"gate-watcher: no ack {int(elapsed)}s after nudge "
                    f"(comment {state['delivered_id']}) — manual check needed",
                )
                state.update(mode="DISARMED", blocked_line=None, delivered_id=None)
                save_json(cfg["state_path"], state)
                log.write("DISARM (no ack after redelivery — human notified)")
            time.sleep(cfg["disarmed_poll_s"])
            continue

        log.write(f"unknown mode {mode!r} — resetting to DISARMED")
        state = default_state(cfg)
        save_json(cfg["state_path"], state)


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CONFIG)
