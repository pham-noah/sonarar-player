library;

import 'dart:io';

import 'package:flutter/services.dart';

enum StorageAccess { granted, denied, unknown }

class StoragePermission {
  static const MethodChannel _channel = MethodChannel('personar/storage');

  static Future<StorageAccess> status() async {
    if (!Platform.isAndroid) return StorageAccess.unknown;
    try {
      final raw = await _channel.invokeMethod<String>('status');
      return _parse(raw);
    } on PlatformException {
      return StorageAccess.unknown;
    } on MissingPluginException {
      return StorageAccess.unknown;
    }
  }

  static Future<StorageAccess> request() async {
    if (!Platform.isAndroid) return StorageAccess.unknown;
    try {
      final raw = await _channel.invokeMethod<String>('request');
      return _parse(raw);
    } on PlatformException {
      return StorageAccess.unknown;
    } on MissingPluginException {
      return StorageAccess.unknown;
    }
  }

  static Future<StorageAccess> notificationStatus() async {
    if (!Platform.isAndroid) return StorageAccess.unknown;
    try {
      return _parse(await _channel.invokeMethod<String>('notificationStatus'));
    } on PlatformException {
      return StorageAccess.unknown;
    } on MissingPluginException {
      return StorageAccess.unknown;
    }
  }

  static Future<StorageAccess> requestNotification() async {
    if (!Platform.isAndroid) return StorageAccess.unknown;
    try {
      return _parse(await _channel.invokeMethod<String>('requestNotification'));
    } on PlatformException {
      return StorageAccess.unknown;
    } on MissingPluginException {
      return StorageAccess.unknown;
    }
  }

  static StorageAccess _parse(String? raw) => switch (raw) {
        'granted' => StorageAccess.granted,
        'denied' => StorageAccess.denied,
        _ => StorageAccess.unknown,
      };
}
