#!/usr/bin/env python3
"""build_dashboard_data.py — dashboard/data.json 생성기 (dashboard-data.yml 이 15분마다 실행).

레지스트리 원천은 projects/*/project.yml 이다 — 대시보드 CONFIG 하드코딩을 대체한다.
각 프로젝트의 CODE/MGMT 이슈 전량(페이지네이션)과 리포트/계획서 목록을 한 파일로 굽고,
브라우저는 같은 오리진의 이 파일 하나만 읽는다 (GitHub API 직호출·rate limit 제거).

- stdlib 전용 (watcher.py 와 동일 원칙 — 러너/로컬 어디서든 venv 불필요).
- 토큰: env GITHUB_TOKEN (Actions 의 github.token 이면 충분). 없으면 비인증(로컬 테스트용, 60/hr).
- 이슈: state=all & per_page=100, Link rel="next" 전량 추적 (레포당 최대 10쪽=1000개, 초과 시 경고).
- reports/research 목록은 체크아웃된 로컬 디렉토리에서 직접 리스팅 (API 0회).
- 실패는 하드 실패(exit 1) — 부분 데이터를 커밋하느니 지난 data.json 을 유지한다.
"""
import json
import os
import re
import sys
import urllib.request
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
API = "https://api.github.com"
MAX_PAGES = 10

# 대시보드 isGateWaiting 의 라벨-없는 구형 이슈 판정과 동일한 텍스트 신호 (index.html 과 계약)
LEGACY_GATE_SUBSTRINGS = ("human_blocked", "human gate", "### gate request")


def read_project_yml(path: str) -> dict:
    """평평한 `key: "value"` 라인만 뽑는 최소 파서 — project.yml 계약 범위(비중첩 문자열)에 충분.
    중첩 블록(gjc: 등)과 주석은 무시한다. PyYAML 의존을 피하기 위한 의도적 제약."""
    out = {}
    with open(path, encoding="utf-8") as f:
        for ln in f:
            if ln[:1] in ("#", " ", "\t", "\n"):
                continue
            m = re.match(r'^([A-Za-z_]+):\s*"([^"]*)"', ln)
            if not m:
                m = re.match(r"^([A-Za-z_]+):\s*([^#\n]+)", ln)
            if m:
                out[m.group(1)] = m.group(2).strip()
    return out


def gh_json(url: str, token: str):
    req = urllib.request.Request(url)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8")), (r.headers.get("Link", "") or "")


def next_url(link_header: str):
    for part in link_header.split(","):
        if 'rel="next"' in part:
            m = re.search(r"<([^>]+)>", part)
            if m:
                return m.group(1)
    return None


def fetch_issues(repo: str, token: str, _memo={}):
    """레포의 이슈 전량 (PR 제외, 대시보드가 쓰는 필드만). 같은 레포는 1회만 fetch(메모이즈)."""
    if repo in _memo:
        return _memo[repo]
    url = f"{API}/repos/{repo}/issues?state=all&per_page=100"
    raw, pages = [], 0
    while url and pages < MAX_PAGES:
        data, link = gh_json(url, token)
        raw.extend(data or [])
        url = next_url(link)
        pages += 1
    if url:
        print(f"WARNING: {repo} 이슈가 {MAX_PAGES * 100}개 초과 — 초과분 미수집", file=sys.stderr)
    out = []
    for i in raw:
        if "pull_request" in i:
            continue
        hay = ((i.get("title") or "") + " " + (i.get("body") or "")).lower()
        out.append({
            "number": i["number"],
            "title": i.get("title") or "",
            "state": i.get("state"),
            "labels": [l["name"] if isinstance(l, dict) else l for l in (i.get("labels") or [])],
            "updated_at": i.get("updated_at"),
            "html_url": i.get("html_url"),
            "legacy_gate_text": any(s in hay for s in LEGACY_GATE_SUBSTRINGS),
        })
    _memo[repo] = out
    return out


def list_names(dirpath: str, pattern: str):
    if not os.path.isdir(dirpath):
        return []
    return sorted(n for n in os.listdir(dirpath) if re.search(pattern, n))


def main() -> int:
    token = os.environ.get("GITHUB_TOKEN", "")
    projects = []
    pdir = os.path.join(ROOT, "projects")
    for slug in sorted(os.listdir(pdir)):
        yml = os.path.join(pdir, slug, "project.yml")
        if slug.startswith("_") or not os.path.isfile(yml):
            continue
        cfg = read_project_yml(yml)
        missing = [k for k in ("project", "owner", "mgmt_repo", "code_repo") if not cfg.get(k)]
        if missing:
            print(f"STOP: projects/{slug}/project.yml 필수 키 누락: {missing}", file=sys.stderr)
            return 1
        base = cfg.get("docs_base") or f"projects/{slug}"
        projects.append({
            "name": cfg["project"],
            "owner": cfg["owner"],
            "mgmt_repo": cfg["mgmt_repo"],
            "code_repo": cfg["code_repo"],
            "docs_base": base,
            "code_issues": fetch_issues(f"{cfg['owner']}/{cfg['code_repo']}", token),
            "mgmt_issues": fetch_issues(f"{cfg['owner']}/{cfg['mgmt_repo']}", token),
            "reports": list_names(os.path.join(ROOT, base, "reports"), r"_report\.html$"),
            "research": list_names(os.path.join(ROOT, base, "research"), r"_research_plan\.html$"),
        })
    if not projects:
        print("STOP: projects/*/project.yml 이 하나도 없음", file=sys.stderr)
        return 1
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "projects": projects,
    }
    dst = os.path.join(ROOT, "dashboard", "data.json")
    tmp = dst + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))
        f.write("\n")
    os.replace(tmp, dst)
    n_issues = sum(len(p["code_issues"]) + len(p["mgmt_issues"]) for p in projects)
    print(f"data.json: {len(projects)} project(s), issues {n_issues}, "
          f"reports {sum(len(p['reports']) for p in projects)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
