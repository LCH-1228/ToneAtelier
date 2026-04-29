---
name: ios-code-review
description: ToneAtelier iOS 코드 리뷰 체크리스트. reviewer 에이전트가 코드 변경을 점검할 때 사용. TCA 패턴, 메모리/Swift Concurrency, AGENTS.md+HarnesDocs 컨벤션, 디자인 토큰 일관성, 성능을 우선순위(Critical/Major/Minor)로 분류해 보고. "리뷰해줘", "검토해줘", "이거 봐줘", "확인해줘" 같은 검토 요청 시 트리거. 코드 직접 수정은 하지 않음.
---

# iOS Code Review Skill

ToneAtelier 코드 변경 사항 리뷰 절차와 체크리스트. **코드를 직접 수정하지 않고 지적·제안만 한다.**

## 0. 진입 시 필수 절차

1. **`swiftui-pro` 스킬 호출** — SwiftUI 측면 추가 검증 (모던 API, 성능 최적화)
2. async/await/actor가 등장하면 **`swift-concurrency-pro` 스킬 호출**
3. 메모리 의심 패턴이 보이면 **`memory-leak` 스킬 호출**
4. 대상 파일 + 인접 파일(부모 Reducer, 사용처 View, Client) 같이 읽어 맥락 파악
5. `HarnesDocs/Essentials.md` + `AGENTS.md`를 컨벤션 정답지로 사용

## 우선순위 정의

- **Critical**: 빌드 실패, 크래시, 메모리 누수, 보안/세션 위반, TCA 핵심 패턴 위반
- **Major**: 컨벤션 위반, 디자인 토큰 일탈, 성능 저하, 유지보수성 손상
- **Minor**: 가독성, 네이밍, 사소한 최적화, 응답 모델 보강

## 1. TCA 패턴 (Critical)

체크 항목:

- [ ] 부모 ↔ 자식 통신이 **`delegate` enum 한정**인가? 자식이 부모 State에 접근하는 위반 없음
- [ ] `.run { ... }` 효과에 `.cancellable(id:cancelInFlight:true)` 적용
- [ ] `Scope`가 `BindingReducer` 앞에 위치
- [ ] `@Presents` + `.ifLet(\.$alert, ...)` 패턴 준수
- [ ] `BindableAction` 채택 시 `binding(BindingAction<State>)` 케이스 존재
- [ ] 표준 child Action 분기 패턴 사용:
  ```swift
  case .child(.delegate(...)): return .none
  case .child: return .none
  case .childDismissed: state.child = nil; return .none
  ```
- [ ] 비동기 effect ID가 Feature명 + 작업명 조합으로 충돌 방지

## 2. 메모리 / Swift Concurrency (Critical)

체크 항목:

- [ ] 클로저 self 캡처: dependency 사전 추출 (`[foo = self.foo]`)
- [ ] `delegate` 프로퍼티가 `weak var` (UIKit 브리지)
- [ ] Task / AsyncStream / NotificationCenter cancel/제거 경로 명시
- [ ] 임시 파일 cleanup이 모든 경로(성공/실패/취소/제출 후)에 존재
- [ ] `LiveSessionCenter.generation` 캡처/비교 패턴 준수 (보호 엔드포인트)
- [ ] `LiveImageStore` in-flight join 패턴 준수
- [ ] WebView dismantle에서 `WKScriptMessageHandler` 명시 제거
- [ ] AsyncStream `onTermination`으로 자동 제거
- [ ] 새 화면 또는 장기 작업에 deinit 검증 코드 (선택)

## 3. 컨벤션 (Major)

체크 항목:

- [ ] `AGENTS.md` 디렉토리 역할대로 파일 위치 (예: 화면 전용 컴포넌트는 해당 Feature `Components/`, 공유 UI만 `Shared/Components/`)
- [ ] `<FeatureName>Feature.swift` + `<FeatureName>View.swift` 쌍 명명
- [ ] `HarnesDocs/Essentials.md` §16 작업 진행 정책 준수:
  - `APIInfo.swift` / `Secrets.xcconfig` 미접근
  - 한글 응답 / 한글 커밋 본문
  - 빌드 가능한 단위로 커밋 분리
- [ ] View가 URLSession 직접 호출 안 함
- [ ] API는 `Dependencies/<Domain>Client` 경유
- [ ] `liveValue`가 `httpClient.send` 1줄 패턴
- [ ] `testValue`가 throw stub
- [ ] 새 외부 SPM / UIKit / RxSwift 도입 전 사용자 사전 확인 흔적

