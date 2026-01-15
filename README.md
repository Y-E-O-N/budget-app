# 가계부 앱 (Budget App)

Flutter로 개발된 간단한 가계부 앱입니다.

## 📱 기능

### 예산 탭 (메인 기능)
- **월별 예산 관리**: ◀ ▶ 버튼으로 월 이동
- **예산 추가/수정/삭제**
  - 우측 상단 [+] 버튼으로 추가
  - 항목 길게 누르기: 수정/삭제 메뉴
  - 항목 스와이프: 삭제
- **매달 적용 옵션**: 다음 달에 자동으로 예산 복사

### 예산 상세 페이지
- **예산 현황**: 예산 / 사용 / 남은 금액 + 진행률 바
- **세부예산 관리**: 예산을 더 세분화하여 관리
- **지출 내역 등록**: 날짜, 세부예산 선택, 금액, 메모

### 하단 탭
- 예산 (구현 완료)
- 내역 (추후 개발)
- 통계 (추후 개발)
- 설정 (추후 개발)

---

## 🛠️ 설치 및 실행

### 1. Flutter 프로젝트 생성

```bash
# 새 Flutter 프로젝트 생성
flutter create budget_app

# 프로젝트 폴더로 이동
cd budget_app
```

### 2. 파일 복사

다운로드한 파일들을 생성된 프로젝트에 복사합니다:
- `pubspec.yaml` → 프로젝트 루트에 덮어쓰기
- `lib/` 폴더 전체 → 프로젝트의 `lib/` 폴더에 덮어쓰기

### 3. 패키지 설치

```bash
# 의존성 패키지 다운로드
flutter pub get
```

### 4. 실행

```bash
# 디버그 모드로 실행
flutter run

# 특정 기기 지정 (예: Chrome)
flutter run -d chrome

# 특정 기기 지정 (예: 연결된 안드로이드)
flutter run -d <device_id>
```

### 5. APK 빌드 (안드로이드)

```bash
# 릴리즈 APK 빌드
flutter build apk --release
```

빌드된 APK 위치: `build/app/outputs/flutter-apk/app-release.apk`

---

## 📁 프로젝트 구조

```
lib/
├── main.dart                      # 앱 진입점, 초기화, 테마 설정
│
├── models/                        # 데이터 모델 (구조 정의)
│   ├── budget.dart               # 예산 모델
│   ├── budget.g.dart             # Hive 어댑터 (자동 생성)
│   ├── sub_budget.dart           # 세부예산 모델
│   ├── sub_budget.g.dart         # Hive 어댑터
│   ├── expense.dart              # 지출 모델
│   └── expense.g.dart            # Hive 어댑터
│
├── providers/                     # 상태 관리
│   └── budget_provider.dart      # 예산 데이터 CRUD, 월 이동 등
│
├── screens/                       # 화면 UI
│   ├── home_screen.dart          # 메인 화면 (하단 탭바)
│   ├── budget_tab.dart           # 예산 탭
│   ├── budget_detail_screen.dart # 예산 상세 (세부예산, 지출)
│   ├── history_tab.dart          # 내역 탭 (미구현)
│   ├── stats_tab.dart            # 통계 탭 (미구현)
│   └── settings_tab.dart         # 설정 탭 (미구현)
│
└── widgets/                       # 재사용 가능한 위젯 (추후 확장)
```

---

## 📦 사용된 패키지

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `provider` | ^6.1.1 | 상태 관리 |
| `hive` | ^2.2.3 | 로컬 데이터베이스 |
| `hive_flutter` | ^1.1.0 | Hive Flutter 확장 |
| `intl` | ^0.18.1 | 숫자/날짜 포맷팅 |
| `uuid` | ^4.2.1 | 고유 ID 생성 |

---

## 💡 코드 주요 개념 설명

### Provider 패턴
```dart
// 데이터 제공
ChangeNotifierProvider(
  create: (context) => BudgetProvider()..init(),
  child: MyApp(),
)

// 데이터 구독 (자동 리빌드)
Consumer<BudgetProvider>(
  builder: (context, provider, child) {
    return Text(provider.totalBudget.toString());
  },
)

// 일회성 접근
context.read<BudgetProvider>().addBudget(...);
```

### Hive 데이터베이스
```dart
// 초기화
await Hive.initFlutter();
Hive.registerAdapter(BudgetAdapter());

// Box 열기
final box = await Hive.openBox<Budget>('budgets');

// CRUD
box.put(id, budget);     // 추가/수정
box.get(id);             // 조회
box.delete(id);          // 삭제
box.values;              // 전체 조회
```

### StatelessWidget vs StatefulWidget
```dart
// StatelessWidget: 상태 없음 (고정된 UI)
class MyWidget extends StatelessWidget { ... }

// StatefulWidget: 상태 있음 (setState로 UI 갱신)
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}
```

---

## ⚠️ 참고사항

1. **폰트 설정**
   - `pubspec.yaml`에 Pretendard 폰트가 설정되어 있지만
   - 폰트 파일은 별도로 추가해야 합니다
   - 없으면 기본 시스템 폰트가 사용됩니다

2. **다크모드**
   - 기기의 시스템 설정을 따릅니다
   - `themeMode: ThemeMode.system`

3. **데이터 저장**
   - Hive를 사용하여 앱 내부에 저장
   - 앱 삭제 시 데이터도 함께 삭제됩니다

---

## 🚀 향후 개발 계획

- [ ] 내역 탭: 전체 지출 내역 조회, 검색, 필터
- [ ] 통계 탭: 월별 차트, 카테고리별 분석
- [ ] 설정 탭: 다크모드, 백업/복원, 알림
- [ ] 위젯: 홈 화면 위젯 지원
