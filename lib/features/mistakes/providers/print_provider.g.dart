// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'print_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$selectionNotifierHash() => r'6fe02e50ef32196d92f9680bdc4ebeefff148dbb';

/// 選取模式 Notifier
///
/// Copied from [SelectionNotifier].
@ProviderFor(SelectionNotifier)
final selectionNotifierProvider =
    AutoDisposeNotifierProvider<SelectionNotifier, SelectionState>.internal(
  SelectionNotifier.new,
  name: r'selectionNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectionNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SelectionNotifier = AutoDisposeNotifier<SelectionState>;
String _$printSettingsNotifierHash() =>
    r'efe3c9e66fb5752ffbc4b2787b05912c4b04fe58';

/// 列印設定 Notifier
///
/// Copied from [PrintSettingsNotifier].
@ProviderFor(PrintSettingsNotifier)
final printSettingsNotifierProvider =
    AutoDisposeNotifierProvider<PrintSettingsNotifier, PrintSettings>.internal(
  PrintSettingsNotifier.new,
  name: r'printSettingsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$printSettingsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PrintSettingsNotifier = AutoDisposeNotifier<PrintSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
