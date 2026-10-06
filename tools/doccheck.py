#!/usr/bin/env python3
"""doccheck v1.4 — 만능프롬프트 v2.6 문서 점검기 (Python 3.9+, 표준 라이브러리만, 읽기 전용).

점검 항목
  - STATUS.md: HOT 구역 표식, Task 제목 형식·중복 ID·허용 상태, 상태별 필수 필드
  - Scope Guard: 열린 Task마다 근원(R-xxx / bug / safety / maint)이 있는지
  - HOT 구역이 가리키는 T-ID가 실제로 있는지, '현재 Task'가 진행 중 상태인지
  - STATUS가 현재 Milestone 범위를 넘어 커졌는지(열린 Task 수)
  - 문서 지도 SSOT 열: 요구 파일 또는 결정 파일/인덱스 (없으면 PROJECT/DECISIONS 기본값)
  - 결정 원본: 제목 형식·중복 ID·허용 상태, 파일 간 superseded 대상 존재
  - STATUS와 선언된 요구/결정 원본의 R-ID·D-ID가 정의되어 있는지
  - ID 형식: R-001 / T-001 / D-001 (숫자 3자리 이상). T-1 같은 비표준 ID는 오류
  - docs/README.md 문서 지도에 docs/ 문서가 파일 단위로 모두 실려 있는지, 없는 파일을 가리키지 않는지
  - AGENTS.md, README.md, docs/**/*.md 의 상대 링크: 파일과 #anchor(제목) 존재 여부, 비밀키로 보이는 문자열
  - archive 폴더 사용 (과거 이력은 Git으로)
  - 일반 모드: 작업 트리 검사. --git: 모든 문서 검사를 고정한 index 스냅샷에서 수행
  - --git: HEAD → index Task 정리 계약 (종료 상태·필수 필드를 먼저 커밋)
  - --base: 조상 base 이후 전체 부모 경로의 STATUS 이력 + 고정 HEAD 문서 (병용 시 index)
  - index 충돌·변경·읽기 실패는 점검 불가. 사용자 index·작업 트리를 수정하지 않음

사용 (저장소 루트에서)
  python3 tools/doccheck.py            # 점검
  python3 tools/doccheck.py --status   # 지금 어디까지 했는지 요약 + 점검
  python3 tools/doccheck.py --git      # pre-commit: HEAD ↔ staged 비교
  python3 tools/doccheck.py --base origin/main   # CI: 이력 + HEAD 문서
  python3 tools/doccheck.py --git --base origin/main   # 이력 + index 문서 (기존 CLI 호환)
  python3 tools/doccheck.py --strict   # 경고도 실패로 처리

종료 코드: 0 통과, 1 오류 있음, 2 점검 불가(STATUS 없음, 읽기 실패, index 충돌·변경 등)
점검기는 문서를 고치지 않는다.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

TASK_STATUSES = {
    "planned", "inProgress", "verificationPending",
    "blocked", "onHold", "completed", "cancelled", "moved",
}
OPEN_STATUSES = {"planned", "inProgress", "verificationPending", "blocked", "onHold"}
REQUIRED_FIELDS = {
    "completed": ["근거"],
    "blocked": ["사유", "조건"],
    "onHold": ["사유", "조건"],
    "cancelled": ["사유"],
    "moved": ["이관"],
}
# ID 표준: 접두어 + 숫자 3자리 이상 (R-001, T-001, D-001). 모든 정규식이 이 하나를 쓴다.
ID_NUM = r"\d{3,}"
ORIGIN_OK = re.compile(rf"^(R-{ID_NUM}(?!\d)|bug|safety|maint)(?![A-Za-z])")
OPEN_TASK_WARN = 15
HOT_LINE_WARN = 40
DECISION_STATUS = re.compile(rf"^(proposed|accepted|rejected|superseded by (D-{ID_NUM}))$")

TASK_HEAD = re.compile(rf"^###\s+(T-{ID_NUM})(?!\d)(.*?)\[([^\]]+)\]")
DEC_HEAD = re.compile(rf"^###\s+(D-{ID_NUM})(?!\d)(.*?)\[([^\]]+)\]")
REQ_DEF = re.compile(rf"^\s*[-*]\s+(R-{ID_NUM})(?!\d)")
# 한글 조사가 바로 붙는 경우(예: "T-005에서")도 잡도록 \b 대신 명시적 경계를 쓴다
ID_REF = re.compile(rf"(?<![A-Za-z0-9_-])([RDT]-{ID_NUM})(?!\d)")
BAD_ID = re.compile(r"(?<![A-Za-z0-9_-])([RDT]-\d{1,2})(?!\d)")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
HTML_ID = re.compile(r"<a\s+[^>]*(?:id|name)=[\"']([^\"']+)[\"']", re.I)
MD_PATH = re.compile(r"(?<![\w/.-])((?:\.\./|\./)?[\w][\w./-]*\.md)(?![\w.-])")
LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)\)")
SECRET_PATTERNS = [
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), "개인 키"),
    (re.compile(r"\bAKIA[0-9A-Z]{16}\b"), "AWS 액세스 키"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b"), "GitHub 토큰"),
    (re.compile(r"\bsk-[A-Za-z0-9_\-]{20,}\b"), "API 비밀키(sk-)"),
    (re.compile(r"\bxox[baprs]-[A-Za-z0-9\-]{10,}\b"), "Slack 토큰"),
    (re.compile(r"\bAIza[0-9A-Za-z_\-]{35}\b"), "Google API 키"),
]


class SnapshotError(Exception):
    """검사 기준을 읽거나 고정할 수 없음. PASS로 처리하지 않는다."""


class WorkingTree:
    def __init__(self, root: Path):
        self.root = root

    def read_text(self, path: Path) -> str:
        if not path.resolve().is_relative_to(self.root):
            raise SnapshotError("프로젝트 밖의 문서를 읽을 수 없다")
        return path.read_text(encoding="utf-8")

    def is_file(self, path: Path) -> bool:
        return path.is_file()

    def is_dir(self, path: Path) -> bool:
        return path.is_dir()

    def exists(self, path: Path) -> bool:
        return path.exists()

    def markdown_files(self, directory: Path) -> list[Path]:
        return sorted(p for p in directory.rglob("*.md") if p.is_file())

    def verify(self) -> None:
        pass


def git_bytes(root: Path, *args: str) -> bytes:
    """필수 Git 읽기는 실패를 '파일 없음'으로 바꾸지 않는다."""
    try:
        result = subprocess.run(["git", "-C", str(root), *args],
                                capture_output=True, timeout=15,
                                env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"})
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SnapshotError(f"Git 읽기 실패: {args[0]}") from exc
    if result.returncode:
        raise SnapshotError(f"Git 읽기 실패: {args[0]} (exit {result.returncode})")
    return result.stdout


class IndexSnapshot(WorkingTree):
    """index의 경로→불변 blob ID를 고정한다. 작업 트리로 보충하지 않는다."""

    def __init__(self, root: Path):
        self.root = root
        top = Path(os.fsdecode(git_bytes(root, "rev-parse", "--show-toplevel")).strip()).resolve()
        if top != root:
            raise SnapshotError("--git의 --root는 Git 저장소 루트여야 한다 (하위 프로젝트는 지원하지 않음)")
        index_path = Path(os.fsdecode(git_bytes(root, "rev-parse", "--git-path", "index")).strip())
        self.index_path = index_path if index_path.is_absolute() else root / index_path
        self.index_digest = self.digest()
        self.manifest = self.index_manifest()
        self.entries: dict[Path, tuple[str, str]] = {}
        self.texts: dict[Path, str] = {}
        self.directories: set[Path] = set()
        if self.manifest and not self.manifest.endswith(b"\0"):
            raise SnapshotError("index 목록 형식을 해석할 수 없다")
        for record in self.manifest.split(b"\0"):
            if not record:
                continue
            match = re.fullmatch(rb"(100644|100755|120000|160000) ([0-9a-f]{40}|[0-9a-f]{64}) ([0-3])\t(.+)", record, re.S)
            if not match or match[3] != b"0" or set(match[2]) == {ord("0")}:
                raise SnapshotError("해석 불가능하거나 충돌 중인 index 상태다")
            rel = Path(os.fsdecode(match[4]))
            if rel.is_absolute() or ".." in rel.parts:
                raise SnapshotError("index 경로가 저장소 경계를 벗어난다")
            path = root / rel
            if path in self.entries:
                raise SnapshotError("index 경로가 중복된다")
            self.entries[path] = (match[1].decode(), match[2].decode())
            self.directories.update(path.parents)
        # intent-to-add는 다음 커밋의 파일이 아니다. 빈 blob으로 오인하지 않는다.
        visible = git_bytes(root, "diff", "--cached", "--name-only", "-z", "--diff-filter=A", "--ita-visible-in-index", "--")
        hidden = git_bytes(root, "diff", "--cached", "--name-only", "-z", "--diff-filter=A", "--ita-invisible-in-index", "--")
        if visible != hidden:
            raise SnapshotError("intent-to-add 항목이 있다. 실제 index 내용을 확정한 뒤 검사한다")
        self.verify()

    @staticmethod
    def normalize(path: Path) -> Path:
        # resolve()는 작업 트리의 symlink를 따라가므로 index 검사에 쓰지 않는다.
        return Path(os.path.abspath(path))

    def index_manifest(self) -> bytes:
        return git_bytes(self.root, "ls-files", "--stage", "--full-name", "-z")

    def digest(self) -> bytes:
        try:
            return hashlib.sha256(self.index_path.read_bytes()).digest()
        except FileNotFoundError:
            return b""  # 최초 add 전. STATUS 없음으로 점검 불가 처리한다.

    def read_text(self, path: Path) -> str:
        path = self.normalize(path)
        if path not in self.texts:
            entry = self.entries.get(path)
            if entry is None or entry[0] not in {"100644", "100755"}:
                raise SnapshotError(f"snapshot의 일반 문서 파일을 읽을 수 없다: {path.relative_to(self.root) if path.is_relative_to(self.root) else path}")
            try:
                self.texts[path] = git_bytes(self.root, "cat-file", "blob", entry[1]).decode("utf-8")
            except UnicodeError as exc:
                raise SnapshotError(f"UTF-8 문서를 읽을 수 없다: {path.relative_to(self.root)}") from exc
        return self.texts[path]

    def is_file(self, path: Path) -> bool:
        entry = self.entries.get(self.normalize(path))
        return entry is not None and entry[0] != "160000"

    def is_dir(self, path: Path) -> bool:
        path = self.normalize(path)
        return path in self.directories or self.entries.get(path, (None,))[0] == "160000"

    def exists(self, path: Path) -> bool:
        return self.is_file(path) or self.is_dir(path)

    def markdown_files(self, directory: Path) -> list[Path]:
        directory = self.normalize(directory)
        return sorted(p for p in self.entries if directory in p.parents and p.suffix == ".md" and self.is_file(p))

    def verify(self) -> None:
        if self.digest() != self.index_digest or self.index_manifest() != self.manifest:
            raise SnapshotError("검사 도중 index가 변경됐다. 현재 index로 다시 검사해야 한다")


class CommitSnapshot(IndexSnapshot):
    """고정 commit tree. index/작업 트리 조회 없이 기존 snapshot 읽기 인터페이스를 쓴다."""

    def __init__(self, root: Path, commit: str):
        self.root, self.commit = root, commit
        self.entries, self.texts, self.directories = {}, {}, set()
        manifest = git_bytes(root, "ls-tree", "-r", "-z", commit)
        for record in manifest.split(b"\0"):
            if not record:
                continue
            match = re.fullmatch(rb"(100644|100755|120000|160000) (?:blob|commit) ([0-9a-f]{40}|[0-9a-f]{64})\t(.+)", record, re.S)
            if not match:
                raise SnapshotError("commit tree 목록을 해석할 수 없다")
            path = root / os.fsdecode(match[3])
            self.entries[path] = (match[1].decode(), match[2].decode())
            self.directories.update(path.parents)

    def verify(self) -> None:
        pass  # commit과 blob ID는 불변이다.


class Report:
    def __init__(self, root: Path, snapshot: WorkingTree | None = None):
        self.root = root
        self.snapshot = snapshot if snapshot is not None else WorkingTree(root)
        self.anchors: dict[Path, set[str]] = {}
        self.pending: set[tuple[Path, int]] = set()
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def _loc(self, path: Path, line: int | None) -> str:
        try:
            rel = path.relative_to(self.root)
        except ValueError:
            rel = path
        return f"{rel}:{line}" if line else f"{rel}"

    def error(self, path: Path, line: int | None, msg: str) -> None:
        self.errors.append(f"ERROR {self._loc(path, line)} {msg}")

    def warn(self, path: Path, line: int | None, msg: str) -> None:
        self.warnings.append(f"WARN  {self._loc(path, line)} {msg}")


def strip_code(lines: list[str]) -> list[tuple[int, str]]:
    """코드 블록(``` 또는 ~~~) 안의 줄을 빼고 (줄번호, 내용)을 돌려준다."""
    out, fence = [], None
    for i, line in enumerate(lines, 1):
        s = line.lstrip()
        if fence is None and (s.startswith("```") or s.startswith("~~~")):
            fence = s[:3]
            continue
        if fence is not None:
            if s.startswith(fence):
                fence = None
            continue
        out.append((i, line))
    return out


def parse_blocks(lines: list[tuple[int, str]], head: re.Pattern):
    """### 제목 단위로 묶는다. [(id, status, line_no, title, body_text)]"""
    blocks, cur = [], None
    for no, line in lines:
        if line.startswith("#"):
            if cur:
                blocks.append(cur)
                cur = None
            m = head.match(line)
            if m:
                cur = [m.group(1), m.group(3).strip(), no, m.group(2).strip(), []]
            continue
        if cur is not None:
            cur[4].append(line)
    if cur:
        blocks.append(cur)
    return [(b[0], b[1], b[2], b[3], "\n".join(b[4])) for b in blocks]


def field_value(body: str, name: str) -> str | None:
    m = re.search(rf"{re.escape(name)}\s*:\s*([^·\n]*)", body)
    return m.group(1).strip() if m else None


def hot_section(lines: list[str]):
    start = end = None
    for i, line in enumerate(lines, 1):
        if "HOT:START" in line:
            start = i if start is None else -1
        elif "HOT:END" in line:
            end = i if end is None else -1
    return start, end


def split_status(raw: list[str]):
    """(hot_ok, hot_lines, body_lines) — HOT 구역과 나머지를 나눈다."""
    hs, he = hot_section(raw)
    lines = strip_code(raw)
    hot_ok = bool(hs and he and hs > 0 and he > hs)
    hot = [(n, l) for n, l in lines if hot_ok and hs < n < he]
    body = [(n, l) for n, l in lines if not (hot_ok and hs <= n <= he)]
    return hot_ok, hot, body


def hot_value(hot_lines: list[tuple[int, str]], key: str) -> tuple[int, str] | None:
    for no, line in hot_lines:
        m = re.match(rf"^\s*[-*]\s*{re.escape(key)}\s*:\s*(.*)$", line)
        if m:
            return no, m.group(1).strip()
    return None


def check_status(rep: Report, path: Path):
    raw = rep.snapshot.read_text(path).splitlines()
    hs, he = hot_section(raw)
    if hs is None or he is None:
        rep.error(path, None, "HOT 구역 표식(<!-- HOT:START --> / <!-- HOT:END -->)이 없다")
    elif hs < 0 or he < 0:
        rep.error(path, None, "HOT 구역 표식이 두 번 이상 있다")
    elif he < hs:
        rep.error(path, he, "HOT:END가 HOT:START보다 앞에 있다")
    elif he - hs - 1 > HOT_LINE_WARN:
        rep.warn(path, hs, f"HOT 구역이 {he - hs - 1}줄이다. 지금 상태만 남길 것")

    hot_ok, hot_lines, body_lines = split_status(raw)
    tasks = parse_blocks(body_lines, TASK_HEAD)
    seen: dict[str, int] = {}
    by_id: dict[str, str] = {}
    for tid, st, no, _title, body in tasks:
        if tid in seen:
            rep.error(path, no, f"{tid} ID 중복 (처음: {seen[tid]}줄)")
        seen.setdefault(tid, no)
        by_id[tid] = st
        if st not in TASK_STATUSES:
            rep.error(path, no, f"{tid} 허용되지 않은 상태 [{st}] — 허용: {', '.join(sorted(TASK_STATUSES))}")
            continue
        for f in REQUIRED_FIELDS.get(st, []):
            if not field_value(body, f):
                rep.error(path, no, f"{tid} [{st}] 에 '{f}:' 값이 없다")
        if st in OPEN_STATUSES:
            origin = field_value(body, "근원")
            if not origin:
                rep.error(path, no, f"{tid} 근원이 없다 (Scope Guard) — '근원: R-xxx | bug (재현: …) | safety | maint (승인: …)'. 없으면 백로그로")
            elif not ORIGIN_OK.match(origin):
                rep.error(path, no, f"{tid} 근원 '{origin}' 은 R-xxx / bug / safety / maint 중 하나가 아니다")
        if st == "verificationPending" and not (field_value(body, "대기") or field_value(body, "근거")):
            rep.warn(path, no, f"{tid} [verificationPending] 에 무엇을 기다리는지('대기:')가 없다")

    for no, line in body_lines:
        if re.match(r"^###\s+T-\d+", line) and not TASK_HEAD.match(line):
            rep.error(path, no, "Task 제목 형식 오류 — '### T-001 제목 [상태]' (ID는 숫자 3자리 이상)")

    for no, line in hot_lines:
        for ref in ID_REF.findall(line):
            if ref.startswith("T-") and ref not in by_id:
                rep.error(path, no, f"HOT 구역이 가리키는 {ref} 가 Task 목록에 없다")
    cur = hot_value(hot_lines, "현재 Task")
    if cur:
        for ref in ID_REF.findall(cur[1]):
            st = by_id.get(ref)
            if st and st not in {"inProgress", "verificationPending"}:
                rep.warn(path, cur[0], f"HOT '현재 Task' {ref} 의 상태가 [{st}] 이다 — HOT 구역을 실제 상태에 맞출 것")

    n_open = sum(1 for s in by_id.values() if s in OPEN_STATUSES)
    if n_open > OPEN_TASK_WARN:
        rep.warn(path, None, f"열린 Task가 {n_open}개다. 현재 Milestone 밖 항목은 백로그로 옮길 것(moved)")
    if hot_ok and not tasks:
        rep.warn(path, None, "Task가 하나도 없다")

    refs = {(r, n) for n, l in hot_lines + body_lines for r in ID_REF.findall(l) if not r.startswith("T-")}
    return tasks, hot_lines, refs


def map_declarations(rep: Report, path: Path):
    """자유 문구 역할을 추측하지 않는다. 기존 표의 선택적 SSOT 열만 해석한다."""
    if not rep.snapshot.is_file(path):
        return []
    rows, header = [], None
    for no, line in strip_code(rep.snapshot.read_text(path).splitlines()):
        if not line.strip().startswith("|") or not line.strip().endswith("|"):
            header = None
            continue
        cells = [c.strip() for c in line.strip()[1:-1].split("|")]
        if "파일" in cells and "SSOT" in cells:
            header = cells
            continue
        if header is None or all(re.fullmatch(r":?-+:?", c) for c in cells):
            continue
        if len(cells) != len(header):
            rep.error(path, no, "SSOT 표의 열 수가 맞지 않는다")
            continue
        role = cells[header.index("SSOT")].strip("`")
        if not role or role == "-":
            continue
        if role not in {"requirements", "decisions", "decisions-index", "pending"}:
            rep.error(path, no, f"알 수 없는 SSOT 역할: {role}")
            continue
        cell = cells[header.index("파일")]
        link = re.fullmatch(r"\[[^\]]+\]\(([^)\s]+)\)", cell)
        target = link[1] if link else cell.strip("`")
        dest = source_path(rep, path, no, target)
        if dest is None:
            continue
        if role == "pending":
            if link or rep.snapshot.exists(dest):
                rep.error(path, no, "pending은 아직 없는 조건부 문서를 링크 없이 경로로만 적는다")
            else:
                rep.pending.add((path, no))
            rows.append((role, dest, no))
            continue
        if not rep.snapshot.is_file(dest):
            rep.error(path, no, f"선언한 SSOT 파일이 없다: {target}")
        rows.append((role, dest, no))
    return rows


def source_path(rep: Report, owner: Path, no: int, target: str) -> Path | None:
    target = unquote(target)
    dest = Path(os.path.abspath(owner.parent / target))
    if (re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or Path(target).is_absolute()
            or "#" in target or "?" in target or dest.suffix != ".md"
            or not dest.is_relative_to(rep.root)
            or any(part.startswith(".") for part in dest.relative_to(rep.root).parts)):
        rep.error(owner, no, "SSOT는 프로젝트 안의 숨김·임시 영역 밖 Markdown 파일이어야 한다")
        return None
    if not isinstance(rep.snapshot, IndexSnapshot) and dest.resolve() != dest:
        rep.error(owner, no, "SSOT 경로의 symlink는 지원하지 않는다")
        return None
    return dest


def discover_sources(rep: Report, docs: Path):
    mp = docs / "README.md"
    rows = map_declarations(rep, mp)
    requirements = [p for role, p, _ in rows if role == "requirements"]
    decisions = [(role, p) for role, p, _ in rows if role.startswith("decisions")]
    if len(requirements) > 1:
        rep.error(mp, None, "요구사항 SSOT가 둘 이상 선언됐다")
    if len(decisions) > 1:
        rep.error(mp, None, "결정 SSOT가 둘 이상 선언됐다 — 하나의 파일 또는 인덱스를 지정한다")
    project = requirements[0] if requirements else docs / "PROJECT.md"
    if not rep.snapshot.is_file(project):
        rep.error(mp, None, "요구사항 SSOT가 없다 — PROJECT.md 또는 requirements 역할의 기존 명세가 필요하다")
    # 기본 경로도 같은 경계 검사. 숨김·외부·symlink를 원본으로 승격하지 않는다.
    if source_path(rep, mp, 1, os.path.relpath(project, docs)) is None:
        project = None
    decision_files = []
    if not decisions:
        default = docs / "DECISIONS.md"
        if rep.snapshot.is_file(default):
            decisions = [("decisions", default)]
    for role, path in decisions[:1]:
        if source_path(rep, mp, 1, os.path.relpath(path, docs)) is None or not rep.snapshot.is_file(path):
            continue
        if role == "decisions":
            decision_files.append(path)
            continue
        if path.name != "README.md" or path.parent == docs or not path.is_relative_to(docs):
            rep.error(mp, None, "결정 인덱스는 docs 하위 폴더의 README.md여야 한다")
            continue
        for child_role, child, no in map_declarations(rep, path):
            if child_role == "pending":
                continue
            if child_role != "decisions" or child.parent != path.parent or child == path:
                rep.error(path, no, "결정 인덱스에는 같은 폴더의 개별 decisions 파일만 선언한다")
            elif child in decision_files:
                rep.error(path, no, "결정 파일이 중복 선언됐다")
            elif rep.snapshot.is_file(child):
                decision_files.append(child)
    return project, decision_files


def check_sources(rep: Report, project: Path | None, decisions: list[Path], status: Path, status_refs):
    req_ids, dec_ids, seen, refs = set(), set(), {}, []
    if project and rep.snapshot.is_file(project):
        for no, line in strip_code(rep.snapshot.read_text(project).splitlines()):
            match = REQ_DEF.match(line)
            if match:
                if match[1] in req_ids:
                    rep.error(project, no, f"{match[1]} ID 중복")
                req_ids.add(match[1])
            refs.extend((project, no, r) for r in ID_REF.findall(line) if not match or r != match[1])
    for path in decisions:
        lines = strip_code(rep.snapshot.read_text(path).splitlines())
        for did, st, no, _title, _body in parse_blocks(lines, DEC_HEAD):
            if did in seen:
                rep.error(path, no, f"{did} ID 중복 (처음: {rep._loc(*seen[did])})")
            seen.setdefault(did, (path, no))
            dec_ids.add(did)
            if not DECISION_STATUS.fullmatch(st):
                rep.error(path, no, f"{did} 허용되지 않은 상태 [{st}]")
        for no, line in lines:
            if re.match(r"^###\s+D-\d+", line) and not DEC_HEAD.match(line):
                rep.error(path, no, "결정 제목 형식 오류 — '### D-001 제목 [상태]'")
            refs.extend((path, no, r) for r in ID_REF.findall(line))
    refs.extend((status, no, r) for r, no in status_refs)
    for path, no, ref in refs:
        if ref.startswith("R-") and ref not in req_ids:
            label = project.name if project else "정식 SSOT"
            rep.error(path, no, f"{ref} 가 {label} 요구사항에 없다")
        if ref.startswith("D-") and ref not in dec_ids:
            rep.error(path, no, f"{ref} 가 DECISIONS.md에 없다 (또는 선언된 결정 SSOT에도 없음)")
    return req_ids, dec_ids


def _mentions(text: str, rel: str) -> bool:
    return re.search(rf"(?<![\w./-])(?:\./)?{re.escape(rel)}(?![\w.-])", text) is not None


def check_doc_map(rep: Report, docs: Path) -> None:
    """문서 지도는 파일 단위로 검사한다. 폴더 이름만 적는 것은 인정하지 않는다.
    예외: evidence/ 는 폴더 단위 허용. 폴더에 자체 목록 X/README.md가 있고 지도에 그 파일이 있으면
    폴더 안 문서는 X/README.md에 (X 기준 상대 경로로) 적혀 있으면 된다."""
    mp = docs / "README.md"
    md = [p for p in rep.snapshot.markdown_files(docs) if p != mp]
    md = [p for p in md if p.relative_to(docs).parts[0] != "evidence"]
    if not rep.snapshot.is_file(mp):
        if md:
            rep.error(mp, None, "docs/ 가 있으면 문서 지도(docs/README.md)가 있어야 한다 — Core §6.5")
        return
    text = rep.snapshot.read_text(mp)
    for p in md:
        rel = p.relative_to(docs).as_posix()
        if _mentions(text, rel):
            continue
        owner = None
        for parent in p.relative_to(docs).parents:
            if parent == Path("."):
                break
            idx = docs / parent / "README.md"
            if rep.snapshot.is_file(idx) and idx != p and _mentions(text, (parent / "README.md").as_posix()):
                owner = idx
                break
        if owner is not None:
            sub = p.relative_to(owner.parent).as_posix()
            if _mentions(rep.snapshot.read_text(owner), sub):
                continue
            rep.error(owner, None, f"폴더 목록에 {sub} 이(가) 없다")
            continue
        rep.error(mp, None, f"문서 지도에 {rel} 이(가) 파일 단위로 없다 (폴더 이름만으로는 인정 안 함)")
    for no, line in enumerate(text.splitlines(), 1):
        if (mp, no) in rep.pending:
            continue
        for ref in MD_PATH.findall(line):
            if not rep.snapshot.exists(mp.parent / ref) and not rep.snapshot.exists(docs.parent / ref):
                rep.error(mp, no, f"문서 지도가 없는 파일을 가리킨다: {ref}")


def slugify(text: str) -> str:
    """GitHub 방식 제목 anchor: 링크·태그 제거 → 소문자 → 글자·숫자·_·-·공백만 남김 → 공백을 - 로."""
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"[^\w\- ]", "", text.strip().lower())
    return text.replace(" ", "-")


