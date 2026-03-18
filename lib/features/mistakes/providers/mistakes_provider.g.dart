// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mistakes_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mistakeByIdHash() => r'93dd040748c23c426c9c9ba8bc4584021ce95acb';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [mistakeById].
@ProviderFor(mistakeById)
const mistakeByIdProvider = MistakeByIdFamily();

/// See also [mistakeById].
class MistakeByIdFamily extends Family<AsyncValue<Mistake?>> {
  /// See also [mistakeById].
  const MistakeByIdFamily();

  /// See also [mistakeById].
  MistakeByIdProvider call(
    int id,
  ) {
    return MistakeByIdProvider(
      id,
    );
  }

  @override
  MistakeByIdProvider getProviderOverride(
    covariant MistakeByIdProvider provider,
  ) {
    return call(
      provider.id,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'mistakeByIdProvider';
}

/// See also [mistakeById].
class MistakeByIdProvider extends AutoDisposeFutureProvider<Mistake?> {
  /// See also [mistakeById].
  MistakeByIdProvider(
    int id,
  ) : this._internal(
          (ref) => mistakeById(
            ref as MistakeByIdRef,
            id,
          ),
          from: mistakeByIdProvider,
          name: r'mistakeByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$mistakeByIdHash,
          dependencies: MistakeByIdFamily._dependencies,
          allTransitiveDependencies:
              MistakeByIdFamily._allTransitiveDependencies,
          id: id,
        );

  MistakeByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final int id;

  @override
  Override overrideWith(
    FutureOr<Mistake?> Function(MistakeByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MistakeByIdProvider._internal(
        (ref) => create(ref as MistakeByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Mistake?> createElement() {
    return _MistakeByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MistakeByIdProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MistakeByIdRef on AutoDisposeFutureProviderRef<Mistake?> {
  /// The parameter `id` of this provider.
  int get id;
}

class _MistakeByIdProviderElement
    extends AutoDisposeFutureProviderElement<Mistake?> with MistakeByIdRef {
  _MistakeByIdProviderElement(super.provider);

  @override
  int get id => (origin as MistakeByIdProvider).id;
}

String _$mistakeFiltersHash() => r'080fbb632acfc119f81b41ec65c2034358c6851c';

/// See also [MistakeFilters].
@ProviderFor(MistakeFilters)
final mistakeFiltersProvider =
    AutoDisposeNotifierProvider<MistakeFilters, Map<String, dynamic>>.internal(
  MistakeFilters.new,
  name: r'mistakeFiltersProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mistakeFiltersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MistakeFilters = AutoDisposeNotifier<Map<String, dynamic>>;
String _$mistakesHash() => r'bdd9a0b02b5260a6cd683d7fb3fa43ca44d8f663';

/// See also [Mistakes].
@ProviderFor(Mistakes)
final mistakesProvider =
    AutoDisposeAsyncNotifierProvider<Mistakes, List<Mistake>>.internal(
  Mistakes.new,
  name: r'mistakesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$mistakesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Mistakes = AutoDisposeAsyncNotifier<List<Mistake>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
