import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'user_profile_photo_path';

final userProfilePhotoPathProvider =
    StateNotifierProvider<UserProfilePhotoPathNotifier, String?>(
  (ref) => UserProfilePhotoPathNotifier(),
);

class UserProfilePhotoPathNotifier extends StateNotifier<String?> {
  UserProfilePhotoPathNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString(_prefsKey)?.trim();
      if (savedPath != null && savedPath.isNotEmpty && File(savedPath).existsSync()) {
        state = savedPath;
      } else {
        state = null;
      }
    } catch (_) {
      state = null;
    }
  }

  Future<void> setPhotoPath(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      await clear();
      return;
    }
    state = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, normalized);
    } catch (_) {
      // Keep in-memory value when persistence fails.
    }
  }

  Future<void> clear() async {
    final previous = state;
    state = null;
    if (previous != null && previous.isNotEmpty) {
      try {
        final f = File(previous);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {
      // Keep in-memory value when persistence fails.
    }
  }
}