def anchors_of(rep: Report, path: Path) -> set[str]:
    path = Path(os.path.abspath(path))
    if path not in rep.anchors:
        found: set[str] = set()
        counts: dict[str, int] = {}
        raw = rep.snapshot.read_text(path).splitlines()
        for _no, line in strip_code(raw):
            m = HEADING.match(line)
            if m:
                base = slugify(m.group(2))
                n = counts.get(base, 0)
                counts[base] = n + 1
                found.add(base if n == 0 else f"{base}-{n}")
            for hid in HTML_ID.findall(line):
                found.add(hid.lower())
        rep.anchors[path] = found
    return rep.anchors[path]


def check_links_and_secrets(rep: Report, files: list[Path]) -> None:
    for path in files:
        if not isinstance(rep.snapshot, IndexSnapshot) and not path.resolve().is_relative_to(rep.root):
            rep.error(path, None, "프로젝트 밖의 문서 symlink는 검사하지 않는다")
            continue
        raw = rep.snapshot.read_text(path).splitlines()
        for no, line in strip_code(raw):
            if (path, no) in rep.pending:
                continue
            for target in LINK.findall(line):
                if re.match(r"^[a-z][a-z0-9+.\-]*:", target, re.I):
                    continue
                file_part, _, frag = target.partition("#")
                dest = Path(os.path.abspath(path.parent / file_part)) if file_part else path
                if not dest.is_relative_to(rep.root) or (not isinstance(rep.snapshot, IndexSnapshot) and not dest.resolve().is_relative_to(rep.root)):
                    rep.error(path, no, "프로젝트 밖의 로컬 문서 링크는 검사하지 않는다")
                    continue
                if file_part and not rep.snapshot.exists(dest):
                    rep.error(path, no, f"깨진 링크: {target}")
                    continue
                if frag and rep.snapshot.is_file(dest) and dest.suffix.lower() == ".md":
                    if unquote(frag).lower() not in anchors_of(rep, dest):
                        rep.error(path, no, f"없는 제목(anchor)으로 가는 링크: {target}")
        for no, line in enumerate(raw, 1):
            for pat, label in SECRET_PATTERNS:
                if pat.search(line):
                    rep.error(path, no, f"비밀값으로 보이는 문자열({label}) — 문서에서 제거하고 키를 교체할 것")


