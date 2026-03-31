# QuickNoteObsidian 코드 퀄리티 가이드

> 구현 에이전트와 리뷰 에이전트가 공통으로 참조하는 가이드.
> 베이스: Apple Swift API Design Guidelines + Ice/Hidden Bar/Dozer 메뉴바 앱 실제 패턴.

---

## 1. 프로젝트 구조

```
QuickNoteObsidian/
├── QuickNoteObsidian/
│   ├── App.swift                  # @main 진입점, 메뉴바 앱 설정
│   ├── AppState.swift             # 매니저들의 소유자, 앱 전체 상태
│   ├── MenuBarManager.swift       # 메뉴바 아이콘, 드롭다운, 최근 기록
│   ├── HotkeyManager.swift        # 글로벌 단축키 등록/해제
│   ├── FileWatcher.swift          # FSEvents로 meta.json 감시
│   ├── MetaJSONParser.swift       # SuperWhisper meta.json 파싱
│   ├── NoteCreator.swift          # Obsidian 노트 파일 생성
│   ├── HUDPanel.swift             # 플로팅 HUD 결과 표시
│   ├── ConfigManager.swift        # 설정 로드/저장 (원자적)
│   └── Assets.xcassets/           # 메뉴바 아이콘
├── docs/
│   ├── 설계의도.md
│   ├── ADR.md
│   └── code_quality.md            # 이 파일
└── README.md
```

- 파일 1개 = 타입 1개
- `AppState`가 모든 매니저를 소유, 매니저 간 의존은 `AppState` 경유

---

## 2. Swift 코딩 컨벤션

> 소스: Apple Swift API Design Guidelines, Google Swift Style Guide, Ice 프로젝트 패턴

### 네이밍
- 타입: `UpperCamelCase` — 명사. 역할이 명확해야 함 (`FileWatcher`, `MetaJSONParser`)
- 변수/함수: `lowerCamelCase`
- Bool 프로퍼티: `is-`/`has-`/`can-` 접두어 필수 (`isWatching`, `hasError`)
- enum 케이스: `lowerCamelCase` (`case normalStatus`, `case folderMissing`)
- 상수: 케이스 없는 `enum`으로 네임스페이스
  ```swift
  enum Constants {
      static let defaultRecordingsPath = "~/Documents/superwhisper/recordings/"
      static let maxTitleLength = 50
  }
  ```
- 약어 금지: `btn`, `mgr`, `cfg` 대신 `button`, `manager`, `config`
- 파일명 = 주요 타입명 (`FileWatcher.swift`)

### 코드 구성
- `// MARK: -`로 섹션 구분 (Properties, Lifecycle, Public, Private)
- 프로토콜 준수는 별도 extension으로
  ```swift
  // MARK: - FileWatcher: NSObject
  extension FileWatcher { ... }
  ```
- 클로저에서 `[weak self]` 필수 (강한 참조 순환 방지)
- `private(set)` 활용 — 외부 읽기 허용, 쓰기 내부 제한

### 에러 처리
- 외부 입력 (meta.json, 파일 시스템): 반드시 에러 처리
- 내부 로직: 불필요한 옵셔널/에러 처리 금지
- `guard let` + early return 우선, 중첩 `if let` 지양
- `os.Logger` 카테고리별 사용
  ```swift
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FileWatcher")
  ```
- `force unwrap(!)` — `Bundle.main.bundleIdentifier!` 같은 보장된 값에만 한정

---

## 3. macOS 메뉴바 앱 패턴

> 소스: Ice, Hidden Bar, Dozer 오픈소스 프로젝트 실제 코드

### 앱 라이프사이클
```swift
// Dock 아이콘 숨기기 (메뉴바 전용 앱 필수)
NSApp.setActivationPolicy(.accessory)
```

### NSStatusItem
- `NSStatusBar.system.statusItem(withLength:)` 로 생성
- `button?.sendAction(on: [.leftMouseUp, .rightMouseUp])` — 좌/우클릭 구분

### 이벤트 모니터 (Ice 패턴)
- Global + Local 분리
- 반환값 프로퍼티에 **strong reference** 저장 필수 (GC/ARC 해제 방지)
- `deinit`에서 `NSEvent.removeMonitor` 호출 필수

