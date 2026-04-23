# Directory Structure

로그인 기능 구현 전 기준 디렉토리 구조를 먼저 고정한다.

## 기본 원칙

- `App`: 앱 진입점과 전역 분기만 담당한다.
- `Features`: 실제 화면 단위 기능을 둔다.
- `MainTab`: 탭 바 컨테이너 역할만 맡고, 실제 탭 화면은 `Tabs` 아래로 확장한다.
- `Shared`: 여러 Feature에서 재사용하는 UI/유틸만 둔다.
- 기존 `Dependencies`, `Networking`, `Debug` 구조는 그대로 유지한다.

## 현재 기준 트리

```text
ToneAtelier/
├── App/
│   └── Root/
├── Features/
│   ├── Auth/
│   │   └── Login/
│   │       └── Components/
│   ├── MainTab/
│   └── Tabs/
├── Shared/
│   ├── Components/
│   ├── DesignSystem/
│   └── Extensions/
├── Dependencies/
├── Networking/
└── Debug/
```

## 역할 정의

### `App/Root`

- 앱 시작 지점
- 로그인 여부에 따라 `Login` 또는 `MainTab`으로 분기
- 전역 NavigationStack 또는 앱 루트 상태 보관

### `Features/Auth/Login`

- 로그인 화면 전용 기능
- 추후 생성 대상 예시
  - `LoginFeature.swift`
  - `LoginView.swift`
  - `Components/LoginTextField.swift`
  - `Components/SocialLoginButton.swift`

### `Features/MainTab`

- `TabView` 또는 탭 선택 상태를 담당
- 각 탭의 진입 화면을 조합하는 컨테이너
- 추후 생성 대상 예시
  - `MainTabFeature.swift`
  - `MainTabView.swift`

### `Features/Tabs`

- 실제 탭 화면들을 보관
- 탭이 생기면 아래 규칙으로 확장

```text
Features/Tabs/
└── <TabName>/
    ├── <TabName>View.swift
    ├── <TabName>Feature.swift
    └── Detail/
        ├── <TabName>DetailView.swift
        └── <TabName>DetailFeature.swift
```

예시:

```text
Features/Tabs/
└── Home/
    ├── HomeView.swift
    ├── HomeFeature.swift
    └── Detail/
        ├── HomeDetailView.swift
        └── HomeDetailFeature.swift
```

### `Shared`

- 특정 도메인에 묶이지 않는 공용 UI
- 공용 버튼, 입력 필드 스타일, ViewModifier, Extension 등

## 이번 단계의 결정

- 디렉토리만 먼저 정리하고, 기존 `ContentView.swift`와 `ToneAtelierApp.swift`는 아직 이동하지 않는다.
- 다음 단계에서 `App/Root`, `Features/Auth/Login`, `Features/MainTab`부터 실제 구현 파일을 추가한다.
