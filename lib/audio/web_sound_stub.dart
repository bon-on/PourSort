/// Non-web builds play sounds through the native shell audio channel.
class WebSound {
  void play(String assetKey, double volume) {}

  Future<bool> loop(String assetKey, double volume) async => false;

  void stopLoop() {}

  void pauseLoop() {}

  Future<bool> resumeLoop() async => false;
}
