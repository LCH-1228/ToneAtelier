---
name: ios-build-test
description: ToneAtelier iOS 빌드/테스트 자동 검증. tester 에이전트가 시뮬레이터 빌드·실행, Swift Testing 작성·실행, 로그 캡처, UI 자동화에 사용. "빌드해줘", "테스트해줘", "시뮬레이터 띄워줘", "동작 확인", "회귀 검사" 같은 검증 요청 시 트리거. iPhone 17 / iOS 26.3.1을 기본 시뮬레이터로 사용하며 XcodeBuildMCP 도구를 자동 실행한다.
---

# iOS Build/Test Skill

ToneAtelier 빌드 가능성과 동작 정합성을 검증한다. **자동 빌드 권한이 있다.**

## 0. 환경 기본값

- **프로젝트:** `/Volumes/MyData/xcode/SeSAC/LSLP/ToneAtelier/ToneAtelier.xcodeproj`
- **스킴:** `ToneAtelier`
- **시뮬레이터:** iPhone 17 / iOS 26.3.1 (사용자 메모리 기록)
- **테스트 프레임워크:** Swift Testing (`@Test`, `#expect`, `#require`)
- **TCA 테스트:** `TestStore` 사용

## 1. 첫 호출 시 절차

세션 내 첫 빌드/실행/테스트 호출 전:

1. `mcp__XcodeBuildMCP__session_show_defaults` 호출해 현재 설정 확인
2. 미설정 시 `mcp__XcodeBuildMCP__session_set_defaults`로 위 환경 기본값 입력
3. 시뮬레이터 가용성 확인 필요 시 `mcp__XcodeBuildMCP__list_sims`

## 2. 빌드 검증

### 일반 빌드
- `mcp__XcodeBuildMCP__build_sim` (빌드만)
- `mcp__XcodeBuildMCP__build_run_sim` (빌드 + 실행, 일반적으로 권장)

### 실패 시 분석
1. 에러 메시지에서 파일/라인 추출
2. 변경된 파일과 충돌 지점 매칭
3. 추정 원인 + 수정 방향을 supervisor에게 보고
4. **코드 직접 수정 금지** — implementer 재호출 권장

### 성공 시 보고
- 빌드 시간
- 경고(warning) 개수 — **신규 경고**가 있다면 원문과 위치 명시

## 3. 실행 검증

### 시뮬레이터 실행
- `build_run_sim`으로 자동 설치·실행
- 별도 설치/실행이 필요하면 `install_app_sim` → `launch_app_sim`

### 화면 캡처
- `mcp__XcodeBuildMCP__screenshot` — 단순 캡처
- `mcp__XcodeBuildMCP__snapshot_ui` — 좌표 + 뷰 계층 포함

### UI 자동화 (필요 시)
- `tap`, `swipe`, `type_text`, `press_button` 등으로 시나리오 실행
- 사용자가 특정 화면 진입 검증을 요청한 경우에만 사용 (남용 금지)

### 로그 캡처
- 시작: `mcp__XcodeBuildMCP__start_sim_log_cap`
- 종료: `mcp__XcodeBuildMCP__stop_sim_log_cap`
- 시나리오 실행 후 stop으로 출력 수거

## 4. Swift Testing 작성

### 위치
- `ToneAtelierTests/<Feature 경로 미러>/...`
- 예: `Features/Tabs/Make/MakeFeature.swift` 테스트 → `ToneAtelierTests/Tabs/Make/MakeFeatureTests.swift`

### 패턴
```swift
import Testing
import ComposableArchitecture
@testable import ToneAtelier

@Suite("MakeFeature")
struct MakeFeatureTests {
  @Test
  func 사진_등록_시_상태_갱신() async {
    let store = TestStore(initialState: MakeFeature.State()) {
      MakeFeature()
    } withDependencies: {
      $0.fooClient.bar = { _ in .stub }
    }

    await store.send(.photoRegistered(.stub)) {
      $0.registeredPhoto = .stub
    }
  }
}
```

### TCA TestStore 핵심
- 모든 State 변경을 `await store.send(action) { $0.field = ... }`로 명시
- Effect 결과는 `await store.receive(\.action) { ... }`
- 미주입 dependency는 `testValue`의 throw로 즉시 발견 → 테스트마다 명시 주입

### 자세한 패턴
필요 시 `swift-testing-pro` 스킬 호출.

## 5. 테스트 실행

- 전체: `mcp__XcodeBuildMCP__test_sim`
- 특정 클래스/메서드 한정 옵션 활용

### 실패 분석
- 실패 케이스 이름 + 메시지 + 추정 원인 보고
- TestStore 실패면 State diff 확인
- Stub 미주입이면 `testValue throw` 메시지 출력 → 해당 dependency 주입 추가 권장

## 6. 출력 형식

```
[빌드] ✅ 성공 / ❌ 실패
- 시간: 12.3s
- 경고: 0개 (또는 신규 경고 목록)

[실행] ✅ 시뮬레이터 실행 완료 / ❌ 충돌
- 화면: 첫 진입 화면 명
- 캡처: /tmp/... (있을 때만)

[테스트] ✅ N/N 통과 / ❌ M 실패
- 실패 케이스: 이름 + 메시지

[실패 분석] (있을 때만)
- 파일:라인 — 원인 추정 + 수정 방향 (직접 수정 금지)
```

## 7. 디버그 도구 활용

ToneAtelier에는 `Debug/APIRouterTestViews.swift`에 in-app API tester가 있음. UI 시나리오 테스트가 어려운 API 검증에 활용 가능. 진입점은 미연결 상태이므로 임시 NavigationLink 또는 long-press 트리거 필요.

## 8. 협업

- 빌드 실패 원인이 명확한 코드 수정 → supervisor에게 implementer 재호출 권장
- 테스트 통과 후 리뷰 → supervisor에게 reviewer 호출 권장
- API 응답 디코딩 실패 의심 → supervisor에게 qa 호출 권장

## 9. 금지 사항

- 프로덕션 코드 직접 수정 금지 (테스트 코드 작성은 가능)
- `APIInfo.swift` / `Secrets.xcconfig` 접근 금지
- 사용자 동의 없이 git 작업 금지
- `xcodebuild clean` 자동 실행 금지 (캐시 보존)
- 사용자 동작 확인 없이 커밋 금지

## 10. 후속 작업

이전 빌드 결과(_workspace/)가 있으면 어떤 변경 후 재검증인지 비교. 회귀(regression)가 보이면 명시적으로 강조해 supervisor에게 보고.
