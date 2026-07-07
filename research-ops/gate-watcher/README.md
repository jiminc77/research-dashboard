# gate-watcher

HUMAN GATE에서 사람 판정 코멘트(`## HUMAN 판정` + `[RESUME]`, author=jiminc77)를 감지해 라이브 gjc tmux 세션에 **"가서 읽어라" nudge만** 전달하는 데몬. 판정 본문은 절대 주입하지 않는다 (공개 레포 주입 방어 — gjc가 자체 fetch로 이중 검증).

## 파일

| 파일 | 역할 |
|---|---|
| `watcher.py` | 데몬 본체 (stdlib 전용, python3 ≥ 3.8) |
| `config.example.json` | 설정 템플릿 → `~/.config/gate-watcher/config.json` |
| `gate-watcher.service` | systemd user unit |
| `tests/test_watcher.py` | T1 단위 테스트 (판정 계약 C1–C4 잠금) |
| `rehearsal.sh` | T2 리허설 (목업 ledger + 목업 tmux — 라이브 무접촉) |

## 배포 (원격 머신, ~10분)

```bash
# 0) T1 테스트
python3 -m unittest discover -s tests -v

# 1) 설정
mkdir -p ~/.config/gate-watcher ~/.local/state/gate-watcher
cp config.example.json ~/.config/gate-watcher/config.json
# 편집 항목:
#  - tmux_session: `tmux ls`로 라이브 gjc 세션 이름 확인 후 기입 (첫 arm 전 사람 확인 1회)
#  - baseline_comment_id: 과거 판정 소급 방지선 — 현재 최대 id로:
#    curl -s "https://api.github.com/repos/jiminc77/DGCC/issues/12/comments?per_page=100" | jq '[.[].id] | max'
#  - armed_substrings: 실제 ledger와 대조:
#    grep -c "human_blocked" /home/simx2204/Workspaces/DGCC/.gjc/ultragoal/ledger.jsonl

# 2) 토큰 (jiminc77-agent fine-grained PAT: DGCC+research-dashboard / Issues RW)
printf 'GITHUB_TOKEN=%s\n' '<PAT>' > ~/.config/gate-watcher/env && chmod 600 ~/.config/gate-watcher/env

# 3) T2 리허설 (research-dashboard에 [TEST] 이슈 만들고)
GITHUB_TOKEN=$(cut -d= -f2 ~/.config/gate-watcher/env) bash rehearsal.sh <TEST-issue-번호>

# 4) 상시 기동
cp gate-watcher.service ~/.config/systemd/user/
systemctl --user daemon-reload && systemctl --user enable --now gate-watcher
loginctl enable-linger $USER
journalctl --user -u gate-watcher -f
```

## 게이트 issue 자동 발견 (v2.1)

대상 issue는 매 ARMED 폴링마다 자동 결정: **(1) `issue_labels` 매치** (open 이슈, 최근 갱신순, PR 제외) → **(2) `issue_number` fallback**. phase가 바뀌어도 config 수정 불필요 — 라벨 상태기계(`state:blocked-human`)를 쓰는 프로젝트는 완전 자동, 라벨 미운용 단계(현 DGCC M3R)는 fallback(#12)으로 동작. 어느 경로로 정해졌는지 `watcher.log`에 기록됨 (`gate issue resolved: #N (source=label|fallback)`).

## 동작 (spec §3)

`DISARMED`(ledger만 30초 감시, API 무호출) → 꼬리에 `human_blocked`/`blocker_classified` → `ARMED`(3분 이슈 폴링) → C1–C5 충족 → tmux nudge + 👀 reaction → `WAIT_ACK` → ledger 재개 → `DISARMED`. 30분 무응답 시 1회 재전달, 재실패 시 사람 알림 후 해제.

## 계약 (요약)

트리거 = author `jiminc77` ∧ 첫 줄 `## HUMAN 판정` ∧ 본문 `[RESUME]` ∧ id > 기준선 ∧ ARMED. agent 계정·타 계정·blockquote 인용·[RESUME] 없는 코멘트는 전부 무시 (tests/가 잠금).

## T3 (M3R 게이트 실전)

수동 nudge 백업 대기: 판정 게시 후 5분 내 👀 reaction 없으면 수동 전달, watcher.log를 #12에 보고 (성패 무관).

## 운영 노트

- C4 구현 = `last_processed_id` 단조 증가 — ARM 이전 게시 판정도 소급 탐지(레이스 안전), `baseline_comment_id`가 과거 이력 차단.
- phase 전환 시: 라벨 도입 전까지는 fallback `issue_number`만 새 게이트 이슈로 갱신 (라벨 도입 후엔 그것도 불필요).
- 라이브 gjc 규약 (issue #12 공지): gjc 코멘트 첫 줄에 `## HUMAN` 금지, 판정 인용은 blockquote로만.
