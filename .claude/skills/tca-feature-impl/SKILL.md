---
name: tca-feature-impl
description: ToneAtelier iOS 프로젝트의 SwiftUI + TCA Feature, Reducer, View, Networking Router/Client, Dependency 구현 가이드. 새 화면 추가, 새 API 엔드포인트, Client 작성, 디자인 시스템 적용 시 implementer 에이전트가 사용. "Feature 만들어줘", "Router 추가해줘", "Reducer 작성해줘", "Client 추가해줘", "이 화면 구현해줘", "API 붙여줘" 등 구현 키워드 등장 시 트리거.
---

# TCA Feature Implementation Guide

ToneAtelier의 SwiftUI + TCA 코드 작성 패턴을 정의한다. implementer가 1차 참조한다.

## 0. 진입 시 필수 확인

1. `HarnesDocs/Essentials.md` 가장 먼저 — 화면 트리, 인증/세션 플로우, 표준 흐름
2. `AGENTS.md` — 디렉토리 역할, 작업 규칙
3. 가장 비슷한 기존 Feature를 모방 (Home/Feed/Make 중 가까운 도메인)
4. 변경 범위가 크면 사용자에게 변경 계획 먼저 보고 (글로벌 CLAUDE.md 기본사항 1번)

## 1. 디렉토리 배치

```
Features/
├── Auth/
│   └── Login/Components/
├── MainTab/
└── Tabs/<TabName>/
    ├── <TabName>Feature.swift
    ├── <TabName>View.swift
    ├── Components/        ← 화면 전용 하위 UI
    └── Detail/
        ├── <TabName>DetailFeature.swift
        └── <TabName>DetailView.swift
```

화면 단위는 `<FeatureName>Feature.swift` + `<FeatureName>View.swift` 쌍을 기본으로. 여러 Feature 재사용 UI만 `Shared/Components`로 이동.

## 2. Reducer 패턴

```swift
@Reducer
struct FooFeature {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    var child: ChildFeature.State?
    // 입력/표시 필드
  }

  enum Action: BindableAction, Sendable {        // 입력 있으면 BindableAction
    case binding(BindingAction<State>)
    case task
    case alert(PresentationAction<Alert>)
    case child(ChildFeature.Action)
    case childDismissed
    case delegate(Delegate)

    enum Alert: Equatable, Sendable {}
    enum Delegate: Equatable, Sendable { case fooHappened(...) }
  }

  @Dependency(\.fooClient) private var fooClient

  var body: some Reducer<State, Action> {
    Scope(state: \.someChild, action: \.someChild) { SomeChildFeature() }   // child 먼저
    BindingReducer()
    Reduce { state, action in ... }
      .ifLet(\.$alert, action: \.alert)
      .ifLet(\.child, action: \.child) { ChildFeature() }
  }
}
```

**핵심 규칙:**
- 부모 ↔ 자식 통신은 **`delegate` enum 한정** (자식이 부모 State에 접근 금지)
- 비동기 effect: `.run { send in ... }` + `.cancellable(id: "FooFeature.task", cancelInFlight: true)`
- `Scope`는 `BindingReducer` **앞에**
- 표준 child 분기:
  ```swift
  case .child(.delegate(.somethingHappened(...))):
    // 부모 state 동기화
    return .none
  case .child:
    return .none
  case .childDismissed:
    state.child = nil
    return .none
  ```

## 3. View 패턴

```swift
struct FooView: View {
  @Bindable var store: StoreOf<FooFeature>

  var body: some View {
    content
      .navigationDestination(
        isPresented: $store.isChildPresented.sending(\.childDismissed)
      ) { ... }
      .alert($store.scope(state: \.alert, action: \.alert))
      .task { await store.send(.task).finish() }
  }
}
```

**핵심 규칙:**
- View는 State 표시 + Action 송출만. 직접 API 호출 금지
- child 진입은 `.navigationDestination(isPresented:)` 또는 `.ifLet`
- dismiss는 binding setter에서 명시적 액션 송출
- 다크 테마: `.preferredColorScheme(.dark)` 또는 `HomeTheme.background`

## 4. Networking — 새 API 엔드포인트

순서:
1. `APIInfo.Path`에 경로 상수 추가가 필요하면 **사용자에게 요청** (직접 수정 금지)
2. `Networking/Routers/<Domain>Router.swift`에 case 추가
3. `Dependencies/<Domain>Client.swift`에 `@Sendable` 클로저 + Request/Response 모델 추가
4. `liveValue`와 `testValue` 동기 작성
5. (선택) `Debug/APIRouterTestViews.swift`에 테스트 액션 추가

### Router

```swift
enum FooRouter: APIRouter {
  case bar(BarRequest)

  var method: HTTPMethod      { ... }
  var path: String            { APIInfo.Path.fooBar }
  var queryItems: [URLQueryItem] { [] }
  var body: HTTPBody { get throws { try .jsonBody(request) } }
  var requiresAccessToken: Bool { true }
}
```

