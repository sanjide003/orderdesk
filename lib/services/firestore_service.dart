import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_profile.dart';
import '../models/delivery_rules.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
import 'lakfa_seed_data.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<BusinessProfile> watchBusinessProfile() {
    return _db.collection('settings').doc('business_profile').snapshots().map(
          (doc) => doc.exists && doc.data() != null
              ? BusinessProfile.fromMap(doc.data()!)
              : LakfaSeedData.profile,
        );
  }

  Future<void> saveBusinessProfile(BusinessProfile profile) {
    return _db
        .collection('settings')
        .doc('business_profile')
        .set(profile.toMap(), SetOptions(merge: true));
  }

  Future<void> updateAppLanguage(String lang) {
    return _db
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

  Stream<List<ProductModel>> watchProducts() {
    return _db.collection('products').snapshots().map((snap) {
      if (snap.docs.isEmpty) return LakfaSeedData.products;
      return snap.docs
          .map((d) => ProductModel.fromMap(d.id, d.data()))
          .toList();
    });
  }

  Future<void> saveProduct(ProductModel product) {
    final doc = product.id.isEmpty
        ? _db.collection('products').doc()
        : _db.collection('products').doc(product.id);
    return doc.set(product.toMap(), SetOptions(merge: true));
  }

  Future<void> toggleProductActive(String id, bool active) {
    return _db.collection('products').doc(id).update({'active': active});
  }

  Future<void> deleteProduct(String id) {
    return _db.collection('products').doc(id).delete();
  }

  Stream<List<TemplateModel>> watchTemplates() {
    return _db
        .collection('templates')
        .orderBy('order')
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return LakfaSeedData.templates;
      return snap.docs
          .map((d) => TemplateModel.fromMap(d.id, d.data()))
          .toList();
    });
  }

  Future<void> saveTemplate(TemplateModel template) {
    final doc = template.id.isEmpty
        ? _db.collection('templates').doc()
        : _db.collection('templates').doc(template.id);
    return doc.set(template.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteTemplate(String id) {
    return _db.collection('templates').doc(id).delete();
  }

  Stream<List<OrderModel>> watchOrders() {
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OrderModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<String> createOrder(OrderModel order) async {
    final ref = await _db.collection('orders').add(order.toMap());
    return ref.id;
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
    return _db.collection('orders').doc(orderId).update(data);
  }

  Future<void> deleteOrder(String orderId) {
    return _db.collection('orders').doc(orderId).delete();
  }

  Future<void> seedLakfaDefaults() async {
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
