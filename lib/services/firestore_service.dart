import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/business_profile.dart';
import '../models/customer_model.dart';
import '../models/delivery_rules.dart';
import '../models/message_log_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
import 'excel_import_service.dart';
import 'lakfa_seed_data.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Instant optimistic state notifiers so UI updates immediately across all screens
  final ValueNotifier<String?> languageNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<int?> colorNotifier = ValueNotifier<int?>(null);

  static String normalizePhoneKey(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  // -------------------- Business Profile & Settings --------------------

  Stream<BusinessProfile> watchBusinessProfile() {
    return _db.collection('settings').doc('business_profile').snapshots().map(
      (doc) {
        final profile = doc.exists && doc.data() != null
            ? BusinessProfile.fromMap(doc.data()!)
            : LakfaSeedData.profile;
        return profile.copyWith(
          appLanguage: languageNotifier.value ?? profile.appLanguage,
          primaryColorHex: colorNotifier.value ?? profile.primaryColorHex,
        );
      },
    );
  }

  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    colorNotifier.value = profile.primaryColorHex;
    languageNotifier.value = profile.appLanguage;
    await _db
        .collection('settings')
        .doc('business_profile')
        .set(profile.toMap(), SetOptions(merge: true));
  }

  Future<void> updateAppLanguage(String lang) async {
    languageNotifier.value = lang;
    await _db
        .collection('settings')
        .doc('business_profile')
        .set({'appLanguage': lang}, SetOptions(merge: true));
  }

  Stream<DeliveryRules> watchDeliveryRules() {
    return _db.collection('settings').doc('delivery_rules').snapshots().map(
          (doc) => doc.exists && doc.data() != null
              ? DeliveryRules.fromMap(doc.data()!)
              : LakfaSeedData.deliveryRules,
        );
  }

  Future<void> saveDeliveryRules(DeliveryRules rules) {
    return _db
        .collection('settings')
        .doc('delivery_rules')
        .set(rules.toMap(), SetOptions(merge: true));
  }

  // -------------------- Products (Active & Recycle Bin) --------------------

  Stream<List<ProductModel>> watchProducts() {
    return _db.collection('products').snapshots().map((snap) {
      if (snap.docs.isEmpty) {
        return LakfaSeedData.products.where((p) => !p.isDeleted).toList();
      }
      return snap.docs
          .map((d) => ProductModel.fromMap(d.id, d.data()))
          .where((p) => !p.isDeleted)
          .toList();
    });
  }

  Stream<List<ProductModel>> watchDeletedProducts() {
    return _db.collection('products').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => ProductModel.fromMap(d.id, d.data()))
          .where((p) => p.isDeleted)
          .toList();
      list.sort((a, b) => (b.deletedAt ?? DateTime(2000))
          .compareTo(a.deletedAt ?? DateTime(2000)));
      return list;
    });
  }

  Future<void> saveProduct(ProductModel product) {
    final doc = product.id.isEmpty
        ? _db.collection('products').doc()
        : _db.collection('products').doc(product.id);
    return doc.set(product.toMap(), SetOptions(merge: true));
  }

  Future<void> toggleProductActive(ProductModel product, bool active) {
    return _db
        .collection('products')
        .doc(product.id)
        .set(product.copyWith(active: active).toMap(), SetOptions(merge: true));
  }

  Future<void> softDeleteProduct(ProductModel product) {
    return _db.collection('products').doc(product.id).set(
          product
              .copyWith(isDeleted: true, deletedAt: DateTime.now())
              .toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> restoreProduct(String id) {
    return _db.collection('products').doc(id).set(
          {'isDeleted': false, 'deletedAt': null},
          SetOptions(merge: true),
        );
  }

  Future<void> permanentlyDeleteProduct(String id) {
    return _db.collection('products').doc(id).delete();
  }

  // -------------------- Templates (Active & Recycle Bin) --------------------

  Stream<List<TemplateModel>> watchTemplates() {
    return _db
        .collection('templates')
        .orderBy('order')
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) {
        return LakfaSeedData.templates.where((t) => !t.isDeleted).toList();
      }
      return snap.docs
          .map((d) => TemplateModel.fromMap(d.id, d.data()))
          .where((t) => !t.isDeleted)
          .toList();
    });
  }

  Stream<List<TemplateModel>> watchDeletedTemplates() {
    return _db.collection('templates').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => TemplateModel.fromMap(d.id, d.data()))
          .where((t) => t.isDeleted)
          .toList();
      list.sort((a, b) => (b.deletedAt ?? DateTime(2000))
          .compareTo(a.deletedAt ?? DateTime(2000)));
      return list;
    });
  }

  Future<void> saveTemplate(TemplateModel template) {
    final doc = template.id.isEmpty
        ? _db.collection('templates').doc()
        : _db.collection('templates').doc(template.id);
    return doc.set(template.toMap(), SetOptions(merge: true));
  }

  Future<void> softDeleteTemplate(TemplateModel template) {
    return _db.collection('templates').doc(template.id).set(
          template
              .copyWith(isDeleted: true, deletedAt: DateTime.now())
              .toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> restoreTemplate(String id) {
    return _db.collection('templates').doc(id).set(
          {'isDeleted': false, 'deletedAt': null},
          SetOptions(merge: true),
        );
  }

  Future<void> permanentlyDeleteTemplate(String id) {
    return _db.collection('templates').doc(id).delete();
  }

  // -------------------- Orders (Active & Recycle Bin) --------------------

  Stream<List<OrderModel>> watchOrders() {
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OrderModel.fromMap(d.id, d.data()))
            .where((o) => !o.isDeleted)
            .toList());
  }

  Stream<List<OrderModel>> watchDeletedOrders() {
    return _db.collection('orders').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => OrderModel.fromMap(d.id, d.data()))
          .where((o) => o.isDeleted)
          .toList();
      list.sort((a, b) => (b.deletedAt ?? DateTime(2000))
          .compareTo(a.deletedAt ?? DateTime(2000)));
      return list;
    });
  }

  Future<String> createOrder(OrderModel order) async {
    final ref = await _db.collection('orders').add(order.toMap());
    if (order.phone.trim().isNotEmpty) {
      await upsertCustomerFromDetails(
        name: order.customerName,
        phone: order.phone,
        address: order.address,
        source: 'order',
      );
    }
    return ref.id;
  }

  Future<void> saveOrder(OrderModel order) {
    return _db
        .collection('orders')
        .doc(order.id)
        .set(order.toMap(), SetOptions(merge: true));
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    String? trackingId,
    bool? reviewSent,
  }) {
    final data = <String, dynamic>{'status': status};
    if (trackingId != null) data['trackingId'] = trackingId;
    if (status == 'Dispatched') {
      data['dispatchedAt'] = Timestamp.fromDate(DateTime.now());
    }
    if (reviewSent != null) data['reviewSent'] = reviewSent;
    return _db
        .collection('orders')
        .doc(orderId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> updateOrderPayment({
    required String orderId,
    required String paymentStatus,
    required double paidAmount,
  }) {
    final data = <String, dynamic>{
      'paymentStatus': paymentStatus,
      'paidAmount': paidAmount,
      'paidAt': paymentStatus == 'Pending'
          ? null
          : Timestamp.fromDate(DateTime.now()),
    };
    return _db
        .collection('orders')
        .doc(orderId)
        .set(data, SetOptions(merge: true));
  }

  // -------------------- WhatsApp Message Logs --------------------

  Stream<List<MessageLogModel>> watchMessageLogs() {
    return _db
        .collection('message_logs')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MessageLogModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> logMessageSend({
    required String phone,
    String recipientName = '',
    String orderId = '',
    String customerId = '',
    String templateId = '',
    String templateTitle = '',
    String stage = '',
    String lang = '',
    String messagePreview = '',
    String mode = 'direct',
    DateTime? sentAt,
  }) {
    final norm = normalizePhoneKey(phone);
    final resolvedCustomerId = customerId.isNotEmpty
        ? customerId
        : (norm.isNotEmpty ? 'cust_$norm' : '');
    final log = MessageLogModel(
      id: '',
      recipientName: recipientName.trim(),
      phone: phone.trim(),
      normalizedPhone: norm,
      orderId: orderId.trim(),
      customerId: resolvedCustomerId,
      templateId: templateId.trim(),
      templateTitle: templateTitle.trim(),
      stage: stage.trim(),
      lang: lang.trim(),
      messagePreview: messagePreview.trim(),
      mode: mode,
      sentAt: sentAt ?? DateTime.now(),
    );
    return _db.collection('message_logs').add(log.toMap());
  }

  Future<void> softDeleteOrder(String orderId) {
    return _db.collection('orders').doc(orderId).set(
      {
        'isDeleted': true,
        'deletedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> restoreOrder(String orderId) {
    return _db.collection('orders').doc(orderId).set(
      {
        'isDeleted': false,
        'deletedAt': null,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> permanentlyDeleteOrder(String orderId) {
    return _db.collection('orders').doc(orderId).delete();
  }

  // -------------------- Customers & Excel Import --------------------

  Stream<List<CustomerModel>> watchCustomers() {
    return _db.collection('customers').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => CustomerModel.fromMap(d.id, d.data()))
          .where((c) => !c.isDeleted)
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  Stream<List<CustomerModel>> watchDeletedCustomers() {
    return _db.collection('customers').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => CustomerModel.fromMap(d.id, d.data()))
          .where((c) => c.isDeleted)
          .toList();
      list.sort((a, b) => (b.deletedAt ?? DateTime(2000))
          .compareTo(a.deletedAt ?? DateTime(2000)));
      return list;
    });
  }

  Future<void> saveCustomer(CustomerModel customer) {
    final norm = normalizePhoneKey(customer.phone);
    final docId = customer.id.isNotEmpty
        ? customer.id
        : (norm.isNotEmpty
            ? 'cust_$norm'
            : _db.collection('customers').doc().id);
    return _db
        .collection('customers')
        .doc(docId)
        .set(customer.copyWith(id: docId).toMap(), SetOptions(merge: true));
  }

  Future<void> upsertCustomerFromDetails({
    required String name,
    required String phone,
    String address = '',
    String notes = '',
    String source = 'manual',
  }) {
    final norm = normalizePhoneKey(phone);
    final docId = norm.isNotEmpty
        ? 'cust_$norm'
        : _db.collection('customers').doc().id;
    final now = DateTime.now();
    return _db.collection('customers').doc(docId).set(
      {
        'name': name,
        'phone': phone,
        if (address.isNotEmpty) 'address': address,
        if (notes.isNotEmpty) 'notes': notes,
        'source': source,
        'isDeleted': false,
        'deletedAt': null,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> softDeleteCustomer(String id) {
    return _db.collection('customers').doc(id).set(
      {
        'isDeleted': true,
        'deletedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> restoreCustomer(String id) {
    return _db.collection('customers').doc(id).set(
      {
        'isDeleted': false,
        'deletedAt': null,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> permanentlyDeleteCustomer(String id) {
    return _db.collection('customers').doc(id).delete();
  }

  Future<void> importExcelRows({
    required List<ExcelImportRow> rows,
    required bool saveCustomers,
    required bool saveOrders,
    required String defaultOrderStatus,
    void Function(int processed, int total)? onProgress,
  }) async {
    final now = DateTime.now();
    final total = rows.length;
    onProgress?.call(0, total);

    var batch = _db.batch();
    int opCount = 0;
    int processed = 0;

    Future<void> commitChunk() async {
      if (opCount > 0) {
        await batch.commit();
        batch = _db.batch();
        opCount = 0;
      }
    }

    for (final row in rows) {
      if (saveCustomers) {
        final norm = normalizePhoneKey(row.phone);
        final custId = norm.isNotEmpty
            ? 'cust_$norm'
            : _db.collection('customers').doc().id;
        batch.set(
          _db.collection('customers').doc(custId),
          {
            'name': row.name,
            'phone': row.phone,
            'address': row.address,
            'notes': row.notes,
            'source': 'excel',
            'isDeleted': false,
            'deletedAt': null,
            'createdAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
        opCount++;
      }

      if (saveOrders) {
        final (resolvedStatus, resolvedPayment, resolvedPaidAmt) =
            OrderModel.resolveLegacyStatuses(
          rawStatus:
              row.status.trim().isEmpty ? defaultOrderStatus : row.status.trim(),
          totalAmount: row.amount,
        );
        final items = row.productName.isNotEmpty
            ? [
                OrderItem(
                  productId: '',
                  productName: row.productName,
                  packLabel:
                      row.packLabel.isNotEmpty ? row.packLabel : 'Standard',
                  unitPrice:
                      row.quantity > 0 ? row.amount / row.quantity : row.amount,
                  packDeliveryCharge: 0,
                  quantity: row.quantity,
                ),
              ]
            : <OrderItem>[];
        final order = OrderModel(
          id: '',
          customerName: row.name,
          phone: row.phone,
          address: row.address,
          items: items,
          subtotal: row.amount,
          deliveryCharge: 0,
          totalAmount: row.amount,
          status: resolvedStatus,
          paymentStatus: resolvedPayment,
          paidAmount: resolvedPaidAmt,
          paidAt: resolvedPayment == 'Pending' ? null : now,
          notes: row.notes,
          createdAt: now,
        );
        batch.set(_db.collection('orders').doc(), order.toMap());
        opCount++;
      }

      processed++;
      if (opCount >= 40) {
        await commitChunk();
        onProgress?.call(processed, total);
      }
    }

    await commitChunk();
    onProgress?.call(total, total);
  }

  // -------------------- Empty Bin & Defaults --------------------

  Future<void> emptyBin({
    required List<OrderModel> orders,
    required List<ProductModel> products,
    required List<TemplateModel> templates,
    required List<CustomerModel> customers,
  }) async {
    var batch = _db.batch();
    int opCount = 0;

    Future<void> commitIfNeeded() async {
      if (opCount >= 400) {
        await batch.commit();
        batch = _db.batch();
        opCount = 0;
      }
    }

    for (final o in orders) {
      batch.delete(_db.collection('orders').doc(o.id));
      opCount++;
      await commitIfNeeded();
    }
    for (final p in products) {
      batch.delete(_db.collection('products').doc(p.id));
      opCount++;
      await commitIfNeeded();
    }
    for (final t in templates) {
      batch.delete(_db.collection('templates').doc(t.id));
      opCount++;
      await commitIfNeeded();
    }
    for (final c in customers) {
      batch.delete(_db.collection('customers').doc(c.id));
      opCount++;
      await commitIfNeeded();
    }
    if (opCount > 0) {
      await batch.commit();
    }
  }

  Future<void> seedLakfaDefaults() async {
    languageNotifier.value = LakfaSeedData.profile.appLanguage;
    colorNotifier.value = LakfaSeedData.profile.primaryColorHex;
    final batch = _db.batch();
    batch.set(
      _db.collection('settings').doc('business_profile'),
      LakfaSeedData.profile.toMap(),
      SetOptions(merge: true),
    );
    batch.set(
      _db.collection('settings').doc('delivery_rules'),
      LakfaSeedData.deliveryRules.toMap(),
    );
    for (final p in LakfaSeedData.products) {
      batch.set(_db.collection('products').doc(p.id), p.toMap());
    }
    for (final t in LakfaSeedData.templates) {
      batch.set(_db.collection('templates').doc(t.id), t.toMap());
    }
    await batch.commit();
  }
}
