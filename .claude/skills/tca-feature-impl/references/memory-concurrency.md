# 메모리 / Swift Concurrency 참조

ToneAtelier의 메모리 관리 및 동시성 원칙. `tca-feature-impl` 스킬 본문에서 참조.

## 1. 클로저 self 캡처

TCA `.run { send in ... }` 안에서는 dependency를 미리 추출.

```swift
case .task:
  return .run { [authClient = self.authClient] send in
    let result = try await authClient.refresh()
    await send(.refreshDone(result))
  }
  .cancellable(id: "FooFeature.task", cancelInFlight: true)
```

현재 RxSwift 미사용. 도입 시 글로벌 CLAUDE.md "코드 스타일 §1" 준수 (`drive(with:)`, `withUnretained` 등).

## 2. delegate 프로퍼티

UIKit 브리지 시(예: `WKWebView` Coordinator) `weak var`.

```swift
final class Coordinator: NSObject, WKScriptMessageHandler {
  weak var delegate: WebViewDelegate?
  weak var webView: WKWebView?
}
```

## 3. 비동기 작업

화면 재진입 중복 방지를 위해 `.cancellable(id:cancelInFlight:true)`.

```swift
return .run { ... }
  .cancellable(id: "FeatureName.specificTask", cancelInFlight: true)
```

ID는 Feature 이름 + 작업명 조합. 충돌 방지를 위해 enum 또는 구조체 ID 사용 가능.

## 4. In-flight 작업 join

여러 호출자가 같은 작업을 요청할 때 actor 내부에서 in-flight task를 공유:

```swift
// LiveSessionCenter.refreshTokens(using:) 패턴
// LiveImageStore.data(for:loader:) 패턴
```

새 비슷한 패턴 추가 시 actor + currentTask 변수 + `task.value` await.

## 5. DisposeBag (RxSwift 도입 시)

현재 미사용. 도입 시:
- 클래스 단위 보유
- 해제 시점 stream 종료 검증
- 모든 구독은 `.disposed(by: disposeBag)` 명시

## 6. deinit 검증

새 화면 또는 장기 작업 추가 시 임시 검증 코드:

```swift
deinit {
  print("Deinit: \(Self.self)")
}
```

검증 후 제거하거나 Debug 빌드에서만 활성화.

## 7. 임시 파일 cleanup

Make 도메인의 `MakePhotoFileCleaner.removeFileIfNeeded(at:)` 패턴.

새 임시 파일 생성 시 다음 모든 경로에서 cleanup 호출:
- 성공
- 실패
- 취소
- 제출 후

## 8. 이미지 캐시

`LiveImageStore`가 단일 actor 인스턴스. 메모리 부담 시 `imageClient.clearCache()`.

직접 `Image(uiImage:)`로 큰 이미지 로드 금지 — `imageClient` 경로 사용.

## 9. WebView

`WKScriptMessageHandler`는 `dismantleUIView`에서 명시 제거 + `coordinator.webView = nil`.

```swift
static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
  uiView.configuration.userContentController.removeAllScriptMessageHandlers()
  coordinator.webView = nil
}
```

## 10. AsyncStream continuation

`onTermination`으로 자동 제거.

```swift
AsyncStream<Event> { continuation in
  let id = ...
  Task { await register(continuation, id: id) }
  continuation.onTermination = { _ in
    Task { await unregister(id: id) }
  }
}
```

`LiveSessionCenter.events()` 패턴 참조.
