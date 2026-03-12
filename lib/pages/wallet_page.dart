import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/data/credits_repo.dart';
import '../bubble_library/providers/providers.dart';
import '../localization/app_language.dart';
import '../localization/app_language_provider.dart';
import '../localization/app_strings.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../ui/glass.dart';
import '../iap/credits_pack_store_sheet.dart';

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final lang = ref.watch(appLanguageProvider);
    String? uid;
    try {
      uid = ref.watch(uidProvider);
    } catch (_) {
      uid = null;
    }

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(uiString(lang, 'my_wallet')),
          backgroundColor: Colors.transparent,
          foregroundColor: tokens.textPrimary,
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: tokens.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    uiString(lang, 'sign_in_to_view_wallet'),
                    style: TextStyle(
                      fontSize: 18,
                      color: tokens.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final balanceAsync = ref.watch(creditsBalanceProvider);
    final transactionsAsync = ref.watch(creditTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(uiString(lang, 'my_wallet')),
        backgroundColor: Colors.transparent,
        foregroundColor: tokens.textPrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance card
            GlassCard(
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uiString(lang, 'balance'),
                    style: TextStyle(
                      fontSize: 14,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  balanceAsync.when(
                    data: (balance) => Text(
                      '$balance',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    loading: () => SizedBox(
                      height: 48,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: tokens.primary,
                          ),
                        ),
                      ),
                    ),
                    error: (e, _) => Text(
                      '—',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    uiString(lang, 'credits'),
                    style: TextStyle(
                      fontSize: 14,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        showCreditsPackStoreSheet(context, ref),
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(uiString(lang, 'buy_credits')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Transaction history
            Text(
              uiString(lang, 'transaction_history'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            transactionsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return GlassCard(
                    radius: 16,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          uiString(lang, 'no_transactions_yet'),
                          style: TextStyle(
                            fontSize: 14,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: list
                      .map((tx) => _TransactionTile(
                            transaction: tx,
                            tokens: tokens,
                            lang: lang,
                          ))
                      .toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => GlassCard(
                radius: 16,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      uiString(lang, 'could_not_load_transactions'),
                      style: TextStyle(
                        fontSize: 14,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final CreditTransaction transaction;
  final AppTokens tokens;
  final AppLanguage lang;

  const _TransactionTile({
    required this.transaction,
    required this.tokens,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = transaction.createdAt != null
        ? '${transaction.createdAt!.year}-${transaction.createdAt!.month.toString().padLeft(2, '0')}-${transaction.createdAt!.day.toString().padLeft(2, '0')} '
            '${transaction.createdAt!.hour.toString().padLeft(2, '0')}:${transaction.createdAt!.minute.toString().padLeft(2, '0')}'
        : '—';
    final typeLabel =
        transaction.type == 'add' ? uiString(lang, 'transaction_added') : uiString(lang, 'transaction_redeemed');
    final creditLabel = uiString(lang, 'credits');
    final amountLabel =
        '${transaction.type == 'add' ? '+' : '-'}${transaction.amount} $creditLabel';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                Text(
                  amountLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: transaction.type == 'add'
                        ? tokens.primary
                        : tokens.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 12,
                color: tokens.textSecondary,
              ),
            ),
            if (transaction.productId != null &&
                transaction.productId!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                transaction.productId!,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (transaction.balanceAfter != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${uiString(lang, 'balance_after')}${transaction.balanceAfter}',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
