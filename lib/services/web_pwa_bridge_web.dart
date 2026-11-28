import 'dart:js_interop';

@JS('orderDeskPwa.canInstall')
external JSBoolean? _jsCanInstall();

@JS('orderDeskPwa.isStandalone')
external JSBoolean? _jsIsStandalone();

@JS('orderDeskPwa.isIos')
external JSBoolean? _jsIsIos();

@JS('orderDeskPwa.promptInstall')
external JSPromise<JSString>? _jsPromptInstall();

@JS('orderDeskPwa.reloadWithFreshCache')
external void _jsReloadWithFreshCache();

@JS('orderDeskPwa.openExternalUrl')
external JSBoolean? _jsOpenExternalUrl(JSString url);

class WebPwaBridge {
  static bool canInstallPwa() {
    try {
      return _jsCanInstall()?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  static bool isStandalone() {
    try {
      return _jsIsStandalone()?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  static bool isIosSafari() {
    try {
      return _jsIsIos()?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> promptPwaInstall() async {
    try {
      final promise = _jsPromptInstall();
      if (promise == null) return 'unavailable';
      final result = await promise.toDart;
      return result.toDart;
    } catch (_) {
      return 'unavailable';
    }
  }

  static void reloadWithFreshCache() {
    try {
      _jsReloadWithFreshCache();
    } catch (_) {}
  }

  static bool openExternalUrl(String url) {
    try {
      return _jsOpenExternalUrl(url.toJS)?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }
}
