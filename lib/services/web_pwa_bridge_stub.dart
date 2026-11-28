class WebPwaBridge {
  static bool canInstallPwa() => false;

  static bool isStandalone() => false;

  static bool isIosSafari() => false;

  static Future<String> promptPwaInstall() async => 'unavailable';

  static void reloadWithFreshCache() {}

  static bool openExternalUrl(String url) => false;
}
