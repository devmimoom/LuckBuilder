import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/providers/providers.dart';
import '../bubble_library/ui/bubble_library_page.dart';
import '../bubble_library/models/product.dart' as lib_product;
import '../bubble_library/models/user_library.dart';
import '../localization/app_language.dart';
import '../localization/app_language_provider.dart';
import '../localization/app_strings.dart';
import '../pages/product_page.dart';

/// Me 頁面的「我的圖書館」書架元件（僅此處使用的棕色世界觀）
class MeLibraryBookshelfSection extends ConsumerWidget {
  const MeLibraryBookshelfSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);

    // 未登入或匿名帳號：仍允許顯示書架（匿名帳號也會有 library）
    AsyncValue<List<UserLibraryProduct>> libAsync;
    try {
      // 若 uidProvider 拋錯代表尚未有可用 uid，直接顯示 loading 狀態
      // ignore: unused_local_variable
      final _ = ref.watch(uidProvider);
      libAsync = ref.watch(libraryProductsProvider);
    } catch (_) {
      libAsync = const AsyncValue.data(<UserLibraryProduct>[]);
    }

    final productsMapAsync = ref.watch(productsMapProvider);

    return libAsync.when(
      data: (lib) {
        return productsMapAsync.when(
          data: (productsMap) {
            // 過濾掉隱藏或缺產品定義的項目
            final purchased = lib.where((e) {
              if (e.isHidden) return false;
              return productsMap.containsKey(e.productId);
            }).toList();

            // 依最近開啟 / 購買時間排序，讓最近在看的排前面
            purchased.sort((a, b) {
              DateTime ta;
              DateTime tb;
              try {
                ta = a.lastOpenedAt ?? a.purchasedAt;
              } catch (_) {
                ta = a.purchasedAt;
              }
              try {
                tb = b.lastOpenedAt ?? b.purchasedAt;
              } catch (_) {
                tb = b.purchasedAt;
              }
              return tb.compareTo(ta);
            });

            if (purchased.isEmpty) {
              return _LibraryContainer(
                lang: lang,
                header: _LibraryHeader(onViewAll: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BubbleLibraryPage()),
                  );
                }),
                child: const _EmptyState(),
              );
            }

            // 將 library 資料轉成 UI 需要的結構（僅取前 8 本做彙總，前 4 本做書架）
            final visible = purchased.take(8).toList();
            final books = <_LibraryBook>[];
            const estimatedTotalPerProduct = 30; // 沒有精確卡片數時的保守估計

            for (var i = 0; i < visible.length; i++) {
              final lp = visible[i];
              final product = productsMap[lp.productId];
              if (product == null) continue;

              final displayTitle = product.displayTitle(lang);
              final readCount = lp.progress.learnedCount;
              const totalCount = estimatedTotalPerProduct;
              final progressPercent = totalCount == 0
                  ? 0
                  : ((readCount / totalCount) * 100).clamp(0, 100).round();

              final accentColor = _accentForTopic(product.topicId);

              books.add(_LibraryBook(
                libraryProduct: lp,
                product: product,
                displayTitle: displayTitle,
                emoji: _emojiForTopicId(product.topicId),
                readCount: readCount,
                totalCount: totalCount,
                progressPercent: progressPercent,
                accentColor: accentColor,
              ));
            }

            if (books.isEmpty) {
              return _LibraryContainer(
                lang: lang,
                header: _LibraryHeader(onViewAll: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BubbleLibraryPage()),
                  );
                }),
                child: const _EmptyState(),
              );
            }

            final totalRead =
                books.fold<int>(0, (sum, b) => sum + b.readCount);
            final totalCards =
                books.fold<int>(0, (sum, b) => sum + b.totalCount);
            final totalPercent = totalCards == 0
                ? 0
                : ((totalRead / totalCards) * 100).clamp(0, 100).round();
            final readingCount = books
                .where((b) => b.progressPercent > 0 && b.progressPercent < 100)
                .length;
            final unreadCount =
                books.where((b) => b.progressPercent == 0).length;

            return _LibraryContainer(
              lang: lang,
              header: _LibraryHeader(onViewAll: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BubbleLibraryPage()),
                );
              }),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReadingProgress(
                    lang: lang,
                    totalPercent: totalPercent,
                    totalRead: totalRead,
                    totalCards: totalCards,
                    readingCount: readingCount,
                    unreadCount: unreadCount,
                  ),
                  const SizedBox(height: 12),
                  _BookshelfRow(
                    books: books.take(4).toList(),
                    onTapBook: (book) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductPage(productId: book.product.id),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
          loading: () => _LibraryContainer(
            lang: lang,
            header: _LibraryHeader(onViewAll: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BubbleLibraryPage()),
              );
            }),
            child: const SizedBox(
              height: 72,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          error: (e, _) => _LibraryContainer(
            lang: lang,
            header: _LibraryHeader(onViewAll: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BubbleLibraryPage()),
              );
            }),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${uiString(lang, 'library_error')}$e',
                style: const TextStyle(
                  color: _libTextMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
      loading: () => _LibraryContainer(
        lang: lang,
        header: _LibraryHeader(onViewAll: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BubbleLibraryPage()),
          );
        }),
        child: const SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (e, _) => _LibraryContainer(
        lang: lang,
        header: _LibraryHeader(onViewAll: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BubbleLibraryPage()),
          );
        }),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '${uiString(lang, 'library_error')}$e',
            style: const TextStyle(
              color: _libTextMuted,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// Library 專用配色（僅此元件使用，不走全域 tokens）
const _libBg = Color(0xFF14120E);
const _libShelf = Color(0xFF2A2318);
const _libShelfEdge = Color(0xFF3A3020);
const _libBorder = Color.fromRGBO(160, 140, 100, 0.12);
const _libText = Color(0xFFE0D8C8);
const _libTextSub = Color(0xFF9A9080);
const _libTextMuted = Color(0xFF605848);
const _libGold = Color(0xFFC8A050);

const _spineColors = <Color>[
  Color(0xFF2D5A3D), // forest green
  Color(0xFF8B4513), // saddle brown
  Color(0xFF1A3A5C), // navy blue
  Color(0xFF4A3060), // plum purple
  Color(0xFF5A3A2A), // dark leather
  Color(0xFF2A4A4A), // teal dark
];

class _LibraryContainer extends StatelessWidget {
  const _LibraryContainer({
    required this.lang,
    required this.header,
    required this.child,
  });

  final AppLanguage lang;
  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: _libBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _libBorder),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.onViewAll});

  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final lang = ProviderScope.containerOf(context, listen: false)
        .read(appLanguageProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text('📚', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              uiString(lang, 'my_library'),
              style: const TextStyle(
                color: _libText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: _libGold,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                uiString(lang, 'view_all_label'),
                style: const TextStyle(
                  color: _libGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: _libGold,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadingProgress extends StatelessWidget {
  const _ReadingProgress({
    required this.lang,
    required this.totalPercent,
    required this.totalRead,
    required this.totalCards,
    required this.readingCount,
    required this.unreadCount,
  });

  final AppLanguage lang;
  final int totalPercent;
  final int totalRead;
  final int totalCards;
  final int readingCount;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final progress = totalPercent.clamp(0, 100);
    return Container(
      decoration: BoxDecoration(
        color: _libShelf,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _libBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Bookmark(percent: progress),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      uiString(lang, 'library_reading_progress_title'),
                      style: const TextStyle(
                        color: _libText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$totalRead/$totalCards',
                      style: const TextStyle(
                        color: _libGold,
                        fontSize: 10,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width =
                          constraints.maxWidth * (progress / 100.0).clamp(0, 1);
                      return Stack(
                        children: [
                          Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: _libGold.withValues(alpha: 0.1),
                            ),
                          ),
                          Container(
                            height: 5,
                            width: width,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFF8B7045),
                                  _libGold,
                                  Color(0xFFF5C04A),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$readingCount${uiString(lang, 'library_reading_suffix')}',
                      style: const TextStyle(
                        color: _libTextMuted,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$unreadCount${uiString(lang, 'library_unread_suffix')}',
                      style: const TextStyle(
                        color: _libTextMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bookmark extends StatelessWidget {
  const _Bookmark({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(28, 36),
            painter: _BookmarkPainter(),
          ),
          Positioned(
            top: 9,
            child: Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF14120E),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE8A838);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height * 0.8)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BookshelfRow extends StatelessWidget {
  const _BookshelfRow({
    required this.books,
    required this.onTapBook,
  });

  final List<_LibraryBook> books;
  final void Function(_LibraryBook book) onTapBook;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < books.length; i++) ...[
                Expanded(
                  child: _BookSpine(
                    book: books[i],
                    spineColor: _spineColors[i % _spineColors.length],
                    onTap: () => onTapBook(books[i]),
                  ),
                ),
                if (i != books.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _libShelfEdge,
                _libShelf,
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookSpine extends StatelessWidget {
  const _BookSpine({
    required this.book,
    required this.spineColor,
    required this.onTap,
  });

  final _LibraryBook book;
  final Color spineColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final height = 50.0 + (book.progressPercent.clamp(0, 100) * 0.5);
    final progressRatio = (book.progressPercent.clamp(0, 100) / 100.0)
        .clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: height,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: spineColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(3)),
              ),
              child: Stack(
                children: [
                  // 進度覆蓋層（由下往上）
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: progressRatio,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: book.accentColor.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 書脊內容
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 2),
                      Container(
                        width: 24,
                        height: 1,
                        color: _libGold.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 24,
                        height: 1,
                        color: _libGold.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _libText,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${book.progressPercent}%',
            style: TextStyle(
              color: book.progressPercent == 0
                  ? _libTextMuted
                  : book.accentColor,
              fontSize: 8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryBook {
  _LibraryBook({
    required this.libraryProduct,
    required this.product,
    required this.displayTitle,
    required this.emoji,
    required this.readCount,
    required this.totalCount,
    required this.progressPercent,
    required this.accentColor,
  });

  final UserLibraryProduct libraryProduct;
  final lib_product.Product product;
  final String displayTitle;
  final String emoji;
  final int readCount;
  final int totalCount;
  final int progressPercent;
  final Color accentColor;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final lang = ProviderScope.containerOf(context, listen: false)
        .read(appLanguageProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: _libShelf.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _libBorder),
            ),
            child: Center(
              child: Text(
                uiString(lang, 'library_empty_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _libTextSub,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            uiString(lang, 'library_empty_hint'),
            style: const TextStyle(
              color: _libTextMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

Color _accentForTopic(String topicId) {
  switch (topicId) {
    case 'habits':
      return const Color(0xFF4ADE80); // green
    case 'crypto':
      return const Color(0xFFF97316); // orange
    case 'ai':
      return const Color(0xFF60A5FA); // blue
    case 'sleep':
      return const Color(0xFFA855F7); // purple
    case 'emotion':
      return const Color(0xFFFB7185); // pink/red
    case 'finance':
      return const Color(0xFFFACC15); // yellow
    default:
      return _libGold;
  }
}

String _emojiForTopicId(String topicId) {
  switch (topicId) {
    case 'habits':
      return '🔄';
    case 'crypto':
      return '🪙';
    case 'ai':
      return '🤖';
    case 'sleep':
      return '🌙';
    case 'emotion':
      return '🌊';
    case 'finance':
      return '💰';
    case 'babydev':
      return '🍼';
    default:
      return '📘';
  }
}

