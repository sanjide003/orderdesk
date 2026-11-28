import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message_log_model.dart';
import '../services/app_strings.dart';
import '../services/firestore_service.dart';
import 'whatsapp_rich_text.dart';

enum MessageTimePreset { all, today, yesterday, last7Days, custom }

class MessageHistoryView extends StatefulWidget {
  final FirestoreService service;
  final AppStrings s;
  final Color primaryColor;
  final String? filterOrderId;
  final String? filterCustomerPhone;
  final String? headerSubtitle;
  final bool compact;

  const MessageHistoryView({
    super.key,
    required this.service,
    required this.s,
    required this.primaryColor,
    this.filterOrderId,
    this.filterCustomerPhone,
    this.headerSubtitle,
    this.compact = false,
  });

  @override
  State<MessageHistoryView> createState() => _MessageHistoryViewState();
}

class _MessageHistoryViewState extends State<MessageHistoryView> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  MessageTimePreset _preset = MessageTimePreset.all;
  String _modeFilter = '';
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomDateTimeRange() async {
    final now = DateTime.now();
    final initialStart =
        _customStart ?? DateTime(now.year, now.month, now.day);
    final initialEnd = _customEnd ?? now;

    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(now.year + 2),
      initialDateRange: DateTimeRange(
        start: DateTime(initialStart.year, initialStart.month, initialStart.day),
        end: DateTime(initialEnd.year, initialEnd.month, initialEnd.day),
      ),
    );
    if (pickedRange == null || !mounted) return;

    final startTime = await showTimePicker(
      context: context,
      helpText: widget.s.t('from_time'),
      initialTime: TimeOfDay(
        hour: _customStart?.hour ?? 0,
        minute: _customStart?.minute ?? 0,
      ),
    );
    if (!mounted) return;

    final endTime = await showTimePicker(
      context: context,
      helpText: widget.s.t('to_time'),
      initialTime: TimeOfDay(
        hour: _customEnd?.hour ?? 23,
        minute: _customEnd?.minute ?? 59,
      ),
    );
    if (!mounted) return;

    final sTime = startTime ?? const TimeOfDay(hour: 0, minute: 0);
    final eTime = endTime ?? const TimeOfDay(hour: 23, minute: 59);

    var startDt = DateTime(
      pickedRange.start.year,
      pickedRange.start.month,
      pickedRange.start.day,
      sTime.hour,
      sTime.minute,
      0,
    );
    var endDt = DateTime(
      pickedRange.end.year,
      pickedRange.end.month,
      pickedRange.end.day,
      eTime.hour,
      eTime.minute,
      59,
    );
    if (endDt.isBefore(startDt)) {
      final tmp = startDt;
      startDt = endDt;
      endDt = tmp;
    }

    setState(() {
      _preset = MessageTimePreset.custom;
      _customStart = startDt;
      _customEnd = endDt;
    });
  }

  bool _matchesTime(MessageLogModel log) {
    final local = log.sentAt.toLocal();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (_preset) {
      case MessageTimePreset.all:
        return true;
      case MessageTimePreset.today:
        return !local.isBefore(todayStart);
      case MessageTimePreset.yesterday:
        final yStart = todayStart.subtract(const Duration(days: 1));
        return !local.isBefore(yStart) && local.isBefore(todayStart);
      case MessageTimePreset.last7Days:
        final wStart = todayStart.subtract(const Duration(days: 6));
        return !local.isBefore(wStart);
      case MessageTimePreset.custom:
        if (_customStart != null && local.isBefore(_customStart!)) return false;
        if (_customEnd != null && local.isAfter(_customEnd!)) return false;
        return true;
    }
  }

  String _modeLabel(String mode) {
    final s = widget.s;
    switch (mode) {
      case 'bulk_queue':
        return s.t('mode_bulk');
      case 'order_stage':
        return s.t('mode_order');
      case 'template':
        return s.t('mode_template');
      default:
        return s.t('mode_direct');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final primary = widget.primaryColor;
    final filterNormPhone = widget.filterCustomerPhone != null &&
            widget.filterCustomerPhone!.trim().isNotEmpty
        ? FirestoreService.normalizePhoneKey(widget.filterCustomerPhone!)
        : '';

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            widget.compact ? 12 : 16,
            10,
            widget.compact ? 12 : 16,
            10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.headerSubtitle != null &&
                  widget.headerSubtitle!.isNotEmpty) ...[
                Text(
                  widget.headerSubtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  labelText: s.t('message_history_title'),
                  hintText: s.t('search_logs_hint'),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _timeChip(MessageTimePreset.all, s.t('filter_time_all')),
                    const SizedBox(width: 6),
                    _timeChip(
                        MessageTimePreset.today, s.t('filter_time_today')),
                    const SizedBox(width: 6),
                    _timeChip(MessageTimePreset.yesterday,
                        s.t('filter_time_yesterday')),
                    const SizedBox(width: 6),
                    _timeChip(MessageTimePreset.last7Days,
                        s.t('filter_time_7days')),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: Icon(
                        Icons.date_range_rounded,
                        size: 15,
                        color: _preset == MessageTimePreset.custom
                            ? Colors.white
                            : primary,
                      ),
                      backgroundColor: _preset == MessageTimePreset.custom
                          ? primary
                          : Colors.grey.shade200,
                      label: Text(
                        _preset == MessageTimePreset.custom &&
                                _customStart != null &&
                                _customEnd != null
                            ? '${DateFormat('dd MMM HH:mm').format(_customStart!)} - ${DateFormat('dd MMM HH:mm').format(_customEnd!)}'
                            : s.t('filter_time_custom'),
                        style: TextStyle(
                          fontSize: 11,
                          color: _preset == MessageTimePreset.custom
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: _pickCustomDateTimeRange,
                    ),
                  ],
                ),
              ),
              if (widget.filterOrderId == null) ...[
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _modeChip('', s.t('all')),
                      const SizedBox(width: 6),
                      _modeChip('order_stage', s.t('mode_order')),
                      const SizedBox(width: 6),
                      _modeChip('bulk_queue', s.t('mode_bulk')),
                      const SizedBox(width: 6),
                      _modeChip('template', s.t('mode_template')),
                      const SizedBox(width: 6),
                      _modeChip('direct', s.t('mode_direct')),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<MessageLogModel>>(
            stream: widget.service.watchMessageLogs(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final allLogs = snap.data ?? [];
              final filtered = allLogs.where((log) {
                if (widget.filterOrderId != null &&
                    widget.filterOrderId!.isNotEmpty) {
                  final matchOrder = log.orderId == widget.filterOrderId;
                  final matchPhone = filterNormPhone.isNotEmpty &&
                      log.normalizedPhone == filterNormPhone;
                  if (!matchOrder && !matchPhone) return false;
                } else if (filterNormPhone.isNotEmpty) {
                  if (log.normalizedPhone != filterNormPhone) return false;
                }

                if (_modeFilter.isNotEmpty && log.mode != _modeFilter) {
                  return false;
                }
                if (!_matchesTime(log)) return false;

                if (_query.isNotEmpty) {
                  final q = _query.toLowerCase();
                  final match = log.recipientName.toLowerCase().contains(q) ||
                      log.phone.contains(q) ||
                      log.templateTitle.toLowerCase().contains(q) ||
                      log.messagePreview.toLowerCase().contains(q);
                  if (!match) return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded,
                            size: 46, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text(
                          s.t('no_messages_logged'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final log = filtered[i];
                  final localTime = log.sentAt.toLocal();
                  final formattedTime =
                      DateFormat('dd MMM yyyy · hh:mm:ss a').format(localTime);
                  final title = log.recipientName.isNotEmpty
                      ? '${log.recipientName} · ${log.phone}'
                      : (log.phone.isNotEmpty ? log.phone : 'WhatsApp');
                  final subtitleParts = <String>[
                    _modeLabel(log.mode),
                    if (log.templateTitle.isNotEmpty) log.templateTitle,
                    formattedTime,
                  ];

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitleParts.join(' · '),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade700,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              DateFormat('hh:mm a').format(localTime),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: primary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (log.messagePreview.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7FFDB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: WhatsAppRichText(
                              text: log.messagePreview,
                              baseStyle: const TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Color(0xFF111B21),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _timeChip(MessageTimePreset preset, String label) {
    final selected = _preset == preset;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      selectedColor: widget.primaryColor,
      backgroundColor: Colors.grey.shade200,
      onSelected: (_) => setState(() => _preset = preset),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _modeChip(String mode, String label) {
    final selected = _modeFilter == mode;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      selectedColor: const Color(0xFF334155),
      backgroundColor: Colors.grey.shade100,
      onSelected: (_) => setState(() => _modeFilter = mode),
      visualDensity: VisualDensity.compact,
    );
  }
}

Future<void> showOrderMessageHistorySheet({
  required BuildContext context,
  required FirestoreService service,
  required AppStrings s,
  required Color primaryColor,
  required String orderId,
  required String customerName,
  required String phone,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${s.t("message_history_title")} · $customerName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: MessageHistoryView(
              service: service,
              s: s,
              primaryColor: primaryColor,
              filterOrderId: orderId,
              filterCustomerPhone: phone,
              compact: true,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showCustomerMessageHistorySheet({
  required BuildContext context,
  required FirestoreService service,
  required AppStrings s,
  required Color primaryColor,
  required String customerName,
  required String phone,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${s.t("message_history_title")} · $customerName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: MessageHistoryView(
              service: service,
              s: s,
              primaryColor: primaryColor,
              filterCustomerPhone: phone,
              headerSubtitle: phone,
              compact: true,
            ),
          ),
        ],
      ),
    ),
  );
}
