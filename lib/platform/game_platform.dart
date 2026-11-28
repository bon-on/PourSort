import 'game_platform_factory_stub.dart'
    if (dart.library.js_interop) 'game_platform_factory_web.dart'
    as platform_factory;

/// Hooks a distribution portal needs from the game loop.
///
/// Mobile and plain web builds use [NoopGamePlatform]; CrazyGames web builds
/// (`--dart-define=CRAZYGAMES=true`) use the SDK-backed implementation.
/// GamePix web builds (`--dart-define=GAMEPIX=true`) use the GamePix SDK
/// adapter (feature-gamepix-sdk).
abstract class GamePlatform {
  const GamePlatform();

  /// Legacy flag: the game itself never shows ads. Portal ads go through
  /// [showRunBreakAd] only, at breaks between levels.
  bool get allowsAds => false;

  /// Whether finished results may be sent to an external service. This game
  /// has no leaderboard or result upload; kept false for the same reason.
  bool get allowsResultRegistration => false;

  /// Whether the portal asks the game to stay silent (CrazyGames SDK
  /// `settings.muteAudio`). Combined with the player's own mute toggle.
  bool get isAudioMuted => false;

  /// Registers a callback for [isAudioMuted] changes (null clears it), so the
  /// music can stop or resume at once. The no-op platform never calls it.
  void setAudioMuteListener(void Function()? listener) {}

  /// Whether [showRunBreakAd] may show an ad, so callers only wait for it on
  /// such platforms (feature-gamepix-sdk).
  bool get showsRunBreakAds => false;

  /// Shows an ad between levels. Completes when the ad ends, fails or is
  /// skipped (cooldown), so callers can always continue afterwards.
  Future<void> showRunBreakAd() async {}

  /// Prepares the portal SDK. Never throws; failures downgrade to no-op.
  Future<void> initialize();

  /// The player is actively playing (no overlay, level not cleared).
  void gameplayStart();

  /// The player stopped playing (overlay open, level cleared).
  void gameplayStop();
}

class NoopGamePlatform extends GamePlatform {
  const NoopGamePlatform();

  @override
  Future<void> initialize() async {}

  @override
  void gameplayStart() {}

  @override
  void gameplayStop() {}
}

GamePlatform createGamePlatform() => platform_factory.createGamePlatform();
