# ADR (Architecture Decision Records)

> QuickNoteObsidian 프로젝트의 기술 결정 기록

---

## ADR-001: 음성 엔진 — SuperWhisper Standard 채택

- **일시**: 2026-03-31
- **상태**: 확정

### 배경
macOS에서 음성 → 텍스트 변환 후 Obsidian 노트를 자동 생성하는 앱을 만들기 위해 음성 엔진 선택이 필요.

### 후보
| 후보 | 결과 |
|---|---|
| macOS 내장 받아쓰기 | 영어→한글 음차 변환, 조우→兆 오류, 띄어쓰기 불량 |
| SuperWhisper Ultra | 인식 우수하나 Pro 구독 필요 ($9.99/월) |
| SuperWhisper Standard | 무료/무제한, 영어 보존 우수, 띄어쓰기 양호 |
| Voice Inbox for Obsidian | 불합격 (전반적 품질 부족) |

### 결정
**SuperWhisper Standard** 채택.

### 이유
- 비교 테스트 3종에서 맥북 대비 5:2 우세
- 영어 용어 보존력 압도적 (개발/기술 메모 용도에 적합)
- Standard 모델은 무료, 음성 인식 사용량 무제한
- AI 후보정은 하루 25회 제한이나 기본 음성 인식에는 영향 없음

### 리스크
- 한국어 고유명사 인식은 맥북보다 약함 (케이건 드라카 → K-건 드라카)
- SuperWhisper 자체가 서비스 종료될 가능성 (대체: macOS 내장 or Whisper 직접 구동)

---

## ADR-002: 연동 방식 — 파일 감시 (FSEvents) 채택

- **일시**: 2026-03-31
- **상태**: 확정

### 후보
| 방식 | 장점 | 단점 |
|---|---|---|
| 파일 감시 (FSEvents) | 추가 도구 불필요, SuperWhisper 설정 변경 없음 | 파일 구조 변경 리스크 |
| Macrowhisper (CLI) | 강력한 자동화, 웹훅 가능 | 외부 의존성 추가, brew 설치 필요 |
| macOS Shortcuts | 구현 간단 | 유연성 부족, 복잡한 로직 불가 |
| 클립보드 감시 | SuperWhisper 기본 동작 활용 | 다른 클립보드 내용과 충돌, 구분 불가 |

### 결정
**파일 감시 (FSEvents)** 채택.

### 이유
- SuperWhisper가 이미 `~/Documents/superwhisper/recordings/{timestamp}/meta.json`에 결과를 자동 저장
- 추가 도구(Macrowhisper 등) 설치 불필요
- Swift에서 FSEvents 네이티브 지원 (DispatchSource.makeFileSystemObjectSource 등)
- meta.json에 `result`, `rawResult`, `datetime`, `modeName` 등 충분한 메타데이터 포함

### 리스크 & 대응
- **파일 구조 변경**: 감시 경로를 설정값으로 관리, 파싱 실패 시 에러 메시지
- **meta.json 키 변경**: `result` 키 없으면 `rawResult` 폴백 → 둘 다 없으면 에러 알림
- **폴더 경로 변경**: 앱 시작 시 경로 존재 확인, 없으면 메뉴바 경고

### 참고: meta.json 구조
```json
{
  "result": "최종 처리된 텍스트",
  "rawResult": "원본 음성 인식 텍스트",
  "datetime": "2026-03-31T05:30:00",
  "modeName": "Default",
  "modelName": "Standard",
  "duration": 3302
}
```

---

## ADR-003: 앱 구현 기술 — Swift 네이티브 채택

- **일시**: 2026-03-31
- **상태**: 확정

### 후보
| 기술 | 장점 | 단점 |
|---|---|---|
| Swift 네이티브 | FSEvents/글로벌 단축키 네이티브, 권한 처리 간단, 빌드 단순 | Swift 학습 필요 |
| Python + rumps | 기존 레시피 존재, 빠른 프로토타이핑 | py2app 빌드 복잡, TCC 권한 삽질, PyObjC 크래시 함정 다수 |

### 결정
**Swift 네이티브** 채택.

### 이유
- rumps 레시피에서 경험한 문제들 (TCC 권한 분리, py2app 빌드, NSWindow 크래시, GC 이벤트 모니터 소멸)이 Swift에서는 발생하지 않거나 훨씬 단순
- 글로벌 단축키: Swift에서 `NSEvent.addGlobalMonitorForEvents` 네이티브 사용
- FSEvents: `DispatchSource` 네이티브 지원
- 접근성 권한: .app 번들 자체에 직접 적용 (py2app 같은 우회 불필요)
- Xcode로 빌드/서명/배포 일원화

### rumps 레시피에서 가져올 교훈
| 교훈 | Swift 적용 |
|---|---|
| `event.keyCode()` 사용 (한글 입력기 대응) | 동일하게 `event.keyCode` 사용 필수 |
| config 원자적 저장 (tmp → rename) | 동일 패턴 적용 |
| 이벤트 모니터 strong reference 유지 | 프로퍼티로 저장 필수 |
| HUD 알림 (performSelector 지연) | NSWindow 또는 UserNotifications 사용 |

---

## ADR-004: 노트 제목 생성 — 음성 첫 줄 추출

- **일시**: 2026-03-31
- **상태**: 확정

### 결정
`result` 텍스트의 첫 줄(또는 첫 문장)을 노트 제목으로 사용.

### 규칙
- 파일명에 사용 불가한 문자 제거: `/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|`
- 제목이 50자 초과 시 50자에서 자르고 `…` 추가
- 제목이 비어있으면 `음성메모_YYYY-MM-DD_HHmmss` 형식 사용
- 동일 제목 파일 존재 시 `{제목}_2`, `{제목}_3` 등 넘버링

---

## ADR-005: SuperWhisper 트리거 — 딥링크 방식

- **일시**: 2026-03-31
- **상태**: 확정

### 결정
글로벌 단축키 입력 시 `superwhisper://record` URL 스킴을 호출하여 녹음 시작.

### 이유
- SuperWhisper 공식 지원 딥링크
- `superwhisper://mode?key=KEY`로 모드 전환도 가능 (향후 확장)
- 별도 API/CLI 불필요

### 주의
- SuperWhisper가 설치/실행되어 있지 않으면 딥링크 실패 → 에러 처리 필요
