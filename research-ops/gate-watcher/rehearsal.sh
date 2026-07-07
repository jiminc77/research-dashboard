#!/usr/bin/env bash
# T2 리허설 (spec v2 §6) — 라이브 세션 무접촉. 목업 ledger + 목업 tmux 세션으로 전 경로 검증.
# 사용: GITHUB_TOKEN=<jiminc77-agent PAT> bash rehearsal.sh <rehearsal-issue-number>
# (사전에 research-dashboard에 "[TEST] gate-watcher rehearsal" 이슈를 만들고 번호를 넘길 것)
set -euo pipefail
ISSUE="${1:?rehearsal issue number 필요}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d /tmp/gw-rehearsal.XXXX)"
SESSION="gw-rehearsal"

echo "== 목업 준비 (workdir: $WORK) =="
printf '%s\n' '{"event":"checkpoint"}' '{"event":"human_blocked","goal":"REHEARSAL"}' > "$WORK/ledger.jsonl"
tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" "cat > $WORK/received.txt"

python3 - "$HERE" "$WORK" "$ISSUE" <<'PY'
import json, sys
here, work, issue = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = json.load(open(f"{here}/config.example.json"))
cfg.update({
    "repo": "jiminc77/research-dashboard",
    "issue_number": int(issue),
    "issue_labels": [],
    "ledger_glob": "",
    "tmux_session": "gw-rehearsal",
    "ledger_path": f"{work}/ledger.jsonl",
    "baseline_comment_id": 0,
    "log_path": f"{work}/watcher.log",
    "state_path": f"{work}/state.json",
    "disarmed_poll_s": 2,
    "armed_poll_s": 5,
    "ack_timeout_s": 60,
})
json.dump(cfg, open(f"{work}/config.json", "w"), ensure_ascii=False, indent=2)
print(f"rehearsal config: {work}/config.json")
PY

echo "== watcher 기동 (백그라운드) =="
python3 "$HERE/watcher.py" "$WORK/config.json" &
WPID=$!
trap 'kill $WPID 2>/dev/null; tmux kill-session -t $SESSION 2>/dev/null' EXIT
sleep 5

cat <<GUIDE
== 이제 사람 확인 절차 ==
1) jiminc77 계정으로 research-dashboard issue #$ISSUE 에 아래 코멘트 게시:
   ### GATE VERDICT
   id: REHEARSAL-G1
   choice: A
   rationale: watcher rehearsal
2) ~5-10초 후 수신 확인:
   tmux capture-pane -p -t $SESSION   (또는 cat $WORK/received.txt)
   cat $WORK/watcher.log              (ARMED → DELIVERED 로그)
3) 위반 케이스 1건 확인 권장: choice: 필드 없는 GATE VERDICT → skip 로그(C3)만, 미전달
4) ledger 재개 시뮬레이션: echo '{"event":"goal_resumed"}' >> $WORK/ledger.jsonl
   → watcher.log 에 "ACK (ledger resumed) → DISARMED"
5) 종료: Ctrl-C. 로그·스크린샷을 T2 증거로 커밋.
GUIDE
wait $WPID