def check_id_format(rep: Report, files: list[Path]) -> None:
    for path in files:
        for no, line in strip_code(rep.snapshot.read_text(path).splitlines()):
            for bad in BAD_ID.findall(line):
                rep.error(path, no, f"비표준 ID {bad} — R-001 / T-001 / D-001 처럼 숫자 3자리 이상으로")


def git(root: Path, *args: str) -> str | None:
    try:
        r = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, timeout=15,
                           env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"})
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout if r.returncode == 0 else None


def head_commit(root: Path) -> str | None:
    branch = git(root, "symbolic-ref", "-q", "HEAD")
    if branch and branch.strip() not in git_bytes(root, "for-each-ref", "--format=%(refname)").decode().splitlines():
        return None
    return resolve_commit(root, "HEAD")


def resolve_commit(root: Path, ref: str) -> str:
    return git_bytes(root, "rev-parse", "--verify", "--end-of-options", f"{ref}^{{commit}}").decode().strip()


class TaskHistory:
    """STATUS blob만 읽고 같은 blob은 한 번 파싱한다. 커밋별 전체 문서 검사는 하지 않는다."""

    def __init__(self, rep: Report, status: Path):
        self.rep, self.status = rep, status
        self.rel = status.relative_to(rep.root).as_posix()
        self.commits, self.blobs, self.issues, self.validated = {}, {}, {}, set()

    def parse(self, text: str):
        _, _, lines = split_status(text.splitlines())
        tasks, issues = {}, []
        for tid, st, no, _title, body in parse_blocks(lines, TASK_HEAD):
            if tid in tasks or st not in TASK_STATUSES:
                issues.append((no, f"{tid} 중복 또는 잘못된 상태"))
            valid = st in TASK_STATUSES and tid not in tasks
            for field in REQUIRED_FIELDS.get(st, []):
                if not field_value(body, field):
                    issues.append((no, f"{tid} [{st}] 에 '{field}:' 값이 없다"))
                    valid = False
            tasks[tid] = (st, valid)
        for no, line in lines:
            if re.match(r"^###\s+T-\d+", line) and not TASK_HEAD.match(line):
                issues.append((no, "Task 제목 형식 오류"))
        return tasks, issues

    def at(self, commit: str, validate=False):
        if commit not in self.commits:
            entry = git_bytes(self.rep.root, "ls-tree", "-z", commit, "--", self.rel)
            if not entry:
                self.commits[commit] = {}
            else:
                match = re.fullmatch(rb"100(?:644|755) blob ([0-9a-f]{40}|[0-9a-f]{64})\t[^\0]+\0", entry)
                if not match:
                    raise SnapshotError(f"{commit[:12]}: 이력의 STATUS 일반 파일을 읽을 수 없다")
                blob = match[1].decode()
                if blob not in self.blobs:
                    text = git_bytes(self.rep.root, "cat-file", "blob", blob).decode("utf-8")
                    self.blobs[blob], self.issues[blob] = self.parse(text)
                self.commits[commit] = (blob, self.blobs[blob])
        item = self.commits[commit]
        if not item:
            return {}
        blob, tasks = item
        if validate and blob not in self.validated:
            for no, message in self.issues[blob]:
                self.rep.error(self.status, no, f"{commit[:12]}: {message}")
            self.validated.add(blob)
        return tasks

    def transition(self, parents, current, retired, label):
        # merge의 다른 부모 경로에 이미 커밋된 정상 종료가 있으면 정리 근거로 인정한다.
        proof = set(retired)
        for parent in parents:
            proof.update(tid for tid, (st, valid) in parent.items()
                         if valid and st in {"completed", "cancelled", "moved"})
        for tid in sorted(set().union(*(set(p) for p in parents)) - set(current)):
            if tid not in proof:
                self.rep.error(self.status, None, f"{label}: 열린 {tid} 또는 유효한 종료 기록 없는 Task가 사라졌다 — completed/cancelled/moved와 필수 필드를 먼저 커밋할 것")
        return proof - set(current)  # 다시 열린 Task에는 옛 종료 증거를 재사용하지 않는다.


