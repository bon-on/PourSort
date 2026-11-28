import 'crazygames_platform.dart';
import 'game_platform.dart';
import 'gamepix_platform.dart';

const bool _crazyGamesBuild = bool.fromEnvironment('CRAZYGAMES');
const bool _gamePixBuild = bool.fromEnvironment('GAMEPIX');

/// Same selection as [createGamePlatform] with the flags as arguments, for
/// tests. GamePix wins over CrazyGames (feature-gamepix-sdk).
GamePlatform selectGamePlatform({
  required bool crazyGames,
  required bool gamePix,
}) {
  if (gamePix) return GamePixPlatform();
  if (crazyGames) return CrazyGamesPlatform();
  return const NoopGamePlatform();
}

/// Written as a constant ternary (not a call to [selectGamePlatform]) so
/// dart2js folds the flags and drops the unused adapter from each bundle.
GamePlatform createGamePlatform() => _gamePixBuild
    ? GamePixPlatform()
    : _crazyGamesBuild
    ? CrazyGamesPlatform()
    : const NoopGamePlatform();
