// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'solver_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$solverNotifierHash() => r'bd2ce15c3ef4efd9ae8432de5b56130261cbc5c7';

/// Riverpod AsyncNotifier：管理「OCR → Gemini → 結果」的完整流程
///
/// Copied from [SolverNotifier].
@ProviderFor(SolverNotifier)
final solverNotifierProvider =
    AutoDisposeNotifierProvider<SolverNotifier, SolverResult>.internal(
  SolverNotifier.new,
  name: r'solverNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$solverNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SolverNotifier = AutoDisposeNotifier<SolverResult>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
