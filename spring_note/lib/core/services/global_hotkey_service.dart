import 'dart:io';

import 'package:flutter/services.dart';

class GlobalHotkeyService {
  const GlobalHotkeyService([
    this._channel = const MethodChannel('spring_note/global_hotkeys'),
  ]);

  final MethodChannel _channel;

  Future<bool> setToggleWindowHotkey(String? hotkey) async {
    if (!Platform.isWindows) {
      return false;
    }

    final normalized = hotkey?.trim() ?? '';
    if (normalized.isEmpty) {
      await unregisterToggleWindowHotkey();
      return true;
    }

    try {
      return await _channel.invokeMethod<bool>(
            'setToggleWindowHotkey',
            normalized,
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> unregisterToggleWindowHotkey() async {
    if (!Platform.isWindows) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('unregisterToggleWindowHotkey');
    } on PlatformException {
      // Global hotkeys are an optional native integration.
    }
  }
}