## 4. 디자인 토큰 일관성 (Major)

체크 항목:

- [ ] 자산: `AppAsset.<scope>.<name>` 사용. raw asset name (`"image_xxx"`) 위반 없음
- [ ] 색상: `HomeTheme.*` 또는 `Color(hex: 0xRRGGBB, opacity:)`. **`UIColor` / `Color(red:green:blue:)` 직접 사용 위반**
- [ ] 폰트: `HomeTheme.pretendard()` / `HomeTheme.mulgyeol()` 사용. `.system(size:)` 직접 사용 위반
- [ ] 탭 바 회피: `MainTabBarView.Layout.contentInsetHeight` 사용. 절대값 hard-code 위반
- [ ] 다크 테마: `.preferredColorScheme(.dark)` 또는 `HomeTheme.background` 적용
- [ ] `Shared/Components/*`가 도메인 모델에 의존하지 않음 (`HomeTheme`/`AppAsset`만)

## 5. 성능 (Minor~Major)

체크 항목:

- [ ] 불필요한 `@ObservableState` 변경으로 인한 View 재계산
- [ ] 큰 이미지를 `Image(uiImage:)`로 직접 로드 (캐시/리사이즈 누락) — `imageClient` 경유 권장
- [ ] 리스트에서 매 아이템마다 무거운 closure 생성
- [ ] `@StateObject` / `@State` / `@Bindable` 등 프로퍼티 래퍼 잘못된 자리
- [ ] 페이지네이션 종료 신호(`nextCursor == "0"`) 미처리 → 무한 루프 가능
- [ ] 합성 Client(Feed/Home/HomeDetail)에서 `async let` 병렬 호출 누락

## 6. 응답 모델 / 네트워킹 (Minor)

체크 항목:

- [ ] 안정화된 응답을 `JSONValue`로 두지 않음 (DTO 교체 권장)
- [ ] snake_case ↔ camelCase 혼재 응답에 `firstString(for:)` 헬퍼 사용
- [ ] 표준 응답 모델(`EmptyResponse` / `MessageResponse` / `LikeStatusResponse` / `UploadedFilesResponse`) 활용 가능한 자리에 별도 정의 안 함
- [ ] Router `requiresAccessToken` / `requiresRefreshToken` 플래그 정확
- [ ] multipart fieldName: 일반 `files`, 프로필 `profile`

## 7. SnapKit 순서 (UIKit 등장 시, Minor)

글로벌 CLAUDE.md "코드 스타일 §2" 준수:
- 그룹: 중심 → 크기 → 외곽 모서리
- 방향: 상 → 하 → 좌 → 우
- 동일 수치는 축약 속성(`edges`, `verticalEdges`, `horizontalEdges`) 우선
- centerY → centerX, height → width, top → bottom → leading → trailing

## 8. 표준 흐름 위반 (Critical~Major)

체크 항목:

- [ ] Optimistic Like 패턴에서 `isLikeRequestInFlight` 가드 누락
- [ ] Like 카운트가 `max(0, ...)` 음수 방지 없음
- [ ] delegate 시그니처가 `likeStatusChanged(id:isLiked:likeCount:)`로 통일
- [ ] CancellationError가 silent 처리(alert 미노출) 됐는지
- [ ] Error → 사용자 메시지가 `userFacingMessage` 확장 사용

## 출력 형식

```
[요약] 한 줄 결론 (LGTM / 수정 후 머지 / 큰 변경 필요)

[Critical] (반드시 수정)
- 파일경로:라인 — 무엇이 / 왜 / 권장 수정
  ```swift
  // 권장 코드 예시 (짧게)
  ```

[Major] (수정 권장)
- ...

[Minor] (선택)
- ...

[칭찬] (선택)
- ...
```

라인 번호는 가능한 명시. 권장 코드는 짧게. **파일 직접 수정 금지.**

## 협업

- 백엔드 정합성 의심 → supervisor에게 qa 호출 권장
- 빌드 실패 우려 → supervisor에게 tester 호출 권장
- 광범위 수정 필요 → supervisor에게 implementer 재호출 권장

## 금지 사항

- 코드 직접 수정 금지
- `APIInfo.swift` / `Secrets.xcconfig` 접근 금지
- 사용자 의도 추측 후 임의 결정 금지
