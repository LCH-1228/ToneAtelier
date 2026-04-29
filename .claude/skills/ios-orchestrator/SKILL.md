---
name: ios-orchestrator
description: ToneAtelier iOS 프로젝트의 모든 작업 진입점. SwiftUI/TCA Feature 추가·수정, 새 API 엔드포인트, 코드 리뷰, 빌드/테스트, 백엔드 정합성 검증 등 iOS 관련 요청을 받으면 반드시 이 스킬을 사용해 supervisor에게 위임. "리뷰만 다시", "빌드만", "이 부분만 수정", "재실행", "보완" 등 부분/후속 요청에도 트리거. ToneAtelier, TCA, SwiftUI, Reducer, Feature, Router, Client, Networking, Make 화면, Home 화면, Feed 화면, Auth, MainTab 같은 키워드 등장 시 진입.
---

# ToneAtelier iOS Orchestrator

ToneAtelier 프로젝트의 모든 iOS 작업 진입점. supervisor 에이전트를 호출해 작업을 분류·분배하고, 사용자 승인 후 적절한 에이전트(implementer/reviewer/tester/qa)에 위임한다.

## Phase 0: 컨텍스트 확인

워크플로우 시작 시 기존 산출물 존재 여부를 확인한다:
- `.claude/_workspace/` 존재 + 사용자가 부분 수정 요청 → **부분 재실행** (해당 에이전트만 재호출)
- `.claude/_workspace/` 존재 + 새 입력 제공 → **새 실행** (기존을 `_workspace_prev/`로 이동)
- 미존재 → **초기 실행**

## Phase 1: 작업 분류 (supervisor 핵심 역할)

사용자 요청을 다음 표로 분류한다:

| 분류 | 신호 | 호출 패턴 |
|------|------|----------|
| **단순 질문** | "이 코드가 뭐야", "왜 이렇게 돼있어", "어디 있어" | 분류 보고 생략. supervisor가 직접 답하거나 implementer에게 즉시 위임 |
| **단일 작업** | "이 Reducer 리뷰만", "지금 빌드만", "이 부분만 수정" | 해당 에이전트 1명 직접 호출 (`Agent` 도구) |
| **연쇄 작업** | "구현 후 리뷰", "수정하고 빌드 검증" | 서브 에이전트를 순차 호출. 전 단계 결과를 다음 단계 입력으로 |
| **풀 워크플로우** | "이 화면 만들어줘", "처음부터 끝까지" | `TeamCreate`로 팀 구성. implementer/qa/reviewer/tester 협업 |

분류가 애매하면 사용자에게 물어본다. 추측 금지.

## Phase 2: 분배 계획 보고 (승인 게이트)

단순 질문이 아닌 모든 요청은 호출 직전에 다음 형식으로 보고:

```
[분류] 단일 / 연쇄 / 풀
[대상] 파일 절대 경로 또는 작업 범위
[호출] 에이전트 이름 (순서)
[중점] 한두 줄로 무엇을 할지
승인하시겠습니까?
```

사용자 승인 후에만 Phase 3으로 진행. 승인 표현 예: "ㅇㅇ", "go", "진행", "ok", "그렇게 해줘".

## Phase 3: 에이전트 호출

### 단일/연쇄: 서브 에이전트 패턴

`Agent` 도구로 호출. 모든 호출에 다음 파라미터 명시:
- `subagent_type`: 에이전트 이름 (예: `implementer`)
- `model`: `"opus"`
- `description`: 5단어 이내 작업 요약
- `prompt`: 자기 완결적 컨텍스트 (대상 파일 경로 + 사용자 원문 + 참조 문서 지시)

연쇄 호출 시 전 단계 결과의 **핵심만** 추출해 다음 단계 프롬프트에 포함. 원문을 그대로 붙여넣지 않는다.

### 풀: 에이전트 팀 패턴

`TeamCreate`로 팀 생성:
- 멤버: implementer, qa, reviewer, tester (필요한 조합)
- `TaskCreate`로 작업 분해 + 의존성 명시
- 팀원이 `SendMessage`로 자체 조율
- 작업 디렉토리: `.claude/_workspace/<날짜>_<요약>/`
- 팀 종료 후 `TeamDelete`로 정리, 산출물은 보존

## Phase 4: 결과 통합 및 사용자 보고

각 에이전트의 반환을 그대로 붙이지 말고 다음 형식으로 압축:

```
[처리 결과]
- 변경 파일: <절대 경로 목록>
- 빌드/테스트: ✅/❌ + 한 줄 요약
- 리뷰 의견: Critical N개 / Major M개 / Minor K개 (있을 때만)
- 정합성 검증: 불일치 N개 (있을 때만)

[잔여 이슈] (있을 때만)
- 사용자 결정 필요 항목

[다음 단계 권장] (선택)
- 빌드/리뷰/QA 추가 호출 권장 여부
```

## 환경 정책 (모든 호출에 전달)

- iOS 시뮬레이터 기본: iPhone 17 / iOS 26.3.1
- 한글 응답
- 커밋 메시지에 `Co-Authored-By` 트레일러 추가 금지
- 동작 확인 없이 커밋 금지
- **`APIInfo.swift` / `Secrets.xcconfig` 읽기/수정/작성 모두 금지**
- 외부 SPM 추가 / UIKit / RxSwift 도입 전 사용자 확인

## 에러 핸들링

- 에이전트 1회 재시도 후 재실패 시 결과 없이 진행, 보고서에 누락 명시
- 빌드 실패 시 코드 직접 수정 금지 — supervisor가 implementer 재호출 제안
- 상충 정보(예: 리뷰와 QA의 의견 충돌) 발생 시 양쪽 출처 병기 후 사용자 결정 요청
- 사용자가 분배 계획에 거부/수정 요청 시 즉시 재계획 후 재승인 요청

## 후속 작업 키워드

다음 표현은 후속 요청으로 인식, Phase 0의 `_workspace/` 비교 모드 활성화:
- "다시", "재실행", "업데이트", "수정", "보완", "개선"
- "방금 그거", "아까 그", "이전 결과"
- "리뷰만 다시", "테스트만 다시"

## 테스트 시나리오

### 정상 흐름 (단일)
입력: "MakeFeature.swift 리뷰해줘"
1. Phase 1 분류 → 단일 (reviewer)
2. Phase 2 보고 → 사용자 승인
3. Phase 3 → `Agent(subagent_type=reviewer, model=opus, prompt=...)`
4. Phase 4 결과 압축 → 사용자에게 Critical/Major/Minor 분류 보고

### 정상 흐름 (풀)
입력: "필터 상세에 댓글 기능 추가해줘"
1. Phase 1 분류 → 풀 워크플로우
2. Phase 2 보고 → "implementer → qa → reviewer → tester 순서로 진행, _workspace 사용" 사용자 승인
3. Phase 3 → `TeamCreate` + `TaskCreate`로 의존성 그래프 생성
4. 팀 자체 조율
5. Phase 4 통합 보고

### 에러 흐름
입력: "이 화면 만들어줘" (어떤 화면인지 모호)
1. Phase 1에서 모호 → 사용자에게 "어떤 화면인지 구체적으로 알려달라" 질문
2. 답변 받기 전까지 Phase 2 진입 안 함
