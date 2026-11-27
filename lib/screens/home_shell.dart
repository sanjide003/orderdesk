import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/delivery_rules.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
import '../services/app_strings.dart';
import '../services/firestore_service.dart';
import '../services/lakfa_seed_data.dart';
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
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BusinessProfile>(
      stream: _service.watchBusinessProfile(),
      builder: (context, profileSnap) {
        final profile = profileSnap.data ?? LakfaSeedData.profile;
        final s = AppStrings(profile.appLanguage);
        final primary = Color(profile.primaryColorHex);

        return Theme(
          data: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: primary,
            scaffoldBackgroundColor: const Color(0xFFF4F7F6),
          ),
          child: StreamBuilder<DeliveryRules>(
            stream: _service.watchDeliveryRules(),
            builder: (context, rulesSnap) {
              final rules = rulesSnap.data ?? LakfaSeedData.deliveryRules;
              return StreamBuilder<List<ProductModel>>(
                stream: _service.watchProducts(),
                builder: (context, prodSnap) {
                  final products = prodSnap.data ?? LakfaSeedData.products;
                  return StreamBuilder<List<TemplateModel>>(
                    stream: _service.watchTemplates(),
                    builder: (context, tplSnap) {
                      final templates = tplSnap.data ?? LakfaSeedData.templates;
                      return StreamBuilder<List<OrderModel>>(
                        stream: _service.watchOrders(),
                        builder: (context, ordSnap) {
                          final orders = ordSnap.data ?? [];

                          void openProducts() {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductsScreen(
                                  service: _service,
                                  products: products,
                                  s: s,
                                ),
                              ),
                            );
                          }

                          void openSettings() {
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

                          final pages = [
                            DashboardScreen(
                              profile: profile,
                              orders: orders,
                              s: s,
                              onNavigateTab: (i) =>
                                  setState(() => _tabIndex = i),
                              onOpenProducts: openProducts,
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
                            ),
                            OrdersScreen(
                              service: _service,
                              profile: profile,
                              products: products,
                              templates: templates,
                              orders: orders,
                              s: s,
                            ),
                          ];

                          return Scaffold(
                            appBar: AppBar(
                              title: Text(
                                profile.brandName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 17),
                              ),
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              toolbarHeight: 52,
                              actions: [
                                IconButton(
                                  tooltip: s.t('app_language'),
                                  icon: Text(
                                    profile.appLanguage == 'ml' ? 'EN' : 'മ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white),
                                  ),
                                  onPressed: () => _service.updateAppLanguage(
                                      profile.appLanguage == 'ml'
                                          ? 'en'
                                          : 'ml'),
                                ),
                                IconButton(
                                  tooltip: s.t('tile_settings'),
                                  icon: const Icon(Icons.settings_outlined,
                                      size: 20),
                                  onPressed: openSettings,
                                ),
                              ],
                            ),
                            body: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 680),
                                child: pages[_tabIndex],
                              ),
                            ),
                            bottomNavigationBar: NavigationBar(
                              height: 60,
                              selectedIndex: _tabIndex,
                              labelBehavior:
                                  NavigationDestinationLabelBehavior.alwaysShow,
                              onDestinationSelected: (i) =>
                                  setState(() => _tabIndex = i),
                              destinations: [
                                NavigationDestination(
                                  icon: const Icon(Icons.dashboard_outlined,
                                      size: 21),
                                  selectedIcon:
                                      const Icon(Icons.dashboard, size: 21),
                                  label: s.t('nav_home'),
                                ),
                                NavigationDestination(
                                  icon: const Icon(
                                      Icons.format_list_numbered_rounded,
                                      size: 21),
                                  selectedIcon: const Icon(
                                      Icons.format_list_numbered_rounded,
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
                                  icon: const Icon(Icons.receipt_long_outlined,
                                      size: 21),
                                  selectedIcon:
                                      const Icon(Icons.receipt_long, size: 21),
                                  label: s.t('nav_orders'),
                                ),
                              ],
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
  }
}