def check_git(rep: Report, root: Path, status: Path, head: str | None, base: str | None) -> None:
    if head is None:
        if base:
            raise SnapshotError("--base 검사에는 HEAD 커밋이 필요하다")
        rep.warn(status, None, "HEAD가 없는 최초 커밋: 현재 index 문서는 검사했고 과거 Task 소실 비교만 생략")
        return
    history = TaskHistory(rep, status)
    if base is not None:
        # 필요한 이력이 있는지 추정하지 않는다. shallow/replace/graft는 지원 범위 밖이다.
        if git_bytes(root, "rev-parse", "--is-shallow-repository").strip() != b"false":
            raise SnapshotError("shallow history로 --base를 판정할 수 없다. 전체 이력을 준비한다")
        graft = Path(os.fsdecode(git_bytes(root, "rev-parse", "--git-path", "info/grafts")).strip())
        if git_bytes(root, "for-each-ref", "--format=%(refname)", "refs/replace").strip() or (graft if graft.is_absolute() else root / graft).exists():
            raise SnapshotError("replace/graft history는 지원하지 않는다")
        base_commit = resolve_commit(root, base)
        if git_bytes(root, "merge-base", base_commit, head).decode().strip() != base_commit:
            raise SnapshotError("--base는 HEAD의 조상이어야 한다")
        graph = git_bytes(root, "rev-list", "--topo-order", "--reverse", "--parents", f"{base_commit}..{head}").decode().splitlines()
        retired = {}
        history.at(base_commit)
        for row in graph:
            commit, *parents = row.split()
            parent_tasks = [history.at(parent) for parent in parents]
            proofs = set().union(*(retired.get(parent, set()) for parent in parents))
            retired[commit] = history.transition(parent_tasks, history.at(commit, validate=True), proofs, commit[:12])
    if isinstance(rep.snapshot, CommitSnapshot):
        return  # --base 단독의 최종 문서도 위 HEAD snapshot으로 검사했다.
    staged, _ = history.parse(rep.snapshot.read_text(status))
    history.transition([history.at(head)], staged, set(), "HEAD → index")


