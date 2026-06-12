# ToneAtelier

- iOS 앱 (SwiftUI + The Composable Architecture).
- 사진/필터/게시글 공유 + 1:1 채팅 + 인앱결제.

## 1. 빌드/실행

- Xcode 프로젝트: `ToneAtelier.xcodeproj` (단일 타깃 + Tests/UITests)
- 빌드 설정: `Configs/App.xcconfig` (커밋되는 기본값) + `Configs/Secrets.xcconfig` (gitignore)
  - `Secrets.xcconfig.example`을 복사해 `Secrets.xcconfig` 생성 후 키 채울 것
  - `KAKAO_NATIVE_APP_KEY`, `IAMPORT_USER_CODE` 두 키
- `ToneAtelier/APIInfo.swift` 와 `ToneAtelier/GoogleService-Info.plist` 는 git 비추적, 절대 grep/find/Bash 결과·응답 텍스트에 노출 금지

## 2. 디렉터리

```
ToneAtelier/
  App/Root/             앱 진입점 (AppRootFeature/View, KakaoSDKConfiguration, AppURLScheme)
  Features/             화면 모듈 — 모두 TCA Reducer
    Auth/{Login,Join}/
    MainTab/            루트 탭 컨테이너 (MainTab enum + Feature/View + Components)
    Tabs/{Home,Feed,Post,Chat,Profile,Make}/
  Shared/               화면 간 공용
    DesignSystem/       AppTheme, AppAsset
    Components/         화면 간 공용 UI — 분류 기준 미정 (추후 탭 단위 / 탭 간 공통 분리 예정)
    Extensions/         Foundation/SwiftUI 확장
  Networking/
    HTTPClient.swift    단일 진입점 (send + token refresh + session invalidation)
    URLRequestBuilder.swift
    Routers/            APIRouter enum (도메인별)
    Models/             DTO 외 네트워킹 공용 타입 자리 (APIError, HTTPTypes, JSONValue, CommonResponses, ChatModels, APIConfiguration) — 일부 정리 예정
    Models/DTO/{도메인}/ XxxRequestDTO, XxxResponseDTO
    Support/            Logger+App, URLQueryItem+Helpers
  Dependencies/         TCA Dependency Client (XxxClient.swift)
  Debug/                디버그 메뉴 (SwiftLint 제외) — 별도 scheme 없음, 진입/노출은 `#if DEBUG` 가드로 Release 차단
ToneAtelierTests/, ToneAtelierUITests/
```

## 3. 신규 화면 추가

Feature 폴더 1개 = 화면 1개 단위. 모두 동일 골격을 따른다.

```
Features/Tabs/Foo/
  FooFeature.swift     @Reducer + State/Action/body
  FooView.swift        struct FooView: View { @Bindable var store: StoreOf<FooFeature> }
  FooModels.swift      enum/struct (PostCategory, FooListOrder 같은 화면 전용 타입)
  Components/          FooXxxRow, FooXxxBanner 등 화면 전용 SwiftUI 뷰
