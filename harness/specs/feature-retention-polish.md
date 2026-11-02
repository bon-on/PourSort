---
id: feature-retention-polish
title: PourSort 시각 개편, 붓기 연출, 재플레이 동기(별점, 레벨 선택, 플레이어 레벨과 테마)
status: active
owner: games
related_adrs:
  - adr-pour-sort-solvable-levels
  - adr-pour-sort-crazygames-web
related_contracts:
  - contract-pour-sort-mvp
  - contract-pour-sort-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - portal-builds
  - harness-audit
---

# 기능 명세: PourSort 시각 개편, 붓기 연출, 재플레이 동기

## Problem
CrazyGames가 같은 시리즈의 MergeCamp를 "The overall quality of the game does not yet meet the expectations of our
platform"으로 거절했다. PourSort도 반투명 사각형 튜브와 단색 막대, 기본 Material 카드뿐이라 시제품처럼 보인다.
붓기 연출은 튜브가 살짝 기울고 칸 높이가 바뀌는 정도라 손맛이 약하고, 배경음악이 없다.
진행도는 "현재 레벨" 정수 하나뿐이라 깬 레벨을 다시 할 이유(별점, 수집, 성장)가 없다.

## Scope
1. 시각 개편(외부 에셋, 패키지 없음, `CustomPainter`)
   - 광택 유리 튜브: 입구 립, 유리 그라데이션, 세로 하이라이트와 반사점, 윤곽선. 액체는 칸마다 위아래 음영이 있는
     그라데이션이고 맨 위 표면은 출렁이는(wobble) 곡선이다. 색마다 고유 기호는 그대로 유지한다(색각 보조).
   - 테마 4종(꾸미기 전용, 규칙 무관): Lab(기본, Lv1), Potion Shop(Lv3), Candy(Lv6), Night Bar(Lv10).
     테마마다 배경 풍경(실험실 타일과 선반, 물약 가게 나무 선반과 촛불, 사탕 줄무늬와 막대사탕, 밤 바의 네온과 보케),
     튜브 받침, 패널 색, 강조색이 달라진다. 액체 색은 가독성을 위해 테마와 무관하게 같다.
   - 넓은 화면(가로가 세로의 1.25배 이상이고 700px 이상)은 가운데 보드와 좌우 패널(레벨, 수, 파, 별 목표, 최고 기록 /
     플레이어 레벨, XP 바, 총 별, 레벨 선택, 테마), 좁은 화면은 위 HUD, 보드, 아래 버튼 줄로 쌓는다.
     390x844, 1280x720, 1366x768, 844x390, 320x640에서 오버플로가 없어야 한다.
2. 붓기 연출(입력을 막지 않음)
   - 규칙은 즉시 적용되고 연출은 뒤따른다. 붓는 튜브가 들려 대상 튜브 옆 위로 날아가 대상 쪽으로 기울고, 입구에서
     대상 액면까지 호를 그리는 물줄기가 흐르며, 원래 튜브 액면은 내려가고 대상 액면은 올라간 뒤 제자리로 돌아온다.
     기울어진 튜브 안의 액면은 화면 기준 수평을 유지한다.
   - 선택한 튜브는 부드럽게 들리고 액면이 출렁인다. 받는 튜브도 출렁이고 거품 입자가 오른다.
   - 한 색으로 가득 찬 튜브는 코르크가 떨어져 꽂히고 반짝이 입자와 "Sorted!" 팝업이 나온다. 연속 두 번의 붓기로
     튜브를 완성하면 "Combo x2" 배너를 보인다.
   - 더 이상 가능한 붓기가 없으면(승리 전) "No moves left" 경고 배너로 되돌리기/튜브 추가를 안내한다.
   - 클리어 시 색종이, 튜브가 차례로 튀는 축하 연출, 결과 카드의 별이 하나씩 찍힌다.
   - 같은 튜브가 걸린 새 붓기가 오면 이전 연출은 즉시 끝난다. 실행 취소, 재시작, 레벨 변경은 연출을 모두 지운다.
   - 연출은 하나의 Ticker로 돌고 남은 연출이 없으면 멈춘다(페인터만 다시 그린다).
3. 별점(판 안의 목표)
   - 파(par)는 레벨 생성기가 이미 계산한 해답 길이(`Level.solutionLength`, 최적의 상한)다. 검증 실패 레벨(-1)은
     `colors * 3`을 쓴다. 레벨 생성은 바꾸지 않는다. 파는 "최적 수"가 아니므로 화면에 "Par"로만 표기한다.
   - 별: 수 <= 파면 3개, 수 <= 파 + max(3, ceil(파 * 0.3))이면 2개, 아니면 1개. 추가 튜브를 쓰면 최대 2개.
   - HUD에 현재 수에서 받을 별(별 미터)과 그 레벨의 최고 기록(최소 수, 최고 별)을 보여준다.