def print_status(root: Path, tasks, hot_lines) -> None:
    print("== 현재 상태 ==")
    branch = git(root, "rev-parse", "--abbrev-ref", "HEAD")
    if branch is None:
        print("Git: 없음 또는 커밋 없음 (Git 도입 권장)")
    else:
        head = (git(root, "log", "-1", "--format=%h %s") or "").strip()
        porcelain = (git(root, "status", "--porcelain") or "").splitlines()
        untracked = sum(1 for l in porcelain if l.startswith("??"))
        changed = len(porcelain) - untracked
        tree = "깨끗함" if not porcelain else f"변경 {changed} · 미추적 {untracked}"
        print(f"Branch: {branch.strip()} · HEAD: {head} · 작업 트리: {tree}")
    for key in ("단계", "현재 Task", "다음", "위험·막힘", "검증 대기", "마지막 갱신"):
        v = hot_value(hot_lines, key)
        if v:
            print(f"{key}: {v[1]}")

    def fmt(states: set[str], limit: int | None = None) -> str:
        items = [f"{t[0]} {t[3]}" for t in tasks if t[1] in states]
        if limit and len(items) > limit:
            items = items[:limit] + [f"…외 {len(items) - limit}"]
        return ", ".join(items) or "없음"

    print(f"진행 중: {fmt({'inProgress'})}")
    print(f"검증 대기: {fmt({'verificationPending'})}")
    print(f"막힘: {fmt({'blocked'})} · 보류: {fmt({'onHold'})}")
    print(f"예정: {fmt({'planned'}, 3)}")
    done = [t[0] for t in tasks if t[1] in {"completed", "cancelled", "moved"}]
    if done:
        print(f"정리 대기(커밋 후 삭제 가능): {', '.join(done)}")
    print()


