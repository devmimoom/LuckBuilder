// lib/widgets/unlock_feature_bar.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/providers/providers.dart';
import '../paywall/paywall_controller.dart';
import '../paywall/paywall_state.dart';

class UnlockProductBar extends ConsumerWidget {
  final String productId;   // ✅ 單一 IAP 的 id
  final String priceText;   // 例如 NT$79
  final VoidCallback? onUnlocked; // ✅ 解鎖成功後要做的事（例如開啟詳情/加入購買）

  const UnlockProductBar({
    super.key,
    required this.productId,
    required this.priceText,
    this.onUnlocked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paywallControllerProvider(productId));
    final libAsync = ref.watch(libraryProductsProvider);
    final ctrl = ref.read(paywallControllerProvider(productId).notifier);

    final isPurchasing = state.status == PaywallStatus.purchasing;
    final paywallUnlocked = state.status == PaywallStatus.unlocked;
    final inLibrary = libAsync.valueOrNull?.any((lp) =>
        lp.productId == productId && !lp.isHidden) ?? false;
    final isUnlocked = paywallUnlocked || inLibrary;

    final title = isUnlocked
        ? 'Product unlocked'
        : switch (state.status) {
            PaywallStatus.purchasing => 'Processing…',
            PaywallStatus.error => 'Purchase not completed',
            _ => 'Unlock this product',
          };

    final subtitle = isUnlocked
        ? 'View full details and add to banner learning'
        : switch (state.status) {
            PaywallStatus.purchasing => 'Confirming with App Store',
            PaywallStatus.error => state.errorMessage ?? 'Try again or use Restore',
            _ => 'After purchase: full details and banner notifications',
          };

    final buttonText = isUnlocked
        ? 'Start learning'
        : switch (state.status) {
            PaywallStatus.purchasing => 'Processing…',
            PaywallStatus.error => 'Try again',
            _ => '$priceText Buy now',
          };

    final onPressed = isPurchasing
        ? null
        : () async {
            if (isUnlocked) {
              onUnlocked?.call();
              return;
            }
            await ctrl.purchase();
            // 如果購買成功，呼叫 callback（例如把產品加入已購買、開啟推播）
            final latest = ref.read(paywallControllerProvider(productId));
            if (latest.status == PaywallStatus.unlocked) {
              onUnlocked?.call();
            }
          };

    return _NeonGlassBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // 左側文案
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha:0.95),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.25,
                          color: Colors.white.withValues(alpha:0.72),
                        ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: isPurchasing ? null : ctrl.restore,
                    child: Text(
                      'Restore purchases',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha:0.70),
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withValues(alpha:0.35),
                          ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // 右側膠囊按鈕
            _CapsuleButton(
              text: buttonText,
              loading: isPurchasing,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

/// 霓虹玻璃底條（用 BackdropFilter 做 blur）
/// 不指定顏色 token 也能運作，若你已有 token 可替換。
class _NeonGlassBar extends StatelessWidget {
  final Widget child;
  const _NeonGlassBar({required this.child});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // 背後模糊
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(),
          ),

          // 霓虹漸層（青綠）+ 玻璃
          Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF2FE6D6).withValues(alpha:0.70),
                  const Color(0xFF25D8C8).withValues(alpha:0.55),
                  const Color(0xFF1EC7B7).withValues(alpha:0.45),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha:0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha:0.25),
                ),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback? onPressed;

  const _CapsuleButton({
    required this.text,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onPressed == null ? 0.72 : 1,
      child: GestureDetector(
        onTap: onPressed,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // blur 背景
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: Colors.white.withValues(alpha:0.16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha:0.20),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading) ...[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha:0.90),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      text,
                      style:
                          Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.white.withValues(alpha:0.95),
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
