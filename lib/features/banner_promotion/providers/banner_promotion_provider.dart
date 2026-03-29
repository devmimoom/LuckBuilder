import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/banner_catalog.dart';

final bannerCatalogProvider = FutureProvider<BannerCatalog>((ref) async {
  final raw =
      await rootBundle.loadString('assets/data/banner_catalog.json');
  final map = json.decode(raw) as Map<String, dynamic>;
  return BannerCatalog.fromJson(map);
});
