# 기본사항

1. 모든 답변은 한글로 작성한다.
2. 어떤 작업에서도 `**/APIInfo.swift`는 읽기, 수정, 작성 대상에서 제외한다.
3. 어떤 작업에서도 `**/Secrets.xcconfig`는 읽기, 수정, 작성 대상에서 제외한다.
4. 금지 파일의 값이 필요하면 직접 확인하지 말고 사용자에게 확인을 요청한다.

# 프로젝트 구조

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
│   ├── Models/
│   ├── Routers/
│   └── Support/
└── Debug/
```

# 디렉토리 역할

1. `App`: 앱 진입점, SDK 초기화, 전역 루트 분기만 담당한다.
2. `App/Root`: 로그인 여부에 따른 루트 화면 전환과 전역 Navigation 구성을 담당한다.
3. `Features`: 화면 단위 기능을 둔다.
4. `Features/Auth`: 인증 관련 화면과 상태를 둔다.
5. `Features/Auth/Login`: 로그인 화면 전용 기능을 둔다.
6. `Features/MainTab`: 탭 바 컨테이너와 탭 선택 상태만 담당한다.
7. `Features/Tabs`: 실제 탭 화면들을 둔다.
8. `Shared`: 특정 도메인에 묶이지 않는 공용 UI, 디자인 시스템, Extension을 둔다.
9. `Dependencies`: TCA Dependency와 외부 SDK/API 클라이언트 진입점을 둔다.
10. `Networking`: API 요청 생성, 라우터, 공통 응답 모델, HTTP 처리 기반 코드를 둔다.
11. `Debug`: API 테스트용 화면과 디버그 지원 코드를 둔다.
12. `Configs`: xcconfig 기반 설정 파일을 둔다. 실제 시크릿 파일은 작업 대상에서 제외한다.

# Feature 구현 규칙

1. 화면 단위 기능은 TCA 구조를 기본으로 한다.
2. 새 화면은 가능한 한 `<FeatureName>Feature.swift`와 `<FeatureName>View.swift`를 함께 둔다.
3. View는 상태를 직접 소유하거나 API를 직접 호출하지 않고, Store의 state를 표시하고 action을 전송한다.
4. 비동기 작업과 외부 의존성 호출은 Reducer에서 `@Dependency`를 통해 처리한다.
5. 화면 전용 하위 UI는 해당 Feature의 `Components` 폴더에 둔다.
6. 여러 Feature에서 재사용되는 UI만 `Shared/Components`로 이동한다.
7. 탭 화면은 아래 구조를 기본으로 확장한다.

```text
Features/Tabs/
└── <TabName>/
    ├── <TabName>Feature.swift
    ├── <TabName>View.swift
    └── Detail/
        ├── <TabName>DetailFeature.swift
        └── <TabName>DetailView.swift
```

# 네트워킹 및 의존성 규칙

1. Feature에서 `URLSession`이나 raw 네트워크 레이어를 직접 호출하지 않는다.
2. API 호출은 `Dependencies`의 Client를 통해 진입한다.
3. API 경로와 요청 구성은 `Networking/Routers`에 둔다.
4. 요청/응답 모델은 성격에 따라 `Dependencies` 또는 `Networking/Models`의 기존 패턴을 따른다.
5. 토큰, 세션, Keychain 등 인증 저장소는 View가 직접 다루지 않는다.

# 설정 파일 규칙

1. `Configs/App.xcconfig`는 공통 설정 진입점이다.
2. `Configs/Secrets.xcconfig.example`은 예시 파일로만 사용한다.
3. `Configs/Secrets.xcconfig`는 실제 키를 담는 로컬 파일이며, 읽기/수정/작성하지 않는다.
4. 프로젝트 파일에서 xcconfig 참조를 수정할 때는 clean build 기준으로 확인한다.

# 작업 규칙

1. 기존 사용자 변경사항을 임의로 되돌리지 않는다.
2. 구조나 정책이 불명확한 경우 임의로 결정하지 말고 사용자에게 먼저 질문한다.
3. 의미 있는 코드 변경 후에는 가능한 경우 `ToneAtelier` iOS Simulator 빌드로 확인한다.
4. 커밋은 빌드 가능한 작업 단위로 분리한다.