4. 판 사이의 동기: 결과 카드, 레벨 선택, 플레이어 레벨과 테마
   - 결과 카드: "Level complete!", 별, 수와 파, 최고 기록과 "New best!", 획득 XP, 레벨 진행 바, 레벨 업과 새로 열린
     테마, Next level(Enter/N/Esc), Replay(R), Levels 버튼. 다음 레벨은 대기, 일일 제한 없이 한 번에 넘어간다.
   - 레벨 선택: 열린 레벨(최고 도달 레벨까지)을 별과 함께 격자로 보여주고 아무 열린 레벨이나 다시 할 수 있다. 잠긴
     레벨은 자물쇠로 보인다. 다시 깬 레벨은 더 좋은 별/수만 갱신한다. 방향키로 이동, Enter로 시작, Esc로 닫는다(L 키).
   - 플레이어 레벨(XP): 처음 깨면 25 + 별당 15 XP, 다시 깨면 5 + 늘어난 별당 15 XP. L에서 L+1까지 100 + 40*(L-1) XP.
     테마 선택 창(P 키)에서 열린 테마만 고를 수 있고, 방향키/Enter/Esc로 조작한다.
   - 저장: `shared_preferences` 키 `pour_sort.progress_v1`(JSON: 마지막 레벨, 최고 도달 레벨, 레벨별 별과 최소 수,
     총 XP, 선택 테마). 새 키가 없고 기존 키 `pour_sort.level`(정수 L)이 있으면 이관한다: 마지막 레벨과 최고 도달
     레벨은 L, 1..L-1은 깬 레벨(별 정보가 없으므로 별 1개로 표시), XP는 깬 레벨마다 1별 첫 클리어 몫(40)을 준다.
     기존 키는 지우지 않고 마지막 레벨을 계속 기록한다(되돌리기 대비). 손상, 누락, 읽기/쓰기 실패는 기본값으로
     대체하고 플레이를 막지 않는다. 저장값을 읽기 전에는 저장하지 않는다(진행도 로드 전에는 입력이 막혀 있다).
5. 소리
   - 거품이 보글거리는 느긋한 배경음악 루프(코드 합성, 16000 Hz 모노 16비트, 1 MB 이하, 이음새 없는 루프)를
     `tool/generate_sounds.py`에 추가한다. 새 효과음: `cork`(튜브 완성), `level_up`(플레이어 레벨 업),
     `unlock`(레벨 선택/테마 선택 확인 클릭).
   - 음악은 웹에서 첫 사용자 입력 뒤 시작, 앱/탭이 숨겨지면 멈춘다. 사용자 소리 토글 하나가 효과음과 음악을 모두
     끄고, CrazyGames `muteAudio` 설정과 변경 리스너를 따른다. 이 게임에는 광고가 없다(광고 흐름 없음).
     iOS(AVAudioPlayer `numberOfLoops = -1`, 중단 후 재개)와 Android(MediaPlayer `isLooping`)에 `startLoop`/`stopLoop`.
   - 효과음 훅: 기존 select/pour/invalid/level_clear는 그대로다. 튜브를 완성했지만 이기지 않은 붓기는 pour 뒤에
     cork를 낸다. 클리어로 플레이어 레벨이 오르면 level_clear 뒤에 level_up을 낸다.

## Acceptance Criteria
- 튜브, 액체, 코르크, 4개 테마 배경이 코드로 그려지고 모든 색 x 테마 조합이 예외 없이 그려진다.
- 붓기 중에도 다음 탭/키가 즉시 처리되고(이동 수가 바로 바뀜), 연출이 끝나면 Ticker가 멈춘다(`pumpAndSettle` 종료).
- 별 계산과 파, XP 곡선, 테마 해금, 결과(신기록, 레벨 업, 새 테마), 진행도 JSON 왕복과 손상값 대체, 기존 키 이관이
  순수 Dart 단위 테스트로 검증된다.
- 결과 카드에 별, 수, 파, 최고 기록, XP, 레벨 바가 보이고 Next/Replay/Levels가 동작한다.
- 레벨 선택에서 열린 레벨을 고르면 그 레벨이 시작되고, 잠긴 레벨은 고를 수 없다. 별이 표시된다.
- 잠긴 테마는 고를 수 없고, 고른 테마는 다시 열어도 유지된다.
- 오버레이(튜토리얼, 결과, 레벨 선택, 테마)가 열려 있으면 보드 입력이 막히고 Esc/Enter로 닫히며,
  CrazyGames gameplayStart/Stop은 전환 때만 한 번씩 호출된다.
- 기존 키보드 조작(1-0, Q W E T Y I, U, R, A, Enter/N), 튜토리얼, 소리 토글, 색 기호가 유지되고 기존 테스트가 통과한다.
- 390x844, 1280x720, 1366x768, 844x390, 320x640에서 오버플로가 없다.

## Constraints
- 새 패키지 의존성 없음(`shared_preferences`만). 그림은 코드, 소리는 생성기.
- 규칙, 해답기, 레벨 생성은 바꾸지 않는다(ADR adr-pour-sort-solvable-levels). 별/XP 계산은 `lib/logic/`의
  Flutter 없는 순수 Dart다.
- lib/ 문자열은 영어 ASCII(GamePix 빌드 검사). GamePix는 외부 요청 없음. 웹 zip을 과도하게 키우지 않는다.
- 이 게임에는 리더보드/결과 등록이 없다(`allowsResultRegistration` false 유지).

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `python3 tool/generate_sounds.py` 두 번 실행 후 동일 shasum
- `flutter build web --release --base-href /PourSort/`, `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- 임시 골든 테스트로 1280x720, 390x844, 결과 카드, 테마별 그림 PNG 확인
- `node <harness-lab>/dist/index.js audit . --format md`
