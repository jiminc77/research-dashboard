# gate-watcher 경보 유닛 (alerts/)

기존 `gate-watcher.service`(원격 워크스테이션 데몬, 리턴 경로)의 **가동 상태를 감시**하는 보조 유닛.
`gate-watcher.service` 자체는 **수정·개명하지 않는다** — OnFailure 훅은 drop-in 한 줄로만 붙인다.

| 파일 | 역할 |
|---|---|
| `gate-watcher-onfailure.service` | `gate-watcher.service` 가 실패하면 ntfy 경보 (OnFailure 훅) |
| `gate-watcher-liveness.service` | `is-active` 체크 → inactive 면 ntfy 경보 |
| `gate-watcher-liveness.timer` | 위 체크를 5분마다 기동 |

## 설치 (3줄 — 원격 워크스테이션에서, systemd --user)

```bash
# 0) NTFY_TOPIC 을 환경파일에 둔다 (secret — 레포에 커밋하지 않는다)
mkdir -p ~/.config/gate-watcher && printf 'NTFY_TOPIC=%s\n' "<your-topic>" > ~/.config/gate-watcher/env

# 1) 세 유닛을 user 디렉토리에 복사 + 기존 gate-watcher 에 OnFailure= 한 줄 추가
cp gate-watcher-onfailure.service gate-watcher-liveness.service gate-watcher-liveness.timer ~/.config/systemd/user/
systemctl --user edit gate-watcher    # 에디터에 아래 2줄만: [Unit] / OnFailure=gate-watcher-onfailure.service

# 2) 리로드 + liveness 타이머 활성화
systemctl --user daemon-reload && systemctl --user enable --now gate-watcher-liveness.timer
```

`systemctl --user edit gate-watcher` 로 여는 drop-in 내용:

```ini
[Unit]
OnFailure=gate-watcher-onfailure.service
```

## 주의

- **NTFY_TOPIC** 은 환경파일(`~/.config/gate-watcher/env`)에서 치환된다. 값은 secret — 공개 레포에 넣지 않는다.
- **라이브 호스트(원격 워크스테이션) 변경·재배치는 사람이 수행**한다. 이 킷은 유닛 원본일 뿐, 운영 중 호스트에 자동 배포하지 않는다.
- 확인: `systemctl --user list-timers gate-watcher-liveness.timer`, `systemctl --user status gate-watcher`.
