import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/src/nfc_manager_android/pigeon.g.dart';

class NfcService {
  static Future<bool> isAvailable() async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return availability == NfcAvailability.enabled;
    } catch (e) {
      return false;
    }
  }

  static Future<void> startReading({
    required Function(String uid) onRead,
    required Function(String error) onError,
  }) async {
    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final uid = _extractUid(tag);
            if (uid != null) {
              onRead(uid);
            } else {
              onError('Could not read card UID.');
            }
          } catch (e) {
            onError('Error reading card: $e');
          }
        },
      );
    } catch (e) {
      onError('NFC session error: $e');
    }
  }

  static Future<void> stopReading() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      // ignore
    }
  }

  static String? _extractUid(NfcTag tag) {
    try {
      // In nfc_manager 4.x, tag.data is a TagPigeon which has an `id` field
      final tagData = tag.data as TagPigeon;
      final id = tagData.id;
      return id
          .map((e) => e.toRadixString(16).padLeft(2, '0'))
          .join(':')
          .toUpperCase();
    } catch (e) {
      return null;
    }
  }
}