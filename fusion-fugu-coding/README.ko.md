# fusion-fugu-coding

[![Release](https://img.shields.io/github/v/release/jeongsk/fusion-fugu-coding?sort=semver&display_name=tag)](https://github.com/jeongsk/fusion-fugu-coding/releases)
[![Install](https://img.shields.io/badge/install-claude%20--plugin--dir-2ea44f)](#2-설치)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-7c3aed?logo=anthropic&logoColor=white)](https://docs.claude.com/en/docs/claude-code/plugins)
[![License: MIT](https://img.shields.io/github/license/jeongsk/fusion-fugu-coding)](LICENSE)

[English](README.md) | **한국어**

Claude Code 위에서 동작하는 플러그인으로, **다중 리뷰어 코드 리뷰 위원회**(Fusion-lite)와
**통제된 계획 → 수정 → 검증 오케스트레이션**(Fugu-lite)을 추가합니다. 실행 런타임은 여전히
Claude Code이며, 이 플러그인은 반복 가능한 오케스트레이션과 전문화된 리뷰 관점, 그리고 안전
가드레일을 제공합니다.

- **Fusion-lite** — 여러 전문 리뷰어(버그, 테스트, 보안, 아키텍처)가 같은 diff를 검토한 뒤,
  심판(judge)이 그 결과를 하나의 구조화된 결정으로 통합합니다. OpenRouter Fusion(패널 + 심판
  종합)에서 영감을 받았습니다.
- **Fugu-lite** — Thinker / Worker / Verifier 역할과 횟수 제한이 있는 수리 루프를
  skills + subagents + hooks로 구성합니다. Sakana AI Fugu / TRINITY / Conductor에서 영감을
  받았습니다. 실제 모델을 학습시키지는 **않으며**, 프롬프트로 역할을 근사합니다.

---

## 1. 이 플러그인이 하는 일

| 명령어 | 역할 | 설명 |
|--------|------|------|
| `/fusion-fugu-coding:fusion-review` | 리뷰 위원회 | 현재 git diff / ref 범위 / 파일에 대한 다중 에이전트 리뷰. 구조화된 결정 JSON과 사람용 요약을 반환합니다. |
| `/fusion-fugu-coding:fugu-plan` | Thinker | 코드를 수정하기 전에 작업을 계획: 분류, 파일, 단계, 테스트, 위험, 롤백, 검증 명령, 바로 쓸 수 있는 worker 프롬프트. **수정 안 함.** |
| `/fusion-fugu-coding:fugu-fix` | Worker + 루프 | 통제된 `계획 → 구현 → 검증 → fusion 리뷰 → 수리` 루프(최대 2회 수리). 최소한의 수정, 커밋/푸시 안 함. |
| `/fusion-fugu-coding:fugu-verify` | Verifier | 현재 변경을 검증: 감지된 검사 실행, diff 시크릿 스캔, Fusion 리뷰 후 결정 반환. 요청하지 않는 한 **수정 안 함.** |

> **명령어 이름은 플러그인 네임스페이스가 붙습니다.** Claude Code 안에서는
> `/fusion-fugu-coding:fusion-review` 처럼 표시됩니다(원래 계획서의 짧은 표기 `/fusion-review`와
> 같은 명령). `/`를 입력하고 `fusion` 또는 `fugu`를 치면 찾을 수 있습니다.

함께 제공되는 것:

- `agents/`의 **서브에이전트 7개** — `bug-reviewer`, `test-reviewer`, `security-reviewer`,
  `architecture-reviewer`, `fusion-judge`, `fugu-thinker`, `fugu-verifier`.
- `hooks/`의 **안전 훅** — 민감 파일 읽기 차단, 위험한 셸 명령 확인 요구, 편집 후 diff 로깅,
  선택적 비동기 typecheck.
- `scripts/`의 **결정적 헬퍼 스크립트** — diff 수집, 프로젝트 감지, 베스트에포트 검사,
  시크릿 스캔, diff 요약.

---

## 2. 설치

이 플러그인은 **[jeongsk/fusion-fugu-coding](https://github.com/jeongsk/fusion-fugu-coding)**에
배포되어 있습니다. 저장소 루트 자체가 플러그인 마켓플레이스(`.claude-plugin/marketplace.json`)
이므로 GitHub에서 바로 설치할 수 있습니다.

### 방법 A — GitHub에서 설치 (권장)

Claude Code에서 마켓플레이스를 추가하고 설치합니다:

```
/plugin marketplace add jeongsk/fusion-fugu-coding
/plugin install fusion-fugu-coding@fusion-fugu-marketplace
```

`/plugin marketplace add`는 `owner/repo` GitHub 약식 표기(또는 전체
`https://github.com/jeongsk/fusion-fugu-coding.git` URL)를 받습니다. 이후 `/plugin`에서
관리(활성화 / 비활성화 / 제거)할 수 있고, 새 릴리스는 다음으로 가져옵니다:

```
/plugin marketplace update fusion-fugu-marketplace
```

### 방법 B — 로컬 개발용 클론

`--plugin-dir`을 클론한 저장소 **안의** 플러그인 폴더로 지정합니다:

```bash
git clone https://github.com/jeongsk/fusion-fugu-coding.git
claude --plugin-dir fusion-fugu-coding/fusion-fugu-coding
```

플러그인 파일을 수정한 뒤에는 Claude Code를 재시작하지 않고 다시 로드합니다:

```
/reload-plugins
```

### 로드 확인

`/`를 입력하면 `fusion-fugu-coding:fusion-review`, `…:fugu-plan`, `…:fugu-fix`,
`…:fugu-verify`가 보여야 합니다. 훅은 자동으로 등록됩니다.

요구 사항: `git`, 그리고 스크립트/훅을 위한 `python3` 및/또는 `jq`(둘 다 우아한 폴백과 함께
사용). Node 프로젝트라면 verifier는 기존 `package.json` 스크립트와 락파일이 가리키는 패키지
매니저를 사용합니다.

---

## 3. 명령어

### `/fusion-fugu-coding:fusion-review [target]`
다중 에이전트 리뷰. `target`은 비어 있거나(현재 작업 트리 diff), 파일 경로, git ref/범위
(`main..HEAD`, 브랜치, SHA), 또는 diff를 평가할 자유 텍스트 의도일 수 있습니다. 네 명의
리뷰어를(서브에이전트가 가능하면 병렬로) 생성한 뒤 심판을 실행합니다. 출력:

```json
{
  "decision": "approve | request_changes | needs_human_review",
  "severity": "none | low | medium | high | critical",
  "summary": "…",
  "issues": [
    { "title": "…", "severity": "…", "file": "…", "evidence": "…",
      "suggested_fix": "…", "reviewer": "bug | test | security | architecture" }
  ],
  "confidence": "low | medium | high",
  "follow_up_commands": ["…"]
}
```
이어서 *무엇이 바뀌었는지 / 머지해도 되는지 / 먼저 고칠 것* 짧은 요약이 따라옵니다.

### `/fusion-fugu-coding:fugu-plan "<task>"`
`Fugu-lite Plan`(목표, 분류, 관련 파일, 제약, 구현 단계, 테스트 전략, 위험 체크리스트, 검증
명령, **Suggested Worker Prompt**)을 생성합니다. 파일을 수정하지 않습니다.

### `/fusion-fugu-coding:fugu-fix "<task>"`
통제된 루프를 실행하고 `Fugu-lite Fix Result`(요약, 변경된 파일, 실행한 검사, fusion 결정,
남은 위험, 다음 단계)를 출력합니다. 최소한의 수정, 제한된 수리(≤2회), 커밋/푸시 안 함.

### `/fusion-fugu-coding:fugu-verify [scope]`
상태/diff 검사, 패키지 매니저와 스크립트 감지, 사용 가능한 검사 실행, diff 시크릿 스캔,
Fusion 리뷰 후 결정을 반환합니다. 수정하지 않습니다.

---

## 4. 예시 워크플로

**머지 전 리뷰**
```
/fusion-fugu-coding:fusion-review
# 또는 브랜치를 main과 비교해 리뷰:
/fusion-fugu-coding:fusion-review main..HEAD
```

**계획 후 가드레일과 함께 수정 구현**
```
/fusion-fugu-coding:fugu-plan "만료된 세션을 위한 refresh token 재시도 추가"
/fusion-fugu-coding:fugu-fix  "로그인 토큰 갱신 버그를 최소 변경으로 수정"
/fusion-fugu-coding:fugu-verify
```

**현재 변경만 검증**
```
/fusion-fugu-coding:fugu-verify
```

---

## 5. 안전 규칙 (강제 또는 지시)

1. **자동 머지/푸시/커밋 없음.** 커밋은 요청할 때만 일어납니다.
2. **시크릿 파일 접근 금지.** `PreToolUse` 훅이 `.env*`, `*.pem`, `*.key`,
   `id_rsa`/`id_ed25519`, `secrets/**`, `config/credentials.*`, `*.p12`/`*.pfx`,
   `.ssh/**`, `.aws/credentials`의 읽기/편집을 거부합니다. 시크릿 값은 절대 출력되지 않습니다.
3. **파괴적 셸 명령은 확인 필요.** `PreToolUse` 훅이 `rm -rf`, `sudo`, `chmod 777`,
   `curl|wget | sh`, `git push --force`, `git reset --hard`, `git clean -f`,
   `docker prune`, `kill -9`, `mkfs`, `dd of=/dev/…`, 포크 폭탄에 대해 `ask`를 반환합니다.
4. **Diff 기반 리뷰**를 선호하며, 변경은 최소·범위 내로 유지합니다.
5. **제한된 수리 루프** — `/fugu-fix`는 최대 2회 수리 후 사용자에게 넘깁니다.
6. **추측보다 증거** — 리뷰어는 근거 있고 실행 가능한 이슈만 보고하며, 증거가 약하면
   `needs_human_review`로 표시합니다.

이 가드레일은 Claude Code 자체 권한 시스템 위의 심층 방어이며, 에이전트가 무엇을 하는지 직접
검토하는 것을 대체하지 않습니다.

---

## 6. 알려진 한계

- **샌드박스가 아닌 휴리스틱.** bash 훅은 패턴 매칭을 사용하므로 충분히 난독화된 명령은 회피할
  수 있습니다. Claude Code의 권한 프롬프트를 켜 두세요.
- **시크릿 스캔은 정규식 기반.** 일반적인 토큰 형태와 키 블록은 잡지만, 새롭거나 독자적인
  형식은 놓칠 수 있고 고엔트로피 문자열에서 오탐이 날 수 있습니다.
- **리뷰 품질은 diff와 모델에 의존.** 매우 큰 diff는 요약 후 점진적으로 리뷰하며, 커버리지는
  명시되지만 보장되지는 않습니다.
- **명령어 이름은 네임스페이스가 붙음**(`/fusion-fugu-coding:…`), 단순 `/fusion-review`가 아님.
- **Node 중심 검사.** `detect-project.sh` / `run-checks.sh`는 npm/pnpm/yarn/bun +
  `package.json` 스크립트를 이해합니다. 다른 생태계는 해당 검사를 수동으로 실행(또는 스크립트
  확장)하세요.
- **서브에이전트가 일부 환경에서 불가능**할 수 있으며, 그럴 때 skills는 네 관점을 순차적으로
  시뮬레이션하는 방식으로 폴백합니다.
- **선택적 자동 typecheck 훅은 기본적으로 꺼져 있음**(`FUSION_FUGU_AUTOCHECK=1`로 활성화).
  전체 테스트 스위트는 절대 실행하지 않습니다.

---

## 7. 권장 사용법

- 사소하지 않은 작업은 **`/fugu-plan` 먼저** 사용하고, 그 *Suggested Worker Prompt*를
  `/fugu-fix`에 붙여넣으세요(작고 범위가 명확한 수정은 `/fugu-fix`를 바로 실행).
- **`/fusion-review`**를 커밋 전 / PR 전 게이트로 사용하세요. `request_changes`와
  `needs_human_review`는 멈춤 신호로 취급합니다.
- 커밋 직전에 **`/fugu-verify`**를 실행해, 실패가 *이번* 변경 때문인지 기존 문제인지
  구분하세요.
- 커밋은 **당신**의 손에 두세요 — 플러그인은 대신 하지 않습니다.

---

## 8. 구조

```
fusion-fugu-coding/
  .claude-plugin/plugin.json      # 매니페스트
  README.md
  skills/
    fusion-review/ SKILL.md  rubrics/{bug,test,security,architecture,judge}.md  examples/review-output.json
    fugu-plan/     SKILL.md  templates/execution-plan.md
    fugu-fix/      SKILL.md  templates/repair-instruction.md
    fugu-verify/   SKILL.md  rubrics/verification-rubric.md
  agents/ bug-reviewer.md test-reviewer.md security-reviewer.md architecture-reviewer.md
          fusion-judge.md fugu-thinker.md fugu-verifier.md
  hooks/  hooks.json
          prevent-secret-read.sh block-dangerous-bash.sh
          collect-diff-after-edit.sh run-checks-after-change.sh
  scripts/ get-diff.sh detect-project.sh run-checks.sh secret-scan.sh summarize-diff.sh
```

## 9. 설계 매핑

- **OpenRouter Fusion → Fusion-lite**: 패널 리뷰어 + 심판 종합; 합의/모순/사각지대 해소;
  하나의 구조화된 최종 답.
- **Sakana Fugu / TRINITY / Conductor → Fugu-lite**: Thinker / Worker / Verifier 역할,
  작업 분해, 제한된 수리 루프, worker 프롬프트 생성.
- **Claude Code 프리미티브**: skills(슬래시 명령 워크플로), subagents(리뷰어),
  hooks(안전/생명주기), scripts(결정적 검사).

이 플러그인은 의도적으로 로컬·실용적·Claude Code 네이티브합니다. 웹 앱, LLM 게이트웨이,
모델 학습, 외부 Fusion/Fugu API를 추가하지 않습니다.
