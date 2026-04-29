# ToneAtelier — Claude Code 지침

이 파일은 Claude Code가 ToneAtelier 프로젝트에서 작업할 때 사용하는 지침이다.

## 프로젝트 컨벤션 / 아키텍처

- **디렉토리 역할 / 작업 규칙 / 네이밍:** `AGENTS.md` 참조
- **아키텍처 / 패턴 / 흐름 / 컨벤션 요약:** `HarnesDocs/Essentials.md` (먼저 읽을 핵심 요약)
- **분과 문서 인덱스:** `HarnesDocs/00_Overview.md`

## 하네스

**목표:** SwiftUI + TCA 기반 iOS 작업을 supervisor가 분류·분배해 implementer/reviewer/tester/qa에게 위임하는 5인 체제.

**트리거:** iOS 관련 작업(Feature 추가/수정, 새 API 엔드포인트, 코드 리뷰, 빌드/테스트, 백엔드 정합성 검증 등) 요청 시 `ios-orchestrator` 스킬을 사용한다. 단순 정보 질문은 직접 응답 가능.

**동작 모델:** supervisor가 매 요청을 단일/연쇄/풀 워크플로우로 분류하고, 분배 계획을 사용자에게 보고해 승인받은 뒤 실행한다 (확인형).

**구성:**
- `.claude/agents/` — supervisor, implementer, reviewer, tester, qa
- `.claude/skills/` — ios-orchestrator, tca-feature-impl, ios-code-review, ios-build-test

## 환경 정책

- iOS 시뮬레이터 기본: iPhone 17 / iOS 26.3.1
- 한글 응답
- 커밋 메시지 한글 본문, `Co-Authored-By` 트레일러 추가 금지
- 사용자 동작 확인 없이 커밋 금지
- **`APIInfo.swift` / `Secrets.xcconfig` 읽기·수정·작성 모두 금지** — 키 값이 필요하면 사용자에게 요청
- 외부 SPM 추가 / UIKit / RxSwift 도입 전 사용자 사전 확인

## 변경 이력

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-04-29 | 초기 구성 (5인 하네스 + 4개 스킬) | 전체 | iOS 개발 작업 자동화 진입점 마련 |
