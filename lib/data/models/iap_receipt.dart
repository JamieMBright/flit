/// In-app purchase receipt record.
///
/// Server-side validation writes these rows after calling Apple/Google APIs.
/// Users can view their own receipts; admins can view all.
class IapReceipt {
  const IapReceipt({
    required this.id,
    required this.userId,
    required this.productId,
    required this.platform,
    this.receiptData,
    this.isValid = false,
    this.amount = 0,
    this.currency = 'gold',
    this.transactionId,
    required this.createdAt,
  });

  final int id;
  final String userId;
  final String productId;
  final String platform;
  final String? receiptData;
  final bool isValid;
  final int amount;
  final String currency;
  final String? transactionId;
  final DateTime createdAt;

  factory IapReceipt.fromJson(Map<String, dynamic> json) {
    return IapReceipt(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      productId: json['product_id'] as String,
      platform: json['platform'] as String,
      receiptData: json['receipt_data'] as String?,
      isValid: json['is_valid'] as bool? ?? false,
      amount: json['amount'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'gold',
      transactionId: json['transaction_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'product_id': productId,
    'platform': platform,
    'receipt_data': receiptData,
    'is_valid': isValid,
    'amount': amount,
    'currency': currency,
    'transaction_id': transactionId,
  };
}
