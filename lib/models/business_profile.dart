class BusinessProfile {
  final String brandName;
  final String tagline;
  final String phone;
  final String website;
  final String instagramHandle;
  final String instagramUrl;
  final String reviewUrl;
  final String courierName;
  final String trackingUrl;
  final String paymentBankLabel;
  final String qrImageBase64;
  final String qrImageUrl;
  final int primaryColorHex;

  const BusinessProfile({
    required this.brandName,
    required this.tagline,
    required this.phone,
    required this.website,
    required this.instagramHandle,
    required this.instagramUrl,
    required this.reviewUrl,
    required this.courierName,
    required this.trackingUrl,
    required this.paymentBankLabel,
    this.qrImageBase64 = '',
    this.qrImageUrl = '',
    this.primaryColorHex = 0xFF0F766E,
  });

  factory BusinessProfile.fromMap(Map<String, dynamic> map) {
    return BusinessProfile(
      brandName: (map['brandName'] ?? 'My Business') as String,
      tagline: (map['tagline'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      website: (map['website'] ?? '') as String,
      instagramHandle: (map['instagramHandle'] ?? '') as String,
      instagramUrl: (map['instagramUrl'] ?? '') as String,
      reviewUrl: (map['reviewUrl'] ?? '') as String,
      courierName: (map['courierName'] ?? 'DTDC Courier') as String,
      trackingUrl: (map['trackingUrl'] ?? '') as String,
      paymentBankLabel: (map['paymentBankLabel'] ?? 'UPI / Bank QR Code') as String,
      qrImageBase64: (map['qrImageBase64'] ?? '') as String,
      qrImageUrl: (map['qrImageUrl'] ?? '') as String,
      primaryColorHex: (map['primaryColorHex'] ?? 0xFF0F766E) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'brandName': brandName,
      'tagline': tagline,
      'phone': phone,
      'website': website,
      'instagramHandle': instagramHandle,
      'instagramUrl': instagramUrl,
      'reviewUrl': reviewUrl,
      'courierName': courierName,
      'trackingUrl': trackingUrl,
      'paymentBankLabel': paymentBankLabel,
      'qrImageBase64': qrImageBase64,
      'qrImageUrl': qrImageUrl,
      'primaryColorHex': primaryColorHex,
    };
  }

  BusinessProfile copyWith({
    String? brandName,
    String? tagline,
    String? phone,
    String? website,
    String? instagramHandle,
    String? instagramUrl,
    String? reviewUrl,
    String? courierName,
    String? trackingUrl,
    String? paymentBankLabel,
    String? qrImageBase64,
    String? qrImageUrl,
    int? primaryColorHex,
  }) {
    return BusinessProfile(
      brandName: brandName ?? this.brandName,
      tagline: tagline ?? this.tagline,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      reviewUrl: reviewUrl ?? this.reviewUrl,
      courierName: courierName ?? this.courierName,
      trackingUrl: trackingUrl ?? this.trackingUrl,
      paymentBankLabel: paymentBankLabel ?? this.paymentBankLabel,
      qrImageBase64: qrImageBase64 ?? this.qrImageBase64,
      qrImageUrl: qrImageUrl ?? this.qrImageUrl,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
    );
  }
}
