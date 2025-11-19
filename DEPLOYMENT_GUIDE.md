# 앱스토어 배포 가이드

## 📱 앱 정보

- **앱 이름**: Roulette Lotto (룰렛 로또)
- **패키지명 (Android)**: `com.jysoft.roulettelotto.app`
- **Bundle ID (iOS)**: `com.jysoft.roulettelotto.app`
- **버전**: 1.0.0
- **버전 코드 (Android)**: 2

---

## 🤖 Google Play Store 배포

### 1. 준비된 파일
- **앱 번들**: `build/app/outputs/bundle/release/app-release.aab`
- **서명**: 출시 모드로 서명됨
- **키스토어**: `android/key/roulette-lotto-key.jks` (⚠️ 반드시 백업 필요!)

### 2. 배포 단계

#### Step 1: Google Play Console 접속
1. [Google Play Console](https://play.google.com/console)에 로그인
2. 개발자 계정이 없다면 등록 (일회성 $25 결제 필요)

#### Step 2: 새 앱 생성
1. "앱 만들기" 클릭
2. 앱 이름: **Roulette Lotto**
3. 기본 언어: 한국어
4. 앱 또는 게임: 앱
5. 무료 또는 유료: 무료
6. 동의 및 앱 만들기

#### Step 3: 앱 정보 입력
1. **앱 액세스 권한**: 모든 기능 사용 가능 (선택)
2. **광고**: 광고 없음 (선택)
3. **앱 카테고리**: 엔터테인먼트 또는 도구
4. **대상 고객**: 모든 연령대

#### Step 4: 스토어 등록 정보
1. **앱 이름**: Roulette Lotto
2. **간단한 설명** (최대 80자):
   ```
   로또 번호를 재미있게 뽑는 룰렛 게임 앱! 무지개 색상의 룰렛을 돌려 번호를 선택하고, 통계를 확인하며 나만의 로또 번호를 관리하세요.
   ```

3. **자세한 설명** (최대 4000자):
   - `APP_STORE_DESCRIPTION.md` 파일의 "자세한 설명" 섹션 내용 사용

4. **앱 아이콘**: `assets/app_icon.png` (512x512px 권장)
5. **기능 그래픽** (선택): 스크린샷 2-8장
6. **스크린샷** (필수):
   - 최소 2장 (최대 8장)
   - 권장 해상도: 1080x1920px (세로) 또는 1920x1080px (가로)
   - 실제 앱 화면 캡처

#### Step 5: 앱 번들 업로드
1. 왼쪽 메뉴에서 "프로덕션" 또는 "내부 테스트" 선택
2. "새 버전 만들기" 클릭
3. "앱 번들 업로드" 클릭
4. `build/app/outputs/bundle/release/app-release.aab` 파일 선택
5. 업로드 완료 대기

#### Step 6: 출시 정보 입력
1. **출시 이름**: 1.0.0 (선택)
2. **출시 노트**: 
   ```
   첫 출시 버전
   - 룰렛 게임으로 로또 번호 선택
   - 풍선 게임으로 재미있게 번호 선택
   - 번호 저장 및 통계 기능
   ```

#### Step 7: 검토 제출
1. 모든 필수 정보 입력 확인
2. "검토 제출" 클릭
3. 검토 완료까지 1-3일 소요

---

## 🍎 Apple App Store 배포

### 1. 준비 사항
- Apple Developer 계정 필요 (연간 $99)
- Xcode 설치 필요
- 앱 서명 인증서 설정

### 2. 배포 단계

#### Step 1: App Store Connect 접속
1. [App Store Connect](https://appstoreconnect.apple.com)에 로그인
2. Apple Developer 계정으로 로그인

#### Step 2: 새 앱 생성
1. "내 앱" → "+" 버튼 클릭
2. **플랫폼**: iOS
3. **이름**: Roulette Lotto
4. **기본 언어**: 한국어
5. **번들 ID**: `com.jysoft.roulettelotto.app` (Xcode에서 생성 필요)
6. **SKU**: `roulette-lotto-001` (고유 식별자)
7. **사용자 액세스**: 전체 액세스
8. "만들기" 클릭

#### Step 3: 앱 정보 입력
1. **카테고리**: 
   - 주 카테고리: 엔터테인먼트
   - 부 카테고리: 도구 (선택)

2. **가격 및 판매**: 무료

3. **개인정보 보호 정책 URL** (필수):
   - 개인정보 보호 정책 페이지 URL 필요
   - 예: https://yourwebsite.com/privacy

#### Step 4: 스토어 등록 정보
1. **이름**: Roulette Lotto
2. **부제목** (선택): 재미있는 로또 번호 생성기
3. **프로모션 텍스트** (선택)
4. **설명**:
   - `APP_STORE_DESCRIPTION.md` 파일의 "자세한 설명" 섹션 내용 사용

5. **키워드**: 로또, 룰렛, 번호 생성, 게임, 통계
6. **지원 URL**: https://yourwebsite.com (필수)
7. **마케팅 URL** (선택)

#### Step 5: 스크린샷 및 미리보기
1. **스크린샷** (필수):
   - iPhone 6.7" (iPhone 14 Pro Max): 최소 1장
   - iPhone 6.5" (iPhone 11 Pro Max): 최소 1장
   - 권장: 각 크기별 3-10장
   - 실제 앱 화면 캡처

2. **앱 미리보기** (선택): 동영상

3. **앱 아이콘**: `assets/app_icon.png` (1024x1024px)

#### Step 6: IPA 파일 업로드
1. Xcode에서 아카이브 생성:
   ```bash
   flutter build ipa --release
   ```

2. **방법 1: Xcode 사용**
   - Xcode 열기
   - Product → Archive
   - "Distribute App" 클릭
   - "App Store Connect" 선택
   - 업로드 진행

3. **방법 2: Transporter 앱 사용**
   - [Transporter 앱](https://apps.apple.com/us/app/transporter/id1450874784) 다운로드
   - `build/ios/ipa/*.ipa` 파일 드래그 앤 드롭
   - 업로드 진행

#### Step 7: 빌드 선택 및 제출
1. App Store Connect에서 "버전" 탭
2. "빌드" 섹션에서 업로드된 빌드 선택
3. "저장" 클릭
4. "검토를 위해 제출" 클릭
5. 검토 완료까지 1-7일 소요

---

## ⚠️ 중요 사항

### 키스토어 백업 (Android)
- **위치**: `android/key/roulette-lotto-key.jks`
- **비밀번호**: roulette2024
- **별칭**: roulette-lotto
- ⚠️ **이 파일을 잃어버리면 앱 업데이트 불가능!**
- 안전한 곳에 백업 필수!

### 개인정보 보호 정책 (iOS 필수)
- App Store Connect에 개인정보 보호 정책 URL 필수
- 웹사이트에 개인정보 보호 정책 페이지 생성 필요
- 예시:
  ```
  https://yourwebsite.com/privacy
  ```

### 스크린샷 준비
- 실제 앱을 실행하여 스크린샷 촬영
- 각 플랫폼별 요구사항에 맞는 해상도 준비
- 앱의 주요 기능을 보여주는 스크린샷 권장

### 테스트
- 배포 전 실제 기기에서 테스트 권장
- 모든 기능이 정상 작동하는지 확인

---

## 📝 체크리스트

### Google Play Store
- [ ] Google Play Console 계정 생성
- [ ] 앱 번들 파일 준비 (`app-release.aab`)
- [ ] 앱 아이콘 준비 (512x512px)
- [ ] 스크린샷 준비 (최소 2장)
- [ ] 앱 설명 작성
- [ ] 키스토어 백업
- [ ] 앱 번들 업로드
- [ ] 검토 제출

### Apple App Store
- [ ] Apple Developer 계정 ($99/년)
- [ ] App Store Connect 계정
- [ ] Bundle ID 등록 (`com.jysoft.roulettelotto.app`)
- [ ] 개인정보 보호 정책 URL 준비
- [ ] 앱 아이콘 준비 (1024x1024px)
- [ ] 스크린샷 준비 (각 기기별)
- [ ] IPA 파일 생성 및 업로드
- [ ] 검토 제출

---

## 🚀 빠른 시작 명령어

### Android App Bundle 재생성
```bash
flutter clean
flutter build appbundle --release
```

### iOS IPA 재생성
```bash
flutter clean
flutter build ipa --release
```

---

## 📞 도움이 필요하신가요?

- [Google Play Console 도움말](https://support.google.com/googleplay/android-developer)
- [App Store Connect 도움말](https://help.apple.com/app-store-connect/)
- [Flutter 배포 가이드](https://docs.flutter.dev/deployment)

