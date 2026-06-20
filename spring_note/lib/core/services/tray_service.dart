import 'dart:io';

import 'package:flutter/services.dart';

import '../models/app_config.dart';

class TrayService {
  const TrayService([this._channel = const MethodChannel('spring_note/tray')]);

  final MethodChannel _channel;

  Future<void> sync(AppConfig config) async {
    if (!Platform.isWindows) {
      return;
    }

    final showTrayIcon = config.showTrayIcon;
    final closeToTray = showTrayIcon && config.closeToTray;
    try {
      await _channel.invokeMethod<void>('configure', {
        'showTrayIcon': showTrayIcon,
        'closeToTray': closeToTray,
      });
    } on PlatformException {
      // Tray integration is optional and Windows-only.
    }
  }

  Future<void> dispose() async {
    if (!Platform.isWindows) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('dispose');
    } on PlatformException {
      // Tray integration is optional and Windows-only.
    }
  }
}
