import 'package:flutter/material.dart';

import '../../domain/entities/adherence_history.dart';
import '../utils/adherence_history_format.dart';
import '../widgets/dose_timeline_rail.dart';
import '../widgets/history_motion.dart';

/// Màn hình S09d · Chi tiết liều dùng theo chuẩn Figma Prototype_DrugTime (node-id=74-7713)
class DoseDetailScreen extends StatefulWidget {
  const DoseDetailScreen({
    super.key,
    required this.dose,
    required this.asOf,
    this.onConfirm,
  });

  final HistoryDose dose;
  final DateTime asOf;
  final VoidCallback? onConfirm;

  @override
  State<DoseDetailScreen> createState() => _DoseDetailScreenState();
}

class _DoseDetailScreenState extends State<DoseDetailScreen> {
  late bool _confirmed;

  @override
  void initState() {
    super.initState();
    _confirmed = widget.dose.status == HistoryDoseStatus.taken ||
        widget.dose.status == HistoryDoseStatus.late;
  }

  void _handleConfirm() {
    setState(() => _confirmed = true);
    widget.onConfirm?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã xác nhận uống liều ${widget.dose.medicationName}'),
        backgroundColor: const Color(0xFF01554F),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dose = widget.dose;
    final scheduledTime = HistoryFormat.time(dose.scheduledAt);
    final upcoming = dose.status == HistoryDoseStatus.pending &&
        dose.scheduledAt.isAfter(widget.asOf);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCFCFC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFE7F3F1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_left,
                    color: Color(0xFF01554F), size: 24),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ),
        ),
        title: const Text(
          'Chi tiết liều dùng',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF211D1D),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // 1. Hero Medication Card
                  HeroMode(
                      enabled: HistoryMotion.enabled(context),
                      child: Hero(
                          tag: DoseHeroTag(dose.scheduleId, dose.scheduledAt),
                          child: Material(
                              type: MaterialType.transparency,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7F3F1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Pill icon box
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFE8D6),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.medication_outlined,
                                        color: Color(0xFFD97706),
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      dose.medicationName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF211D1D),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '1 viên · Trước ăn tối',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF5B6169),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Status pill
                                    _buildStatusChip(
                                        dose, scheduledTime, upcoming),
                                  ],
                                ),
                              )))),
                  const SizedBox(height: 20),

                  // 2. Section: THÔNG TIN LIỀU DÙNG
                  const Text(
                    'THÔNG TIN LIỀU DÙNG',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF254A45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E4E1)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 20, color: Color(0xFF5B6169)),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Giờ theo lịch',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF211D1D),
                                  ),
                                ),
                              ),
                              Text(
                                scheduledTime,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF211D1D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE4E4E1)),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(Icons.restaurant_outlined,
                                  size: 20, color: Color(0xFF5B6169)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Hướng dẫn dùng',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF211D1D),
                                  ),
                                ),
                              ),
                              Text(
                                'Trước ăn tối',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF211D1D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Section: GHI CHÚ
                  const Text(
                    'GHI CHÚ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF254A45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E4E1)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.description_outlined,
                            size: 20, color: Color(0xFFA6A6A6)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Chưa có ghi chú cho liều này',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFA6A6A6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Section: LỊCH SỬ GẦN ĐÂY
                  const Text(
                    'LỊCH SỬ GẦN ĐÂY',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF254A45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E4E1)),
                    ),
                    child: const Column(
                      children: [
                        _RecentHistoryRow(
                          icon: Icons.check_circle_outline,
                          iconColor: Color(0xFF16A34A),
                          title: 'Hôm qua · 20:00',
                          subtitle: 'Đã uống lúc 20:05',
                          subtitleColor: Color(0xFF16A34A),
                        ),
                        Divider(height: 1, color: Color(0xFFE4E4E1)),
                        _RecentHistoryRow(
                          icon: Icons.check_circle_outline,
                          iconColor: Color(0xFF16A34A),
                          title: '22/09 · 20:00',
                          subtitle: 'Đã uống đúng giờ',
                          subtitleColor: Color(0xFF16A34A),
                        ),
                        Divider(height: 1, color: Color(0xFFE4E4E1)),
                        _RecentHistoryRow(
                          icon: Icons.cancel_outlined,
                          iconColor: Color(0xFFDC2626),
                          title: '21/09 · 20:00',
                          subtitle: 'Bỏ lỡ liều',
                          subtitleColor: Color(0xFFDC2626),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom CTA
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  key: const Key('dose-confirm-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _confirmed
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF01554F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _confirmed ? null : _handleConfirm,
                  icon: const Icon(Icons.check, size: 20),
                  label: Text(
                    _confirmed ? 'Đã xác nhận uống' : '✓ Xác nhận đã uống',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(
      HistoryDose dose, String scheduledTime, bool upcoming) {
    if (_confirmed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F7EE),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: const Color(0xFFB7E4C7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
            const SizedBox(width: 6),
            Text(
              'Đã uống lúc ${dose.takenAt != null ? HistoryFormat.time(dose.takenAt!) : scheduledTime}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16A34A),
              ),
            ),
          ],
        ),
      );
    }

    if (dose.status == HistoryDoseStatus.missed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
            const SizedBox(width: 6),
            Text(
              'Bỏ lỡ · $scheduledTime',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      );
    }

    // Default upcoming / pending
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3E2),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, size: 16, color: Color(0xFFD97706)),
          const SizedBox(width: 6),
          Text(
            upcoming
                ? 'Sắp tới · $scheduledTime'
                : 'Chưa uống · $scheduledTime',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD97706),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentHistoryRow extends StatelessWidget {
  const _RecentHistoryRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF211D1D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
