import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/customer_model.dart';
import '../models/delivery_rules.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
import '../services/app_strings.dart';
import '../services/app_version_service.dart';
import '../services/firestore_service.dart';
import '../services/lakfa_seed_data.dart';
import '../services/ui_helpers.dart';
import '../widgets/update_dialog.dart';
import 'bin_screen.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'new_order_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';
import 'templates_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _service = FirestoreService();
  int _tabIndex = 0; // 0..7 across all workspace sections
  bool _sidebarExpanded = true;
  CustomerModel? _prefilledCustomer;
  bool _checkedStartupUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStartupUpdate());
  }

  Future<void> _checkStartupUpdate() async {
    if (_checkedStartupUpdate) return;
    _checkedStartupUpdate = true;

    final installed = await AppVersionService.getInstalledVersion();
    final latest = await AppVersionService.fetchLatest();
    if (!mounted || latest == null) return;
    if (AppVersionService.isRemoteNewer(latest, installed)) {
      final lang = _service.languageNotifier.value ?? 'en';
      final color = Color(_service.colorNotifier.value ?? 0xFF0F766E);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(
          s: AppStrings(lang),
          installed: installed,
          latest: latest,
          primaryColor: color,
        ),
      );
    }
  }

  Future<void> _toggleLanguage(
      BuildContext context, String activeLang, AppStrings s) async {
    final nextLang = activeLang == 'ml' ? 'en' : 'ml';
    try {
      await _service.updateAppLanguage(nextLang);
      if (context.mounted) {
        UiHelpers.showFeedback(
          context,
          AppStrings(nextLang).t('language_updated'),
        );
      }
    } catch (_) {
      if (context.mounted) {
        UiHelpers.showFeedback(context, s.t('action_failed'), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 840;

    return ValueListenableBuilder<String?>(
      valueListenable: _service.languageNotifier,
      builder: (context, langOverride, _) {
        return ValueListenableBuilder<int?>(
          valueListenable: _service.colorNotifier,
          builder: (context, colorOverride, _) {
            return StreamBuilder<BusinessProfile>(
              stream: _service.watchBusinessProfile(),
              builder: (context, profileSnap) {
                final rawProfile = profileSnap.data ?? LakfaSeedData.profile;
                final activeLang = langOverride ?? rawProfile.appLanguage;
                final activeColorHex =
                    colorOverride ?? rawProfile.primaryColorHex;
                final profile = rawProfile.copyWith(
                  appLanguage: activeLang,
                  primaryColorHex: activeColorHex,
                );
                final s = AppStrings(activeLang);
                final primary = Color(activeColorHex);

                return Theme(
                  data: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.light,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: primary,
                      brightness: Brightness.light,
                    ),
                    scaffoldBackgroundColor: const Color(0xFFF4F7F6),
                    canvasColor: const Color(0xFFF4F7F6),
                    cardColor: Colors.white,
                    dialogTheme:
                        const DialogThemeData(backgroundColor: Colors.white),
                    bottomSheetTheme: const BottomSheetThemeData(
                        backgroundColor: Colors.white),
                  ),
                  child: StreamBuilder<DeliveryRules>(
                    stream: _service.watchDeliveryRules(),
                    builder: (context, rulesSnap) {
                      final rules =
                          rulesSnap.data ?? LakfaSeedData.deliveryRules;
                      return StreamBuilder<List<ProductModel>>(
                        stream: _service.watchProducts(),
                        builder: (context, prodSnap) {
                          final products =
                              prodSnap.data ?? LakfaSeedData.products;
                          return StreamBuilder<List<TemplateModel>>(
                            stream: _service.watchTemplates(),
                            builder: (context, tplSnap) {
                              final templates =
                                  tplSnap.data ?? LakfaSeedData.templates;
                              return StreamBuilder<List<OrderModel>>(
                                stream: _service.watchOrders(),
                                builder: (context, ordSnap) {
                                  final orders = ordSnap.data ?? [];

                                  void selectTab(int i) {
                                    setState(() => _tabIndex = i);
                                  }

                                  void openProducts() {
                                    if (isDesktop) {
                                      selectTab(4);
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProductsScreen(
                                          service: _service,
                                          initialProducts: products,
                                          initialStrings: s,
                                        ),
                                      ),
                                    );
                                  }

                                  void openCustomers() {
                                    if (isDesktop) {
                                      selectTab(5);
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CustomersScreen(
                                          service: _service,
                                          onTakeOrder: (customer) {
                                            setState(() {
                                              _prefilledCustomer = customer;
                                              _tabIndex = 2;
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  }

                                  void openBin() {
                                    if (isDesktop) {
                                      selectTab(6);
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            BinScreen(service: _service),
                                      ),
                                    );
                                  }

                                  void openSettings() {
                                    if (isDesktop) {
                                      selectTab(7);
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SettingsScreen(
                                          service: _service,
                                          profile: profile,
                                          rules: rules,
                                          s: s,
                                        ),
                                      ),
                                    );
                                  }

                                  final allPages = [
                                    DashboardScreen(
                                      profile: profile,
                                      orders: orders,
                                      s: s,
                                      onNavigateTab: selectTab,
                                      onOpenProducts: openProducts,
                                      onOpenCustomers: openCustomers,
                                      onOpenBin: openBin,
                                      onOpenSettings: openSettings,
                                    ),
                                    TemplatesScreen(
                                      service: _service,
                                      profile: profile,
                                      products: products,
                                      templates: templates,
                                      s: s,
                                    ),
                                    NewOrderScreen(
                                      service: _service,
                                      profile: profile,
                                      rules: rules,
                                      products: products,
                                      templates: templates,
                                      s: s,
                                      prefilledCustomer: _prefilledCustomer,
                                    ),
                                    OrdersScreen(
                                      service: _service,
                                      profile: profile,
                                      products: products,
                                      templates: templates,
                                      orders: orders,
                                      s: s,
                                      onOpenBin: isDesktop ? openBin : null,
                                    ),
                                    ProductsScreen(
                                      service: _service,
                                      initialProducts: products,
                                      initialStrings: s,
                                      embedded: true,
                                      onOpenBin: openBin,
                                    ),
                                    CustomersScreen(
                                      service: _service,
                                      embedded: true,
                                      onTakeOrder: (customer) {
                                        setState(() {
                                          _prefilledCustomer = customer;
                                          _tabIndex = 2;
                                        });
                                      },
                                    ),
                                    BinScreen(
                                      service: _service,
                                      embedded: true,
                                    ),
                                    SettingsScreen(
                                      service: _service,
                                      profile: profile,
                                      rules: rules,
                                      s: s,
                                      embedded: true,
                                    ),
                                  ];

                                  final navItems = [
                                    _SidebarItem(
                                      index: 0,
                                      icon: Icons.dashboard_outlined,
                                      selectedIcon: Icons.dashboard_rounded,
                                      label: s.t('nav_home'),
                                    ),
                                    _SidebarItem(
                                      index: 1,
                                      icon:
                                          Icons.format_list_numbered_rounded,
                                      selectedIcon:
                                          Icons.format_list_numbered_rounded,
                                      label: s.t('tile_templates'),
                                    ),
                                    _SidebarItem(
                                      index: 2,
                                      icon: Icons.add_shopping_cart_outlined,
                                      selectedIcon:
                                          Icons.add_shopping_cart_rounded,
                                      label: s.t('nav_new_order'),
                                    ),
                                    _SidebarItem(
                                      index: 3,
                                      icon: Icons.receipt_long_outlined,
                                      selectedIcon: Icons.receipt_long_rounded,
                                      label: s.t('tile_orders'),
                                    ),
                                    _SidebarItem(
                                      index: 4,
                                      icon: Icons.inventory_2_outlined,
                                      selectedIcon: Icons.inventory_2_rounded,
                                      label: s.t('tile_products'),
                                    ),
                                    _SidebarItem(
                                      index: 5,
                                      icon: Icons.people_alt_outlined,
                                      selectedIcon: Icons.people_alt_rounded,
                                      label: s.t('tile_customers'),
                                    ),
                                    _SidebarItem(
                                      index: 6,
                                      icon: Icons.delete_outline_rounded,
                                      selectedIcon: Icons.delete_sweep_rounded,
                                      label: s.t('bin_title'),
                                    ),
                                    _SidebarItem(
                                      index: 7,
                                      icon: Icons.settings_outlined,
                                      selectedIcon: Icons.settings_rounded,
                                      label: s.t('tile_settings'),
                                    ),
                                  ];

                                  if (isDesktop) {
                                    final currentTitle =
                                        navItems[_tabIndex].label;
                                    return Scaffold(
                                      body: Row(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 180),
                                            curve: Curves.easeOutCubic,
                                            width:
                                                _sidebarExpanded ? 248 : 74,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border(
                                                right: BorderSide(
                                                    color: Colors.grey.shade200),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                // Brand header
                                                Container(
                                                  height: 56,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12),
                                                  child: Row(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(9),
                                                        child: Image.asset(
                                                          'assets/images/app_logo.png',
                                                          width: 32,
                                                          height: 32,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                      if (_sidebarExpanded) ...[
                                                        const SizedBox(
                                                            width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            profile.brandName,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      if (_sidebarExpanded)
                                                        IconButton(
                                                          tooltip: s.t(
                                                              'collapse_sidebar'),
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                          onPressed: () =>
                                                              setState(() =>
                                                                  _sidebarExpanded =
                                                                      false),
                                                          icon: const Icon(
                                                              Icons
                                                                  .menu_open_rounded,
                                                              size: 19),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                if (!_sidebarExpanded)
                                                  IconButton(
                                                    tooltip:
                                                        s.t('expand_sidebar'),
                                                    onPressed: () => setState(
                                                        () => _sidebarExpanded =
                                                            true),
                                                    icon: const Icon(
                                                        Icons.menu_rounded,
                                                        size: 20),
                                                  ),
                                                const Divider(height: 1),
                                                Expanded(
                                                  child: ListView(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            10),
                                                    children: navItems
                                                        .map((item) {
                                                      final selected =
                                                          _tabIndex ==
                                                              item.index;
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                bottom: 4),
                                                        child: Tooltip(
                                                          message:
                                                              _sidebarExpanded
                                                                  ? ''
                                                                  : item.label,
                                                          child: InkWell(
                                                            onTap: () =>
                                                                selectTab(
                                                                    item.index),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            child: Container(
                                                              height: 42,
                                                              padding:
                                                                  EdgeInsets
                                                                      .symmetric(
                                                                horizontal:
                                                                    _sidebarExpanded
                                                                        ? 12
                                                                        : 0,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: selected
                                                                    ? primary
                                                                        .withValues(
                                                                            alpha: 0.12)
                                                                    : Colors
                                                                        .transparent,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    _sidebarExpanded
                                                                        ? MainAxisAlignment
                                                                            .start
                                                                        : MainAxisAlignment
                                                                            .center,
                                                                children: [
                                                                  Icon(
                                                                    selected
                                                                        ? item
                                                                            .selectedIcon
                                                                        : item
                                                                            .icon,
                                                                    size: 20,
                                                                    color: selected
                                                                        ? primary
                                                                        : Colors
                                                                            .grey
                                                                            .shade700,
                                                                  ),
                                                                  if (_sidebarExpanded) ...[
                                                                    const SizedBox(
                                                                        width:
                                                                            12),
                                                                    Expanded(
                                                                      child:
                                                                          Text(
                                                                        item
                                                                            .label,
                                                                        maxLines:
                                                                            1,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              13.5,
                                                                          fontWeight: selected
                                                                              ? FontWeight.w700
                                                                              : FontWeight.w500,
                                                                          color: selected
                                                                              ? primary
                                                                              : const Color(0xFF1E293B),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                                const Divider(height: 1),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  child: Column(
                                                    children: [
                                                      InkWell(
                                                        onTap: () =>
                                                            _toggleLanguage(
                                                                context,
                                                                activeLang,
                                                                s),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        child: Container(
                                                          height: 40,
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                            horizontal:
                                                                _sidebarExpanded
                                                                    ? 12
                                                                    : 0,
                                                          ),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                _sidebarExpanded
                                                                    ? MainAxisAlignment
                                                                        .start
                                                                    : MainAxisAlignment
                                                                        .center,
                                                            children: [
                                                              Icon(
                                                                  Icons
                                                                      .translate_rounded,
                                                                  size: 19,
                                                                  color: primary),
                                                              if (_sidebarExpanded) ...[
                                                                const SizedBox(
                                                                    width: 12),
                                                                Expanded(
                                                                  child: Text(
                                                                    activeLang ==
                                                                            'ml'
                                                                        ? 'English'
                                                                        : 'മലയാളം',
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w700,
                                                                        fontSize:
                                                                            13,
                                                                        color:
                                                                            primary),
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      InkWell(
                                                        onTap: () async {
                                                          final ok =
                                                              await UiHelpers
                                                                  .confirmDialog(
                                                            context,
                                                            title: s.t(
                                                                'confirm_sign_out'),
                                                            message: s.t(
                                                                'sign_out_q'),
                                                            confirmLabel:
                                                                s.t('sign_out'),
                                                            cancelLabel:
                                                                s.t('cancel'),
                                                            isDestructive: true,
                                                          );
                                                          if (ok) {
                                                            await FirebaseAuth
                                                                .instance
                                                                .signOut();
                                                          }
                                                        },
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        child: Container(
                                                          height: 40,
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                            horizontal:
                                                                _sidebarExpanded
                                                                    ? 12
                                                                    : 0,
                                                          ),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                _sidebarExpanded
                                                                    ? MainAxisAlignment
                                                                        .start
                                                                    : MainAxisAlignment
                                                                        .center,
                                                            children: [
                                                              const Icon(
                                                                  Icons.logout,
                                                                  size: 19,
                                                                  color: Colors
                                                                      .red),
                                                              if (_sidebarExpanded) ...[
                                                                const SizedBox(
                                                                    width: 12),
                                                                Expanded(
                                                                  child: Text(
                                                                    s.t('sign_out'),
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w600,
                                                                        fontSize:
                                                                            13,
                                                                        color: Colors
                                                                            .red),
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              children: [
                                                // Clean 3-zone top workspace header
                                                Container(
                                                  height: 56,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 20),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    border: Border(
                                                      bottom: BorderSide(
                                                          color: Colors
                                                              .grey.shade200),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          currentTitle,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 17,
                                                          ),
                                                        ),
                                                      ),
                                                      if (_tabIndex != 2)
                                                        FilledButton.icon(
                                                          style: FilledButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                primary,
                                                          ),
                                                          onPressed: () =>
                                                              selectTab(2),
                                                          icon: const Icon(
                                                              Icons
                                                                  .add_shopping_cart_rounded,
                                                              size: 17),
                                                          label: Text(s.t(
                                                              'nav_new_order')),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Center(
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                              maxWidth: 1200),
                                                      child:
                                                          allPages[_tabIndex],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  // Mobile & Narrow Viewport Layout
                                  final mobileTab =
                                      _tabIndex > 3 ? 0 : _tabIndex;
                                  return PopScope(
                                    canPop: mobileTab == 0,
                                    onPopInvokedWithResult: (didPop, _) {
                                      if (!didPop && mobileTab != 0) {
                                        selectTab(0);
                                      }
                                    },
                                    child: Scaffold(
                                      backgroundColor: const Color(0xFFF4F7F6),
                                    appBar: AppBar(
                                      title: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.asset(
                                              'assets/images/app_logo.png',
                                              width: 28,
                                              height: 28,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          const SizedBox(width: 9),
                                          Expanded(
                                            child: Text(
                                              profile.brandName,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 17),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      toolbarHeight: 52,
                                      actions: [
                                        IconButton(
                                          tooltip: s.t('tile_customers'),
                                          icon: const Icon(
                                              Icons.people_alt_outlined,
                                              size: 20),
                                          onPressed: openCustomers,
                                        ),
                                        IconButton(
                                          tooltip: s.t('bin_title'),
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 20),
                                          onPressed: openBin,
                                        ),
                                        IconButton(
                                          tooltip: s.t('app_language'),
                                          icon: Text(
                                            activeLang == 'ml' ? 'EN' : 'മ',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white),
                                          ),
                                          onPressed: () => _toggleLanguage(
                                              context, activeLang, s),
                                        ),
                                        IconButton(
                                          tooltip: s.t('tile_settings'),
                                          icon: const Icon(
                                              Icons.settings_outlined,
                                              size: 20),
                                          onPressed: openSettings,
                                        ),
                                      ],
                                    ),
                                    body: allPages[mobileTab],
                                    bottomNavigationBar: NavigationBar(
                                      height: 60,
                                      selectedIndex: mobileTab,
                                      labelBehavior:
                                          NavigationDestinationLabelBehavior
                                              .alwaysShow,
                                      onDestinationSelected: selectTab,
                                      destinations: [
                                        NavigationDestination(
                                          icon: const Icon(
                                              Icons.dashboard_outlined,
                                              size: 21),
                                          selectedIcon: const Icon(
                                              Icons.dashboard,
                                              size: 21),
                                          label: s.t('nav_home'),
                                        ),
                                        NavigationDestination(
                                          icon: const Icon(
                                              Icons
                                                  .format_list_numbered_rounded,
                                              size: 21),
                                          selectedIcon: const Icon(
                                              Icons
                                                  .format_list_numbered_rounded,
                                              size: 21),
                                          label: s.t('nav_templates'),
                                        ),
                                        NavigationDestination(
                                          icon: const Icon(
                                              Icons.add_shopping_cart_rounded,
                                              size: 21),
                                          selectedIcon: const Icon(
                                              Icons.add_shopping_cart_rounded,
                                              size: 21),
                                          label: s.t('nav_new_order'),
                                        ),
                                        NavigationDestination(
                                          icon: const Icon(
                                              Icons.receipt_long_outlined,
                                              size: 21),
                                          selectedIcon: const Icon(
                                              Icons.receipt_long,
                                              size: 21),
                                          label: s.t('nav_orders'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SidebarItem {
  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _SidebarItem({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
