import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../bubble_library/providers/providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../ui/glass.dart';
import 'credits_iap_service.dart';
import '../localization/app_language_provider.dart';
import '../localization/app_language.dart';
import '../localization/app_strings.dart';

/// 額度包商店：1 / 3 / 10 額度，購買後寫入 Firestore
void showCreditsPackStoreSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusMd)),
        ),
        child: _CreditsPackStoreSheet(ref: ref, scrollController: controller),
      ),
    ),
  );
}

class _CreditsPackStoreSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final ScrollController scrollController;

  const _CreditsPackStoreSheet({
    required this.ref,
    required this.scrollController,
  });

  @override
  ConsumerState<_CreditsPackStoreSheet> createState() =>
      _CreditsPackStoreSheetState();
}

class _CreditsPackStoreSheetState extends ConsumerState<_CreditsPackStoreSheet> {
  List<StoreProduct> _products = [];
  bool _loading = true;
  String? _purchasingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await CreditsIAPService.getCreditProducts();
    // Sort by credits (1, 3, 10)
    products.sort((a, b) {
      final creditsA = creditsForProductId(a.identifier);
      final creditsB = creditsForProductId(b.identifier);
      return creditsA.compareTo(creditsB);
    });
    if (mounted) setState(() => _products = products);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _purchase(StoreProduct product) async {
    final lang = widget.ref.read(appLanguageProvider);
    String? uid;
    try {
      uid = widget.ref.read(uidProvider);
    } catch (_) {
      uid = null;
    }
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uiString(lang, 'sign_in_purchase_credits')),
          ),
        );
      }
      return;
    }
    setState(() => _purchasingId = product.identifier);
    try {
      if (kDebugMode) {
        debugPrint('[Store] Starting purchase: ${product.identifier}, uid=$uid');
      }
      final credits = await CreditsIAPService.purchase(product);
      if (kDebugMode) {
        debugPrint('[Store] Purchase returned $credits credits, writing to Firestore...');
      }
      if (credits > 0) {
        await widget.ref
            .read(creditsRepoProvider)
            .addCredits(uid, credits, sourceProductId: product.identifier);
        if (kDebugMode) {
          debugPrint('[Store] Firestore write complete, invalidating provider...');
        }
        widget.ref.invalidate(creditsBalanceProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(uiString(lang, 'added_credits')
                  .replaceFirst('{n}', '$credits')),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        // credits == 0 意味著 product.identifier 不在 _productIdToCredits 映射中
        if (kDebugMode) {
          debugPrint('[Store] WARNING: credits=0 for ${product.identifier}! Product ID not mapped.');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(uiString(lang, 'purchase_unrecognized')
                  .replaceFirst('{id}', product.identifier)),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Store] Purchase error: $e');
        debugPrint('[Store] Error type: ${e.runtimeType}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_userFriendlyPurchaseErrorMessage(e)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lang = widget.ref.watch(appLanguageProvider);
    if (_loading) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: tokens.primary)),
        ),
      );
    }
    if (_products.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: tokens.textSecondary),
              const SizedBox(height: AppSpacing.sm),
              Text(
                uiString(lang, 'no_credit_packs'),
                style: TextStyle(fontSize: 16, color: tokens.textSecondary),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(uiString(lang, 'close')),
              ),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Icon(Icons.stars_rounded, size: 28, color: tokens.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                uiString(lang, 'credits_title'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            uiString(lang, 'credits_use_hint'),
            style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          ..._products.map((p) {
            final credits = creditsForProductId(p.identifier);
            final loading = _purchasingId == p.identifier;
            final perCreditPrice = _calculatePerCreditPrice(p.price, credits);
            final isMostPopular = credits == 3;
            final isBestValue = credits == 10;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GlassCard(
                radius: 16,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: tokens.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: Center(
                                  child: Text(
                                    '$credits',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      uiString(lang, 'credits_label')
                                          .replaceFirst('{n}', '$credits'),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      uiString(lang, 'per_credit_price')
                                          .replaceFirst('{price}', perCreditPrice),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              loading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: tokens.primary,
                                      ),
                                    )
                                  : FilledButton(
                                      onPressed: () => _purchase(p),
                                      child: Text(
                                        p.priceString,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isMostPopular || isBestValue)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: tokens.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isBestValue
                                ? uiString(lang, 'credits_best_value')
                                : uiString(lang, 'credits_most_popular'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(uiString(lang, 'close')),
          ),
        ],
      ),
    );
  }

  String _calculatePerCreditPrice(double totalPrice, int credits) {
    if (credits == 0) return '\$0.00';
    final perCredit = totalPrice / credits;
    return '\$${perCredit.toStringAsFixed(2)}';
  }
}

/// 將購買錯誤轉成使用者可讀訊息，避免顯示整段 PlatformException。
String _userFriendlyPurchaseErrorMessage(dynamic e) {
  if (e is PlatformException) {
    final code = e.details is Map
        ? (e.details as Map)['readableErrorCode']?.toString()
        : null;
    final userCancelled = e.details is Map
        ? (e.details as Map)['userCancelled'] == true
        : false;
    if (userCancelled) {
      return uiString(detectSystemLanguage(), 'purchase_cancelled');
    }
    if (code == 'INVALID_RECEIPT' ||
        (e.message ?? '').toLowerCase().contains('receipt is not valid')) {
      return uiString(detectSystemLanguage(), 'receipt_invalid');
    }
    if (code != null && code.isNotEmpty) {
      return uiString(detectSystemLanguage(), 'purchase_failed_code')
          .replaceFirst('{code}', code);
    }
  }
  return uiString(detectSystemLanguage(), 'purchase_failed_generic');
}