def run() -> int:
    ap = argparse.ArgumentParser(description="만능프롬프트 문서 점검기 v1.4")
    ap.add_argument("--root", default=".", help="저장소 루트 (기본: 현재 폴더)")
    ap.add_argument("--docs", default="docs", help="문서 폴더 (기본: docs)")
    ap.add_argument("--status", action="store_true", help="현재 개발 상태 요약 출력")
    ap.add_argument("--git", action="store_true", help="고정한 index의 모든 문서 검사 + 기준 커밋 대비 열린 Task 소실 검사")
    ap.add_argument("--base", help="CI: 조상 base 이후 전체 부모 경로의 Task 이력 + HEAD 문서 검사 (--git과 함께 쓰면 최종 문서는 index)")
    ap.add_argument("--strict", action="store_true", help="경고도 실패로 처리")
    a = ap.parse_args()

    root = Path(a.root).resolve()
    docs = Path(os.path.abspath(root / a.docs))
    if not docs.is_relative_to(root) or docs == root or any(part.startswith(".") for part in docs.relative_to(root).parts):
        raise SnapshotError("--docs는 프로젝트 안의 숨김 영역 밖 문서 폴더여야 한다")
    head = head_commit(root) if a.git or a.base is not None else None
    if a.base is not None:
        top = Path(os.fsdecode(git_bytes(root, "rev-parse", "--show-toplevel")).strip()).resolve()
        if top != root or head is None:
            raise SnapshotError("--base는 HEAD가 있는 Git 저장소 루트에서 실행한다")
    snapshot = IndexSnapshot(root) if a.git else CommitSnapshot(root, head) if a.base is not None else WorkingTree(root)
    rep = Report(root, snapshot)
    status = docs / "STATUS.md"
    if not isinstance(snapshot, IndexSnapshot) and docs.resolve() != docs:
        raise SnapshotError("문서 폴더의 symlink는 지원하지 않는다")

    if not snapshot.is_file(status):
        print(f"점검 불가: {a.docs}/STATUS.md 이(가) 없다")
        return 2

    tasks, hot_lines, status_refs = check_status(rep, status)
    if a.status:
        if a.git or a.base is not None:
            print(f"문서 기준: {'index' if a.git else 'HEAD commit'} (아래 Git 작업 트리 표시는 현황 정보)")
        print_status(root, tasks, hot_lines)

    project, decision_files = discover_sources(rep, docs)
    req_ids, dec_ids = check_sources(rep, project, decision_files, status, status_refs)

    check_doc_map(rep, docs)
    for d in ("archive", "legacy"):
        if snapshot.is_dir(docs / d):
            rep.warn(docs / d, None, "archive 폴더 대신 Git 이력을 쓴다. 장기 증거만 docs/evidence/ 로")

    md_files = snapshot.markdown_files(docs)
    for source in ([project] if project else []) + decision_files:
        if snapshot.is_file(source) and source not in md_files:
            md_files.append(source)
    for extra in ("AGENTS.md", "CLAUDE.md", "README.md"):
        p = root / extra
        if snapshot.is_file(p):
            md_files.append(p)
    check_links_and_secrets(rep, md_files)
    check_id_format(rep, [p for p in [status, project] + decision_files if p and snapshot.is_file(p)])

    if a.git or a.base is not None:
        check_git(rep, root, status, head, a.base)

    snapshot.verify()

    for line in rep.errors + rep.warnings:
        print(line)
    n_open = sum(1 for t in tasks if t[1] in OPEN_STATUSES)
    print(f"doccheck: 열린 Task {n_open} · 전체 Task {len(tasks)} · 결정 {len(dec_ids)} · 요구 {len(req_ids)} · 오류 {len(rep.errors)} · 경고 {len(rep.warnings)}")
    if rep.errors or (a.strict and rep.warnings):
        return 1
    return 0


def main() -> int:
    try:
        return run()
    except (SnapshotError, OSError, UnicodeError) as exc:
        print(f"점검 불가: {exc}")
        return 2


if __name__ == "__main__":
    sys.exit(main())