```

자식 화면 (Detail/Write/Search 등)은 부모 폴더 안에 같은 골격으로 중첩한다 (예: `Post/Detail/PostDetailFeature.swift`). Components 외 다른 자식 폴더는 모두 sub-feature로 간주.

### State/Action 컨벤션

- `@ObservableState struct State: Equatable` — 자식 화면은 optional (`var detail: FooDetailFeature.State?`)
- `enum Action: BindableAction, Sendable` — `case binding(BindingAction<State>)`, `case task`, 자식 dismiss는 `case xxxDismissed`, 부모 통신은 `case delegate(Delegate)` + nested `enum Delegate: Equatable, Sendable {}`
- 응답은 `case xxxResponse(Result<DTO, Error>)`
- 의존성은 reducer 상단에서 `@Dependency(\.fooClient) private var fooClient`
- `body: some Reducer<State, Action>` 안에서 **자식 Scope → BindingReducer → Reduce** 순으로 정렬. 해당 단계가 없으면 그 줄만 생략하고 나머지 순서는 유지

### 네비게이션

- 1단 push: optional child state + `navigationDestination(isPresented:)` + `presented(_:dismiss:)` 헬퍼 (PostView 참고)
- 모달/풀스크린: `fullScreenCover(isPresented:)` (Write/Search 등 신규 작성 흐름)
- Alert: `@Presents var xxxConfirmation: AlertState<Action.Alert>?` + `.ifLet(\.$xxx, action: \.alert)`
- 자식 화면은 **진입 트리거가 있는 가장 가까운 부모**가 sub-feature로 보유. 같은 화면 타입을 여러 트리에서 사용하면 각 부모가 독립 인스턴스로 보유 (예: `UserPostsFeature` 를 Profile / Post / PostDetail 각각에서)

### 신규 화면 작업 흐름 (sub-branch)

`feat/<screen>-screen` → screen UI/State 작성 → 같은 부모에서 `feat/<screen>-interaction` 분기 → interaction 구현 + **부모 화면에서의 진입 연결까지** 같은 브랜치에서 처리.

## 4. 네트워킹 추가

새 API 한 건 추가 시 4단계:

1. **Router** — `Networking/Routers/FooRouter.swift` 의 enum case 추가
   - `var method`, `var path`, `var queryItems`, `var body`, `var requiresAccessToken` 채우기
   - body가 JSON이면 `try .jsonBody(dto)`, 멀티파트는 `MultipartFormData`
   - 새 path/header/response key 는 모두 `APIInfo` 의 기존 namespace (`Path` / `HeaderField` / `HeaderValue` / `ResponseKey`) 에 추가하고 라우터/빌더에서는 상수 참조만 한다
2. **DTO** — `Networking/Models/DTO/Foo/FooRequestDTO.swift` / `FooResponseDTO.swift`
   - `Codable, Equatable, Sendable`. JSON snake_case ↔ Swift camelCase 매핑은 `enum CodingKeys: String, CodingKey` 의 raw에만 snake_case 허용
3. **Client** — `Dependencies/FooClient.swift`
   - `struct FooClient { var foo: @Sendable (...) async throws -> FooResponseDTO }`
   - `extension FooClient: DependencyKey` — `static var liveValue` 는 `@Dependency(\.httpClient)` 받아 `httpClient.send(APIEndpoint(router: FooRouter.foo(...)))` 호출
   - `static let testValue` 는 모든 클로저가 `throw APIError.transport("FooClient.foo testValue")`
   - `extension DependencyValues { var fooClient: FooClient { get/set } }`
4. **사용** — Feature 안에서 `@Dependency(\.fooClient) private var fooClient` 후 `.run` effect 안에서 호출

토큰/세션은 `HTTPClient` 가 알아서 처리한다 (401/419 시 refresh 1회 시도 → 실패 시 `APIError.invalidSession` 발사 + `SessionClient.invalidate`). Feature/Client 코드에서 토큰 갱신 직접 호출 금지.

### 4-1. 도메인 한정 헬퍼 (Socket / Local Storage)

여러 도메인이 공유하는 client 는 `Dependencies/`. 한 도메인에서만 쓰이는 실시간/저장소는 `Features/Tabs/<도메인>/<역할>/` 에 둔다 — 현재 패턴: `Chat/Socket/ChatSocketClient`, `Chat/Storage/ChatLocalStore`.

- Socket: `actor` 또는 `@Sendable` 클로저 struct + `AsyncStream` 노출
- 도메인 외부 import 금지 — 다른 도메인이 필요해지는 시점에 `Dependencies/` 로 승격 검토
- 사용자 단위 local 캐시는 로그아웃/session invalidation 시 `AppRootFeature` 가 `clearAll()` 호출 (5-1 참고)

## 5. 에러/세션

- 네트워크 에러는 항상 `APIError`. 도메인 layer가 다른 에러 타입을 만들지 않는다.
- 세션 종료/재로그인 트리거는 `AppRootFeature` 가 `sessionClient.events()` 스트림 구독으로 처리. 자식 Feature는 `APIError.invalidSession` 을 그대로 throw 하면 됨.
- `bootstrapSession()` 흐름은 `AppRootFeature.swift` 안에서만 정의 — 다른 곳에서 토큰 refresh를 직접 호출하지 말 것.

### 5-1. Cross-cutting 효과

push token 서버 동기화, session events 구독, 사용자 단위 캐시 (chat local store / image cache) 클리어 등 앱 전역 long-running 효과는 `AppRootFeature.task` 의 `.merge` 안에 `.cancellable(id:)` 로 추가. 새 효과(HLS player teardown 등)도 같은 위치. `AppRootFeature.swift` 가 SwiftLint 임계(400 line) 근처로 커지면 `App/Root/` 에 별도 sub-Reducer 로 분리하고 `body` 에서 composition.

## 6. 로깅

`OSLog` 만 사용. `print` 금지.

```swift
Logger.authSession.notice("...")
Logger.push.error("...: \(error.localizedDescription, privacy: .private)")
```

새 카테고리는 `Networking/Support/Logger+App.swift` 의 `Logger.Category` enum 에 추가하고 `nonisolated static let` 헬퍼도 함께 추가. 카테고리 단위는 **화면/도메인 단위** 권장 (예: `chatRoom`, `postWrite`, `payment`).

- 사용자 식별 가능 정보(토큰, 이메일, 사용자명, 메시지 본문, 좌표 등) → `privacy: .private`
- 상태 코드, enum case 이름, 카운트 등 비민감 정보 → `privacy: .public`

## 7. 의존성 패키지

- ComposableArchitecture (TCA)
- KakaoSDKAuth / KakaoSDKCommon — 카카오 로그인 (`AppDelegate.application(_:open:)` 에서 콜백)
- FirebaseCore / FirebaseMessaging — FCM 푸시
- iamport_ios — 인앱결제 (외부 카드앱 복귀는 `AppURLScheme.payment` 로 식별)
- SnapKit/RxSwift는 **사용하지 않음** (전체 SwiftUI + TCA effect/AsyncStream)

## 8. 코드 스타일

- 들여쓰기 2-space, line 120 warning / 160 error
- import 알파벳 정렬 (SwiftLint `sorted_imports`)
- `force_cast`, `force_try`, `force_unwrapping`, `implicitly_unwrapped_optional` = **error**
- 함수 60/100 lines, 타입 250/400 lines, 파일 400/700 lines (warning/error)
- 식별자: Swift `var/let/func/type` 모두 camelCase. snake_case는 JSON `CodingKey` raw value 에서만 허용
- 주석은 비자명한 WHY 한 줄만. 자명한 코드 설명/단계 나열 금지

## 9. 금지 사항 (프로젝트 한정)

- `Secrets.xcconfig`, `GoogleService-Info.plist`, `APIInfo.swift` 의 내용 직접 접근/노출 금지 — Path/HeaderField/HeaderValue/ResponseKey 상수는 import 없이 그대로 사용
- `Configs/Secrets.xcconfig`, `GoogleService-Info.plist` git 추적 금지
- `Features/` 안에서 `Networking/` 의 Router/HTTPClient 직접 호출 금지 — 반드시 `Dependencies/XxxClient` 경유
- `Shared/Components` 의 컴포넌트는 화면 종속 로직(특정 Feature.State/Action 의존) 금지 — 화면 전용은 `Features/.../Components/`

## 10. 테스트

- `ToneAtelierTests/` — XCTest. 새 Client 추가 시 `testValue` 도 함께 작성해 주입 가능하게 둘 것
- 비기능 변경(주석/포맷팅/문서)에는 빌드 검증 생략 가능

## 11. 진행 중 / 보류

막바지 작업 항목 — 기존 구조의 일관성 안에서 진행한다.

- **MakeFeature 진입** — `Features/Tabs/Make/` 활성. `MainTab` 직접 노출 없이 `ProfileFeature.delegate.makeFilterRequested` 흐름으로 Profile path 안에서 진입. 메인 탭 노출 전환 여부는 추후 결정
- **비디오 HLS 스트리밍** — 기존 `VideoClient` / `Video` DTO 그대로 활용 (별도 client 신설 X), 기존/신규 View 에서 직접 호출
- **화면 전환 로직 정리** — 단순 전환 형태 변경이 아니라 flow 전반에 대한 **대규모 리팩토링 가능성**. 신규 화면 작업 시에도 이 흐름과 충돌하지 않도록 유의
- **일관성 리팩토링 + 버그 수정** — 막바지 주요 작업. 신규 추가보다 기존 구조에 맞추는 변경을 우선
- **`Shared/Components` 디렉터리 정리** — 분류 기준 확정 (탭 단위 vs 탭 간 공통) 후 이동 예정. 지금은 신규 공용 컴포넌트도 일단 `Shared/Components/` 에 그대로 추가
