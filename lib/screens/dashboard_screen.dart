import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/business_profile.dart';
import '../models/order_model.dart';
import '../services/app_strings.dart';
import '../services/template_engine.dart';

class DashboardScreen extends StatelessWidget {
  final BusinessProfile profile;
  final List<OrderModel> orders;
  final AppStrings s;
  final void Function(int tabIndex) onNavigate;

  const DashboardScreen({
    super.key,
    required this.profile,
    required this.orders,
    required this.s,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayCount = orders
        .where((o) =>
            o.createdAt.year == now.year &&
            o.createdAt.month == now.month &&
            o.createdAt.day == now.day)
        .length;
    final pendingPay =
        orders.where((o) => o.status == 'Payment Pending').length;
    final toDispatch = orders.where((o) => o.status == 'Paid').length;
    final reviewDue = orders.where((o) => o.isReviewDue).length;
    final revenue = orders
        .where((o) => o.isPaidOrBeyond)
        .fold<double>(0, (sum, o) => sum + o.totalAmount);

    final primary = Color(profile.primaryColorHex);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, primary.withOpacity(0.82)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.brandName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (profile.tagline.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.tagline,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      s.t('total_revenue'),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      TemplateEngine.formatMoney(revenue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => onNavigate(1),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.flash_on, size: 18),
                label: Text(s.t('new_reply'),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.05,
          children: [
            _StatCard(
              label: s.t('today_orders'),
              value: '$todayCount',
              icon: Icons.today_rounded,
              color: primary,
              onTap: () => onNavigate(2),
            ),
            _StatCard(
              label: s.t('pending_pay'),
              value: '$pendingPay',
              icon: Icons.schedule_rounded,
              color: Colors.orange.shade700,
              onTap: () => onNavigate(2),
            ),
            _StatCard(
              label: s.t('to_dispatch'),
              value: '$toDispatch',
              icon: Icons.local_shipping_outlined,
              color: Colors.blue.shade700,
              onTap: () => onNavigate(2),
            ),
            _StatCard(
              label: s.t('review_due'),
              value: '$reviewDue',
              icon: Icons.star_outline_rounded,
              color: Colors.purple.shade700,
              onTap: () => onNavigate(2),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(s.t('recent_orders'),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            TextButton(
              onPressed: () => onNavigate(2),
              child: Text(s.t('view_all'),
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        if (orders.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: Center(
              child: Text(s.t('no_orders_yet'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
          )
        else
          ...orders.take(5).map((o) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${o.customerName} • ${o.phone}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${o.itemsSummary.isEmpty ? o.status : o.itemsSummary} • ${DateFormat('dd MMM').format(o.createdAt)}',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          TemplateEngine.formatMoney(o.totalAmount),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            o.status,
                            style: TextStyle(
                                color: primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