- 인증 도메인 전체가 보호되면 단일값 `true`. 일부만 미보호면 case별 분기
- multipart fieldName: 일반 파일 `files`, 프로필 이미지 `profile`

### Client

```swift
struct FooClient {
  var bar: @Sendable (_ request: BarRequest) async throws -> BarResponse
}

extension FooClient: DependencyKey {
  static var liveValue: FooClient {
    @Dependency(\.httpClient) var httpClient
    return FooClient(
      bar: { request in
        try await httpClient.send(APIEndpoint<BarResponse>(router: FooRouter.bar(request)))
      }
    )
  }

  static let testValue = FooClient(
    bar: { _ in throw APIError.transport("FooClient.bar testValue") }
  )
}

extension DependencyValues {
  var fooClient: FooClient {
    get { self[FooClient.self] }
    set { self[FooClient.self] = newValue }
  }
}
```

**핵심 규칙:**
- 모든 메서드는 `@Sendable async throws`
- `liveValue`는 `httpClient.send(...)` 1줄. 별도 retry/loading 처리 금지
- `testValue`는 모든 메서드 throw (미주입 즉시 감지)
- 합성 client(Feed/Home/HomeDetail)는 다른 client 여러 개를 `async let`으로 병렬 호출 + fileprivate parser

## 5. 응답 모델 선택

| 상황 | 사용 |
|------|------|
| 빈 응답 | `EmptyResponse` |
| 메시지만 | `MessageResponse` |
| Like 토글 | `LikeStatusResponse` |
| 업로드 | `UploadedFilesResponse` |
| 토큰 갱신 | `TokenRefreshResponse` |
| 인증 후 사용자 | `AuthenticatedUserResponse` |
| 스키마 유동 | `JSONValue` + fileprivate parser |
| 고정 응답 | 도메인 Client 또는 `CommonResponses.swift`에 `Decodable struct` |

**JSON 키 컨벤션:**
- `JSONDecoder.api`는 default strategy (변환 없음)
- snake_case 응답이면 모델 필드도 snake_case
- 혼재 응답은 `firstString(for: ["snake_case", "camelCase", ...])`

## 6. 메모리 / Swift Concurrency

상세 원칙은 `references/memory-concurrency.md` 참조.

핵심:
- `.run { ... }` 안에서 dependency는 미리 추출
- `@Presents` + `.ifLet` 패턴 준수
- 임시 파일 생성 시 cleanup 지점도 같이 추가
- 새 화면 추가 시 `print("Deinit: \(Self.self)")` 임시 검증
- Task/AsyncStream에는 종료/cancel 경로 명시

## 7. 디자인 시스템

| 자원 | 사용 |
|------|------|
| 자산 | `AppAsset.<scope>.<name>` 만 (raw string 금지) |
| 색상 | `HomeTheme.*` 또는 `Color(hex: 0xRRGGBB, opacity:)`. **UIColor 금지** |
| 폰트 | `HomeTheme.pretendard(size:weight:)` / `HomeTheme.mulgyeol(size:weight:)` |
| 다크 테마 | 기본. `HomeTheme.background` |
| 탭 바 회피 | `MainTabBarView.Layout.contentInsetHeight` (절대값 금지) |
| 공유 컴포넌트 | `Shared/Components/*` — `HomeTheme`/`AppAsset`만 의존 |

## 8. 표준 흐름 (재사용 패턴)

상세는 `references/standard-flows.md` 참조.

- Optimistic Like + Snapshot Rollback (HomeDetail/Feed)
- 페이지네이션 (Feed) — 종료 신호 `nextCursor == "0"`
- Error → 사용자 메시지 (`userFacingMessage` 확장)
- CancellationError 정책 (silent)

## 9. 절대 금지

- `APIInfo.swift` / `Secrets.xcconfig` 읽기·쓰기·수정
- View에서 URLSession 직접 호출
- Reducer가 다른 Feature의 State에 직접 접근
- 자식이 부모 State에 직접 접근 (delegate 우회)
- raw asset name / `UIColor` / 절대값 hard-code
- 사용자 사전 확인 없이 외부 SPM 추가, UIKit/RxSwift 도입

## 10. 새 코드 추가 절차 요약

| 작업 | 순서 |
|------|------|
| 새 API 엔드포인트 | 1. 사용자에게 `APIInfo.Path` 추가 요청 → 2. Router case → 3. Client 클로저 + 모델 → 4. testValue 동기 |
| 새 Client | 패턴 복사 → `DependencyValues` 키패스 등록 |
| 새 화면 | 가장 비슷한 기존 Feature 모방 → Reducer → 부모 컨테이너에 Scope 추가 → View → 부모는 navigationDestination 또는 child State + ifLet |
| 새 자산 | Asset Catalog 추가 → `AppAsset.<scope>` 상수 등록 |
