import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/business_profile.dart';
import '../models/order_model.dart';
import '../services/app_strings.dart';
import '../services/app_version_service.dart';
import '../services/template_engine.dart';

class DashboardScreen extends StatefulWidget {
  final BusinessProfile profile;
  final List<OrderModel> orders;
  final AppStrings s;
  final void Function(int tabIndex) onNavigateTab;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenSettings;

  const DashboardScreen({
    super.key,
    required this.profile,
    required this.orders,
    required this.s,
    required this.onNavigateTab,
    required this.onOpenProducts,
    required this.onOpenSettings,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AppVersionInfo? _latestInfo;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    setState(() => _checking = true);
    final info = await AppVersionService.fetchLatest();
    if (mounted) {
      setState(() {
        _latestInfo = info;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final orders = widget.orders;
    final primary = Color(widget.profile.primaryColorHex);
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

    final hasUpdate = _latestInfo != null &&
        _latestInfo!.buildNumber > AppVersionService.currentBuildNumber;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        // 1. Compact Header + Revenue
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, primary.withOpacity(0.84)],
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
                      widget.profile.brandName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.profile.tagline.isNotEmpty)
                      Text(
                        widget.profile.tagline,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    const SizedBox(height: 10),
                    Text(s.t('total_revenue'),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    Text(
                      TemplateEngine.formatMoney(revenue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MiniBadge(label: s.t('today_orders'), count: todayCount),
                  const SizedBox(height: 6),
                  _MiniBadge(label: s.t('pending_pay'), count: pendingPay),
                ],
              ),
            ],
          ),
        ),

        // 2. Horizontal Swipeable Recent Orders Row
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(s.t('recent_orders'),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            InkWell(
              onTap: () => widget.onNavigateTab(3),
              child: Text(s.t('view_all'),
                  style: TextStyle(
                      fontSize: 12,
                      color: primary,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Center(
              child: Text(s.t('no_orders_yet'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ),
          )
        else
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: orders.length > 10 ? 10 : orders.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final o = orders[i];
                return InkWell(
                  onTap: () => widget.onNavigateTab(3),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 195,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                o.customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              TemplateEngine.formatMoney(o.totalAmount),
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: primary),
                            ),
                          ],
                        ),
                        Text(
                          o.itemsSummary.isEmpty ? o.phone : o.itemsSummary,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(o.status,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: primary)),
                            ),
                            Text(DateFormat('dd MMM').format(o.createdAt),
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey.shade500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // 3. All Workspace Modules Tile Grid
        const SizedBox(height: 16),
        Text(s.t('all_modules'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.9,
          children: [
            _ModuleTile(
              icon: Icons.format_list_numbered_rounded,
              color: const Color(0xFF16A34A),
              title: s.t('tile_templates'),
              subtitle: s.t('tile_templates_sub'),
              onTap: () => widget.onNavigateTab(1),
            ),
            _ModuleTile(
              icon: Icons.add_shopping_cart_rounded,
              color: primary,
              title: s.t('tile_new_order'),
              subtitle: s.t('tile_new_order_sub'),
              onTap: () => widget.onNavigateTab(2),
            ),
            _ModuleTile(
              icon: Icons.receipt_long_rounded,
              color: Colors.blue.shade700,
              title: s.t('tile_orders'),
              subtitle: '$toDispatch ${s.t("to_dispatch")} • $reviewDue ${s.t("review_due")}',
              onTap: () => widget.onNavigateTab(3),
            ),
            _ModuleTile(
              icon: Icons.inventory_2_rounded,
              color: Colors.amber.shade800,
              title: s.t('tile_products'),
              subtitle: s.t('tile_products_sub'),
              onTap: widget.onOpenProducts,
            ),
            _ModuleTile(
              icon: Icons.storefront_rounded,
              color: Colors.purple.shade700,
              title: s.t('tile_profile'),
              subtitle: s.t('tile_profile_sub'),
              onTap: widget.onOpenSettings,
            ),
            _ModuleTile(
              icon: Icons.tune_rounded,
              color: Colors.blueGrey.shade700,
              title: s.t('tile_settings'),
              subtitle: s.t('tile_settings_sub'),
              onTap: widget.onOpenSettings,
            ),
          ],
        ),

        // 4. Bottom App Version, Live Auto-Update & Direct APK Download Card
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasUpdate ? Colors.orange.shade400 : Colors.black12,
              width: hasUpdate ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasUpdate
                        ? Icons.system_update_rounded
                        : Icons.verified_outlined,
                    size: 20,
                    color: hasUpdate ? Colors.orange.shade800 : primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('app_version_card'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          hasUpdate
                              ? '${s.t("update_available")}: v${_latestInfo!.version} (Build ${_latestInfo!.buildNumber})'
                              : '${s.t("current_ver")}: v${AppVersionService.currentVersion} (Build ${AppVersionService.currentBuildNumber}) • ${s.t("up_to_date")}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: s.t('check_updates'),
                    onPressed: _checking ? null : _checkVersion,
                    icon: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 19),
                  ),
                ],
              ),
              if (kIsWeb || hasUpdate) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          hasUpdate ? Colors.orange.shade800 : primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () =>
                        AppVersionService.downloadApk(_latestInfo?.apkUrl),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      hasUpdate ? s.t('update_now') : s.t('download_apk'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final int count;
  const _MiniBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $count',
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
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
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
