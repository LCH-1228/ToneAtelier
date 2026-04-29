# 표준 흐름 참조

ToneAtelier에서 반복 등장하는 패턴 모음. `tca-feature-impl` 본문에서 참조.

## 1. Optimistic Like + Snapshot Rollback

HomeDetail/Feed 동일 패턴.

```text
likeButtonTapped:
  guard !isLikeRequestInFlight
  pendingSnapshot = current(isLiked, likeCount)
  isLikeRequestInFlight = true
  applyLikeStatus(targetStatus)              # UI 즉시 토글
  delegate(.likeStatusChanged(...))          # 부모 즉시 통지
  → setLike(id, target)
       success(confirmedStatus): apply confirmed + delegate 재송출
       failure: snapshot으로 원복 + delegate 재송출
```

**핵심:**
- 부모는 `delegate.likeStatusChanged`를 받아 양쪽(필터/랭킹) 배열 동시 동기화 (Feed 한정)
- `settingLikeCount` / `settingLikeStatus`는 `max(0, likeCount ± 1)`로 음수 방지
- delegate 시그니처 통일: `delegate(.likeStatusChanged(id:isLiked:likeCount:))`

## 2. 페이지네이션 (Feed)

```text
- 마지막 카드 등장 시 loadNextPage 발동 (filterItems.last?.id == id)
- 종료 신호: 신규 항목 0개 + cursor 미변경 → nextCursor = "0"
- 에러 시 nextPageErrorMessage 노출, 사용자 명시적 retry까지 자동 호출 안 함
```

**핵심:**
- 종료 후 추가 호출 금지 (`nextCursor == "0"` 체크)
- 에러 자동 재시도 금지 (사용자 액션 대기)

## 3. Error → 사용자 메시지

각 Feature는 fileprivate `Error.userFacingMessage` 확장 보유. `APIError`별 분기:

| APIError 케이스 | 메시지 |
|---|---|
| `transport / decoding / invalidBaseURL / invalidURL` | 메시지 그대로 |
| `missingAccessToken / missingRefreshToken` | "인증 정보가 없어 ..." |
| `invalidSession(statusCode)` | "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))" |
| `server(statusCode, message?, _)` | server message 우선, 없으면 generic + statusCode |
| 그 외 | "잠시 후 다시 시도해 주세요." 톤 |

`AppRootFeature.BootstrapFailure.from(error:)`는 부트스트랩 전용 별도 매핑.

## 4. CancellationError 정책

- 토큰 갱신/요청 도중 `CancellationError` → silent (alert 안 띄움, 진행 플래그만 해제)
- LoginFeature `Error.isRequestCancellation`: `CancellationError + URLError.cancelled` 둘 다 포착

## 5. 인증 / 세션 플로우

### 부트스트랩

```text
AppRootFeature.task
  ├─ sessionClient.snapshot()
  │    ├─ access·refresh 모두 사용 가능?
  │    │     Yes → authClient.refresh()
  │    │            ├─ 성공 → .authenticated
  │    │            ├─ 401/418 → .unauthenticated(LoginFeature.Notice)
  │    │            └─ 그 외 → .retryableFailure(BootstrapFailure)
  │    │     No → partial token clear → .unauthenticated(nil)
  └─ sessionClient.events() 구독 (.cancellable)
       └─ .invalidated(reason) → 강제 LoginView 복귀 + Notice
```

### 토큰 자동 갱신 (보호 엔드포인트가 401/419)

```text
HTTPClient.send → retryAfterRefreshingToken
  refreshTokens() = LiveSessionCenter.refreshTokens(using: AuthRouter.refresh)
    ├─ 성공 → updateTokens → 원 요청 1회 재시도
    └─ 실패 → invalidateSession(.refreshTokenRejected/.expired)
              → APIError.invalidSession 전환
```

### 응답 토큰 자동 추출

응답 body에 `APIInfo.ResponseKey.accessToken` / `.refreshToken` 키가 있으면 `HTTPClient.extractTokens`가 자동으로 `updateTokens` 호출. 소셜 로그인이 이 경로 사용 → Login/Join Reducer는 토큰을 직접 다루지 않음.

### 세션 무효화 사유

`SessionInvalidationReason`: `accessTokenRejected(401) / refreshTokenRejected(401) / expired(418/419)` 3종 → `LoginFeature.Notice`로 매핑.

## 6. URLRequestBuilder 규칙

- baseURL과 endpoint path 슬래시 자동 정규화
- `Accept: application/json` 자동 부착
- `SeSACKey` 헤더는 키가 비어있지 않을 때만
- `Authorization`은 access token을 **Bearer 접두 없이** 그대로 부착
- `RefreshToken`은 별도 헤더
- multipart는 boundary를 `Boundary-<UUID>`로 자동 생성
