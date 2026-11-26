import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/delivery_rules.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
import '../services/firestore_service.dart';
import '../services/lakfa_seed_data.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'quick_reply_screen.dart';
import 'settings_screen.dart';

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
        return StreamBuilder<DeliveryRules>(
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
                    final pages = [
                      QuickReplyScreen(
                        service: _service,
                        profile: profile,
                        rules: rules,
                        products: products,
                        templates: templates,
                      ),
                      OrdersScreen(
                        service: _service,
                        profile: profile,
                        products: products,
                        templates: templates,
                      ),
                      ProductsScreen(service: _service, products: products),
                      SettingsScreen(
                        service: _service,
                        profile: profile,
                        rules: rules,
                        templates: templates,
                      ),
                    ];

                    return Scaffold(
                      appBar: AppBar(
                        title: Text(profile.brandName),
                        backgroundColor: Color(profile.primaryColorHex),
                        foregroundColor: Colors.white,
                      ),
                      body: pages[_tabIndex],
                      bottomNavigationBar: NavigationBar(
                        selectedIndex: _tabIndex,
                        onDestinationSelected: (i) =>
                            setState(() => _tabIndex = i),
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.flash_on_outlined),
                            selectedIcon: Icon(Icons.flash_on),
                            label: 'Reply',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.receipt_long_outlined),
                            selectedIcon: Icon(Icons.receipt_long),
                            label: 'Orders',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.inventory_2_outlined),
                            selectedIcon: Icon(Icons.inventory_2),
                            label: 'Products',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.settings_outlined),
                            selectedIcon: Icon(Icons.settings),
                            label: 'Settings',
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
    );
  }
}
