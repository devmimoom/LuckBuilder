import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers/v2_providers.dart';

// ---------------------------------------------------------------------------
// Form State
// ---------------------------------------------------------------------------

class PlusGuideFormState {
  final int currentStep;
  final Segment? selectedSegment;
  final Topic? selectedTopic;
  final Product? selectedProduct;
  final List<String> presetSlots;
  final int freqPerDay;

  const PlusGuideFormState({
    this.currentStep = 0,
    this.selectedSegment,
    this.selectedTopic,
    this.selectedProduct,
    this.presetSlots = const ['21-23'],
    this.freqPerDay = 1,
  });

  PlusGuideFormState copyWith({
    int? currentStep,
    Object? selectedSegment = _sentinel,
    Object? selectedTopic = _sentinel,
    Object? selectedProduct = _sentinel,
    List<String>? presetSlots,
    int? freqPerDay,
  }) {
    return PlusGuideFormState(
      currentStep: currentStep ?? this.currentStep,
      selectedSegment: selectedSegment == _sentinel
          ? this.selectedSegment
          : selectedSegment as Segment?,
      selectedTopic: selectedTopic == _sentinel
          ? this.selectedTopic
          : selectedTopic as Topic?,
      selectedProduct: selectedProduct == _sentinel
          ? this.selectedProduct
          : selectedProduct as Product?,
      presetSlots: presetSlots ?? this.presetSlots,
      freqPerDay: freqPerDay ?? this.freqPerDay,
    );
  }
}

const _sentinel = Object();

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class PlusGuideNotifier extends StateNotifier<PlusGuideFormState> {
  PlusGuideNotifier() : super(const PlusGuideFormState());

  void goToStep(int step) =>
      state = state.copyWith(currentStep: step.clamp(0, 4));

  void nextStep() => goToStep(state.currentStep + 1);

  void prevStep() => goToStep(state.currentStep - 1);

  void selectSegment(Segment seg) => state = state.copyWith(
        selectedSegment: seg,
        selectedTopic: null,
        selectedProduct: null,
      );

  void selectTopic(Topic topic) => state = state.copyWith(
        selectedTopic: topic,
        selectedProduct: null,
      );

  void selectProduct(Product product) =>
      state = state.copyWith(selectedProduct: product);

  void setPresetSlots(List<String> slots) =>
      state = state.copyWith(presetSlots: slots.isEmpty ? ['21-23'] : slots);

  void setFreqPerDay(int freq) =>
      state = state.copyWith(freqPerDay: freq.clamp(1, 5));

  void reset() => state = const PlusGuideFormState();
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final plusGuideFormProvider =
    StateNotifierProvider<PlusGuideNotifier, PlusGuideFormState>(
  (ref) => PlusGuideNotifier(),
);

/// 取目前表單選中的 Segment 對應的主題列表
/// 完全不碰全域 selectedSegmentProvider，避免污染 Explore 的選取狀態
final plusGuideTopicsProvider = FutureProvider<List<Topic>>((ref) async {
  final seg = ref.watch(plusGuideFormProvider).selectedSegment;
  if (seg == null) return [];
  return ref.read(v2RepoProvider).fetchTopicsForSegment(seg);
});
