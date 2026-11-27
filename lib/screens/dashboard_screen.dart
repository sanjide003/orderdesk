import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/business_profile.dart';
import '../models/order_model.dart';
import '../services/app_strings.dart';
import '../services/app_version_service.dart';
import '../services/template_engine.dart';
import '../services/ui_helpers.dart';
import '../widgets/update_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final BusinessProfile profile;
  final List<OrderModel> orders;
  final AppStrings s;
  final void Function(int tabIndex) onNavigateTab;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenCustomers;
  final VoidCallback onOpenBin;
  final VoidCallback onOpenSettings;

  const DashboardScreen({
    super.key,
    required this.profile,
    required this.orders,
    required this.s,
    required this.onNavigateTab,
    required this.onOpenProducts,
    required this.onOpenCustomers,
    required this.onOpenBin,
    required this.onOpenSettings,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  InstalledAppVersion _installed = const InstalledAppVersion(
    version: AppVersionService.fallbackVersion,
    buildNumber: AppVersionService.fallbackBuildNumber,
  );
  AppVersionInfo? _latestInfo;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkVersion(showFeedback: false);
  }

  Future<void> _checkVersion({bool showFeedback = true}) async {
    setState(() => _checking = true);
    final installed = await AppVersionService.getInstalledVersion();
    final info = await AppVersionService.fetchLatest();
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _latestInfo = info;
      _checking = false;
    });
    if (showFeedback) {
      if (info == null) {
        UiHelpers.showFeedback(context, widget.s.t('update_check_failed'),
            isError: true);
      } else if (AppVersionService.isRemoteNewer(info, installed)) {
        _openUpdateDialog(Color(widget.profile.primaryColorHex));
      } else {
        UiHelpers.showFeedback(
          context,
          '${widget.s.t('up_to_date')} (v${installed.version})',
        );
      }
    }
  }

  void _openUpdateDialog(Color primary) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(
        s: widget.s,
        installed: _installed,
        latest: _latestInfo,
        primaryColor: primary,
      ),
    );
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
        AppVersionService.isRemoteNewer(_latestInfo!, _installed);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;

        final headerCard = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, primary.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: isWide ? 52 : 44,
                  height: isWide ? 52 : 44,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.profile.brandName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.profile.tagline.isNotEmpty)
                      Text(
                        widget.profile.tagline,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11.5),
                      ),
                    if (!isWide) ...[
                      const SizedBox(height: 8),
                      Text(s.t('total_revenue'),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                      Text(
                        TemplateEngine.formatMoney(revenue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isWide)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _MiniBadge(label: s.t('today_orders'), count: todayCount),
                    const SizedBox(height: 6),
                    _MiniBadge(label: s.t('pending_pay'), count: pendingPay),
                  ],
                )
              else
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onPressed: () => widget.onNavigateTab(2),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: Text(
                    s.t('nav_new_order'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        );

        final kpiStrip = Row(
          children: [
            Expanded(
              child: _KpiBox(
                label: s.t('total_revenue'),
                value: TemplateEngine.formatMoney(revenue),
                color: primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiBox(
                label: s.t('today_orders'),
                value: '$todayCount',
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiBox(
                label: s.t('pending_pay'),
                value: '$pendingPay',
                color: Colors.amber.shade800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiBox(
                label: s.t('to_dispatch'),
                value: '$toDispatch',
                color: Colors.green.shade700,
              ),
            ),
          ],
        );

        final recentOrdersSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.t('recent_orders'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Center(
                  child: Text(s.t('no_orders_yet'),
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ),
              )
            else if (isWide)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length > 6 ? 6 : orders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final o = orders[i];
                    return ListTile(
                      dense: true,
                      onTap: () => widget.onNavigateTab(3),
                      title: Text(
                        '${o.customerName}  ·  ${o.phone}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        o.itemsSummary.isEmpty
                            ? o.status
                            : '${o.itemsSummary}  ·  ${o.status}',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            TemplateEngine.formatMoney(o.totalAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: primary,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM').format(o.createdAt),
                            style: TextStyle(
                                fontSize: 10.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  },
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
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  TemplateEngine.formatMoney(o.totalAmount),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: primary,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ]),
                                ),
                              ],
                            ),
                            Text(
                              o.itemsSummary.isEmpty
                                  ? o.phone
                                  : o.itemsSummary,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(o.status,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: primary)),
                                Text(DateFormat('dd MMM').format(o.createdAt),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );

        final modulesGrid = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('all_modules'),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: isWide ? 2 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: isWide ? 2.4 : 1.9,
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
                  subtitle:
                      '$toDispatch ${s.t("to_dispatch")} · $reviewDue ${s.t("review_due")}',
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
                  icon: Icons.people_alt_rounded,
                  color: Colors.indigo.shade700,
                  title: s.t('tile_customers'),
                  subtitle: s.t('tile_customers_sub'),
                  onTap: widget.onOpenCustomers,
                ),
                _ModuleTile(
                  icon: Icons.delete_sweep_rounded,
                  color: Colors.red.shade700,
                  title: s.t('tile_bin'),
                  subtitle: s.t('tile_bin_sub'),
                  onTap: widget.onOpenBin,
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
          ],
        );

        final versionCard = InkWell(
          onTap: _checking ? null : () => _checkVersion(showFeedback: true),
          borderRadius: BorderRadius.circular(14),
          child: Container(
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                                : '${s.t("current_ver")}: v${_installed.version} (Build ${_installed.buildNumber}) · ${s.t("up_to_date")}',
                            style: TextStyle(
                                fontSize: 11,
                                color: hasUpdate
                                    ? Colors.orange.shade800
                                    : Colors.grey.shade700,
                                fontWeight: hasUpdate
                                    ? FontWeight.w700
                                    : FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: s.t('check_updates'),
                      onPressed: _checking
                          ? null
                          : () => _checkVersion(showFeedback: true),
                      icon: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              hasUpdate
                                  ? Icons.system_update_rounded
                                  : Icons.verified_outlined,
                              size: 20,
                              color:
                                  hasUpdate ? Colors.orange.shade800 : primary,
                            ),
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
                      onPressed: () => _openUpdateDialog(
                        hasUpdate ? Colors.orange.shade800 : primary,
                      ),
                      icon: const Icon(Icons.system_update_alt_rounded,
                          size: 18),
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
        );

        return ListView(
          padding: EdgeInsets.fromLTRB(
              isWide ? 20 : 12, isWide ? 18 : 12, isWide ? 20 : 12, 24),
          children: [
            headerCard,
            if (isWide) ...[
              const SizedBox(height: 14),
              kpiStrip,
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: recentOrdersSection,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        modulesGrid,
                        const SizedBox(height: 14),
                        versionCard,
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 14),
              recentOrdersSection,
              const SizedBox(height: 16),
              modulesGrid,
              const SizedBox(height: 16),
              versionCard,
            ],
          ],
        );
      },
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _KpiBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
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
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
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
                color: color.withValues(alpha: 0.12),
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
