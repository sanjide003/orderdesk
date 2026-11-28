import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../services/app_strings.dart';
import '../services/firestore_service.dart';
import '../widgets/message_history_view.dart';

class MessageHistoryScreen extends StatelessWidget {
  final FirestoreService service;
  final BusinessProfile profile;
  final AppStrings s;
  final bool embedded;

  const MessageHistoryScreen({
    super.key,
    required this.service,
    required this.profile,
    required this.s,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: service.languageNotifier,
      builder: (context, langOverride, _) {
        return StreamBuilder<BusinessProfile>(
          stream: service.watchBusinessProfile(),
          initialData: profile,
          builder: (context, profSnap) {
            final liveProfile = profSnap.data ?? profile;
            final activeStrings =
                AppStrings(langOverride ?? liveProfile.appLanguage);
            final primary = Color(
                service.colorNotifier.value ?? liveProfile.primaryColorHex);

            return Scaffold(
              backgroundColor: embedded
                  ? Colors.transparent
                  : const Color(0xFFF4F7F6),
              appBar: embedded
                  ? null
                  : AppBar(
                      title: Text(activeStrings.t('message_history_title')),
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                    ),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: MessageHistoryView(
                    service: service,
                    s: activeStrings,
                    primaryColor: primary,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
