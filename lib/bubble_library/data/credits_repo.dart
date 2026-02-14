import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_paths.dart';

/// 單筆額度交易紀錄（add / redeem）
class CreditTransaction {
  final String id;
  final String type;
  final int amount;
  final String? productId;
  final DateTime? createdAt;
  final int? balanceAfter;

  const CreditTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.productId,
    this.createdAt,
    this.balanceAfter,
  });

  static CreditTransaction fromMap(String id, Map<String, dynamic> m) {
    return CreditTransaction(
      id: id,
      type: (m['type'] as String?) ?? '',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      productId: m['productId'] as String?,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      balanceAfter: (m['balanceAfter'] as num?)?.toInt(),
    );
  }
}

/// 額度包：餘額存 users/{uid}/wallet，兌換時扣額度並寫入 library_products
class CreditsRepo {
  final FirebaseFirestore _db;
  CreditsRepo(this._db);

  Stream<int> watchBalance(String uid) {
    return _db
        .doc(FirestorePaths.userWallet(uid))
        .snapshots()
        .map((doc) => (doc.data()?['balance'] as num?)?.toInt() ?? 0);
  }

  Future<int> getBalance(String uid) async {
    final doc = await _db.doc(FirestorePaths.userWallet(uid)).get();
    return (doc.data()?['balance'] as num?)?.toInt() ?? 0;
  }

  Future<void> addCredits(String uid, int amount,
      {String? sourceProductId}) async {
    if (amount <= 0) return;
    final ref = _db.doc(FirestorePaths.userWallet(uid));
    final txCol = _db.collection(FirestorePaths.userCreditTransactions(uid));
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['balance'] as num?)?.toInt() ?? 0;
      final balanceAfter = current + amount;
      tx.set(ref, {
        'balance': balanceAfter,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(txCol.doc(), {
        'type': 'add',
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
        'productId': sourceProductId,
        'balanceAfter': balanceAfter,
      });
    });
  }

  /// 兌換 N 額度解鎖產品：扣額度並寫入 library_products（原子）
  /// ✅ Firestore 規則：transaction 內必須「所有讀取先執行完，再執行寫入」
  Future<void> redeemCredits({
    required String uid,
    required String productId,
    required int amount,
  }) async {
    if (amount <= 0) return;
    final walletRef = _db.doc(FirestorePaths.userWallet(uid));
    final libraryRef = _db
        .collection(FirestorePaths.userLibraryProducts(uid))
        .doc(productId);
    final txCol = _db.collection(FirestorePaths.userCreditTransactions(uid));
    await _db.runTransaction((tx) async {
      // 步驟 1：所有讀取必須在寫入之前
      final walletSnap = await tx.get(walletRef);
      final libSnap = await tx.get(libraryRef);

      final balance = (walletSnap.data()?['balance'] as num?)?.toInt() ?? 0;
      if (balance < amount) {
        throw StateError('Insufficient credits: need $amount, have $balance');
      }
      final balanceAfter = balance - amount;

      // 步驟 2：全部寫入
      tx.set(walletRef, {
        'balance': balanceAfter,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!libSnap.exists) {
        tx.set(libraryRef, {
          'productId': productId,
          'purchasedAt': FieldValue.serverTimestamp(),
          'isFavorite': false,
          'isHidden': false,
          'pushEnabled': false,
          'progress': {'nextSeq': 1, 'learnedCount': 0},
          'pushConfig': null,
          'lastOpenedAt': null,
        });
      }
      tx.set(txCol.doc(), {
        'type': 'redeem',
        'amount': amount,
        'productId': productId,
        'createdAt': FieldValue.serverTimestamp(),
        'balanceAfter': balanceAfter,
      });
    });
  }

  /// 監聽交易紀錄（依時間倒序，最多 80 筆）
  Stream<List<CreditTransaction>> watchTransactions(String uid) {
    return _db
        .collection(FirestorePaths.userCreditTransactions(uid))
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CreditTransaction.fromMap(d.id, d.data()))
            .toList());
  }
}