### Timer
- `Timer.scheduledTimer` + `[weak self]`
- 리셋 시 `.invalidate()` 후 새 타이머 생성
- `deinit`에서 반드시 `.invalidate()`

### 설정 관리
- `UserDefaults` + 키를 상수 enum으로 관리
- `UserDefaults.standard.register(defaults:)` 앱 시작 시 호출 필수 (기본값 등록)

---

## 4. 이 프로젝트 핵심 규칙

### 글로벌 단축키 (ADR-003, rumps 교훈)
```swift
// ✅ keyCode 사용 (한글 입력기에서도 동작)
if event.keyCode == 34 { /* 'i' 키 */ }

// ❌ characters 사용 금지 (한글 입력기에서 'ㅑ' 반환)
if event.characters == "i" { }
```

### 파일 감시 — FSEvents (ADR-002)
- 감시 경로: 설정값에서 읽기, 하드코딩 금지
- 기본값: `~/Documents/superwhisper/recordings/`
- 새 디렉토리 생성 감지 → 그 안의 `meta.json` 파싱
- 디바운스: 같은 타임스탬프 디렉토리의 이벤트 중복 처리 방지

### meta.json 파싱 (ADR-002)
```swift
let result = json["result"] as? String       // 1차: AI 처리된 텍스트
    ?? json["rawResult"] as? String          // 2차: 원본 텍스트 폴백
// 둘 다 없으면 → 에러 알림, crash 금지
```
- 파싱 실패 시 해당 녹음만 건너뛰기 (앱 전체 중단 금지)
- 처리 완료 타임스탬프는 `Set<String>`으로 관리 → 중복 방지

### 노트 생성 (ADR-004)
- 제목: 첫 줄, 파일명 불가 문자 제거, 50자 제한
- 빈 제목: `음성메모_yyyy-MM-dd_HHmmss`
- 동일 파일명: `{제목}_2`, `{제목}_3` 넘버링
- 파일 쓰기: `.atomic` 옵션 사용 (tmp → rename 자동 처리)

### 설정 저장
```swift
// ✅ 원자적 저장
try data.write(to: configURL, options: .atomic)

// ❌ crash 시 파일 손상
try data.write(to: configURL)
```

### HUD 패널
- 녹음 완료 후 자동 표시, 3~5초 후 자동 닫힘, 클릭 시 즉시 닫힘
- 전체 텍스트 표시 (스크롤 가능)
- `NSFloatingWindowLevel`로 플로팅
- `NSWindow.setReleasedWhenClosed(false)` 설정 필수 (dangling pointer 방지)

### 메뉴바 드롭다운
- 최근 기록 5~10개 (제목 + 시간)
- 클릭 시 Obsidian에서 노트 열기 (`obsidian://` URI)
- 상태 아이콘: 정상 / 감시 폴더 없음 / 에러

---

## 5. 하지 말 것

### 프로젝트 규칙
- SuperWhisper 프로세스를 직접 제어하지 말 것 → 딥링크만 사용
- Obsidian 프로세스에 직접 접근하지 말 것 → 파일 생성만
- 네트워크 통신 없음 — 모든 것이 로컬 파일 기반
- 불필요한 추상화 금지 — 파일 10개 미만의 소형 앱
- 에러 자동 재시도 금지 — 상태 표시 후 사용자 판단

### Swift 안티패턴 (실제 오픈소스에서 확인된 함정)
- `NSEvent.addGlobalMonitorForEvents` 반환값 미저장 → 모니터 ARC 해제, 이벤트 수신 중단
- `NSEvent.addGlobalMonitorForEvents` 핸들러에서 이벤트 소비(swallow) 시도 → 불가. Local만 가능
- Timer `.invalidate()` 누락 → 메모리 누수
- `NSWindow.close()` 사용 → release 트리거로 dangling pointer. `orderOut(nil)` 사용
- `DispatchQueue.main.asyncAfter` 매직 딜레이 남발 → 필요하면 주석으로 이유 명시
- `AppDelegate`에 모든 로직 → `AppState` + 역할별 Manager로 분리
