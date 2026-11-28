// Run with: flutter test --platform chrome test/web
// GamePix selection: flutter test --platform chrome test/web \
//   --dart-define=GAMEPIX=true --dart-define=CRAZYGAMES=true
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pour_sort/platform/crazygames_platform.dart';
import 'package:pour_sort/platform/game_platform.dart';
import 'package:pour_sort/platform/game_platform_factory_web.dart'
    show selectGamePlatform;
import 'package:pour_sort/platform/gamepix_platform.dart';

void main() {
  const gamePix = bool.fromEnvironment('GAMEPIX');
  const crazyGames = bool.fromEnvironment('CRAZYGAMES');

  test('platform selection follows the build flags', () {
    final platform = createGamePlatform();
    if (gamePix) {
      // GAMEPIX wins even when CRAZYGAMES is also set.
      expect(platform, isA<GamePixPlatform>());
      expect(platform, isNot(isA<CrazyGamesPlatform>()));
    } else if (crazyGames) {
      expect(platform, isA<CrazyGamesPlatform>());
    } else {
      expect(platform, isA<NoopGamePlatform>());
    }
  });

  test('selectGamePlatform picks the adapter for each flag', () {
    expect(
      selectGamePlatform(crazyGames: false, gamePix: false),
      isA<NoopGamePlatform>(),
    );
    expect(
      selectGamePlatform(crazyGames: true, gamePix: false),
      isA<CrazyGamesPlatform>(),
    );
    expect(
      selectGamePlatform(crazyGames: false, gamePix: true),
      isA<GamePixPlatform>(),
    );
    expect(
      selectGamePlatform(crazyGames: true, gamePix: true),
      isA<GamePixPlatform>(),
    );
  });

  test('portal platforms register no results and keep ads to break ads', () {
    final platform = createGamePlatform();
    expect(platform.allowsResultRegistration, isFalse);
    expect(platform.allowsAds, isFalse);
  });
}
