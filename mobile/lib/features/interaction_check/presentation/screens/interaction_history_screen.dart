import 'package:flutter/material.dart';

import '../../domain/entities/interaction_check_result.dart';

/// Dữ liệu một lần kiểm tra tương tác thuốc (theo Figma S06e / S06e-1)
class InteractionHistoryItem {
  const InteractionHistoryItem({
    required this.id,
    required this.checkedAt,
    required this.medicationCount,
    required this.status,
    required this.findings,
    required this.allMedicationNames,
    this.userActions = const [],
  });

  final String id;
  final DateTime checkedAt;
  final int medicationCount;
  final InteractionCheckStatus status;
  final List<InteractionFinding> findings;
  final List<String> allMedicationNames;
  final List<String> userActions;

  bool get hasIssues => findings.isNotEmpty;
  int get maxSeverity => findings.isEmpty
      ? 0
      : findings.map((f) => f.severityLevel).reduce((a, b) => a > b ? a : b);
}

enum InteractionFilter {
  all('Tất cả'),
  needAttention('Cần theo dõi'),
  safe('An toàn');

  const InteractionFilter(this.label);
  final String label;
}

/// S06e · Lịch sử kiểm tra tương tác thuốc (Figma node-id=846-17942)
class InteractionHistoryScreen extends StatefulWidget {
  const InteractionHistoryScreen({
    super.key,
    this.initialItems,
    this.onRecheck,
  });

  final List<InteractionHistoryItem>? initialItems;
  final VoidCallback? onRecheck;

  @override
  State<InteractionHistoryScreen> createState() => _InteractionHistoryScreenState();
}

class _InteractionHistoryScreenState extends State<InteractionHistoryScreen> {
  InteractionFilter _currentFilter = InteractionFilter.all;
  late List<InteractionHistoryItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems ?? _sampleHistory();
  }

  static List<InteractionHistoryItem> _sampleHistory() {
    return [
      InteractionHistoryItem(
        id: 'hist-1',
        checkedAt: DateTime(2026, 11, 20, 9, 30),
        medicationCount: 4,
        status: InteractionCheckStatus.found,
        allMedicationNames: const [
          'Paracetamol 500mg',
          'Warfarin 5mg',
          'Metformin 500mg',
          'Vitamin D3 1000 IU',
        ],
        findings: const [
          InteractionFinding(
            ingredientAId: 101,
            ingredientAName: 'Paracetamol',
            ingredientBId: 202,
            ingredientBName: 'Warfarin',
            medicationAName: 'Paracetamol 500mg',
            medicationBName: 'Warfarin 5mg',
            severityLevel: 3,
            interactionType: 'drug_drug',
            handlingType: 'can_nhac_loi_ich_nguy_co',
            description:
                'Paracetamol dùng liều cao kéo dài làm tăng tác dụng chống đông của Warfarin, dẫn tới nguy cơ xuất huyết.',
            warningMessage:
                'Nguy cơ xuất huyết cao khi phối hợp. Cần tham khảo ý kiến bác sĩ để theo dõi chỉ số đông máu INR.',
            source: 'Dược thư Quốc gia Việt Nam',
          ),
        ],
        userActions: const ['Đã hỏi bác sĩ', 'Theo dõi INR'],
      ),
      InteractionHistoryItem(
        id: 'hist-2',
        checkedAt: DateTime(2026, 11, 15, 14, 15),
        medicationCount: 3,
        status: InteractionCheckStatus.found,
        allMedicationNames: const [
          'Metformin 500mg',
          'Cimetidine 400mg',
          'Losartan 50mg',
        ],
        findings: const [
          InteractionFinding(
            ingredientAId: 301,
            ingredientAName: 'Metformin',
            ingredientBId: 302,
            ingredientBName: 'Cimetidine',
            medicationAName: 'Metformin 500mg',
            medicationBName: 'Cimetidine 400mg',
            severityLevel: 2,
            interactionType: 'drug_drug',
            handlingType: 'can_than_trong',
            description:
                'Cimetidine làm giảm thải trừ Metformin qua thận, có thể làm tăng nồng độ Metformin trong huyết tương.',
            warningMessage:
                'Cần thận trọng và theo dõi chức năng thận cũng như đường huyết.',
            source: 'Bộ Y Tế',
          ),
        ],
      ),
      InteractionHistoryItem(
        id: 'hist-3',
        checkedAt: DateTime(2026, 10, 28, 10, 0),
        medicationCount: 3,
        status: InteractionCheckStatus.noneFound,
        allMedicationNames: const [
          'Metformin 500mg',
          'Losartan 50mg',
          'Vitamin D3 1000 IU',
        ],
        findings: const [],
      ),
      InteractionHistoryItem(
        id: 'hist-4',
        checkedAt: DateTime(2026, 10, 10, 16, 45),
        medicationCount: 2,
        status: InteractionCheckStatus.found,
        allMedicationNames: const [
          'Aspirin 81mg',
          'Ibuprofen 400mg',
        ],
        findings: const [
          InteractionFinding(
            ingredientAId: 401,
            ingredientAName: 'Aspirin',
            ingredientBId: 402,
            ingredientBName: 'Ibuprofen',
            medicationAName: 'Aspirin 81mg',
            medicationBName: 'Ibuprofen 400mg',
            severityLevel: 2,
            interactionType: 'drug_drug',
            handlingType: 'can_than_trong',
            description:
                'Ibuprofen có thể làm giảm tác dụng bảo vệ tim mạch của Aspirin liều thấp và tăng nguy cơ loét dạ dày.',
            warningMessage: 'Uống Ibuprofen cách xa Aspirin ít nhất 2 giờ.',
            source: 'Dược thư Quốc gia Việt Nam',
          ),
        ],
      ),
    ];
  }

  List<InteractionHistoryItem> get _filteredItems {
    return switch (_currentFilter) {
      InteractionFilter.all => _items,
      InteractionFilter.needAttention => _items.where((i) => i.hasIssues).toList(),
      InteractionFilter.safe => _items.where((i) => !i.hasIssues).toList(),
    };
  }

  void _openDetail(InteractionHistoryItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InteractionDetailSheet(item: item),
    );
  }

  void _handleRecheck() {
    if (widget.onRecheck != null) {
      widget.onRecheck!();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang tiến hành kiểm tra lại tương tác tủ thuốc...'),
        backgroundColor: Color(0xFF01554F),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final totalChecks = _items.length;
    final attentionCount = _items.where((i) => i.hasIssues).length;

    // Phân nhóm theo tháng
    final groups = <String, List<InteractionHistoryItem>>{};
    for (final item in filtered) {
      final key = 'THÁNG ${item.checkedAt.month}, ${item.checkedAt.year}';
      groups.putIfAbsent(key, () => []).add(item);
    }

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
                icon: const Icon(Icons.chevron_left, color: Color(0xFF01554F), size: 24),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ),
        ),
        title: const Text(
          'Lịch sử kiểm tra',
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
                  // 1. Summary Card (Figma Mint Card)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F3F1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFC7E3DF)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$totalChecks',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF01554F),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Lần kiểm tra',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF5B6169),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 38,
                          color: const Color(0xFFB5DCD7),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$attentionCount',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Cặp cần theo dõi',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF5B6169),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: InteractionFilter.values.map((filter) {
                        final isSelected = _currentFilter == filter;
                        final count = switch (filter) {
                          InteractionFilter.all => totalChecks,
                          InteractionFilter.needAttention => attentionCount,
                          InteractionFilter.safe => totalChecks - attentionCount,
                        };
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${filter.label} ($count)'),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _currentFilter = filter),
                            selectedColor: const Color(0xFF01554F),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF01554F)
                                  : const Color(0xFFE4E4E1),
                            ),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF5B6169),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            showCheckmark: false,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. History Groups
                  if (filtered.isEmpty)
                    _buildEmptyState()
                  else
                    for (final entry in groups.entries) ...[
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Color(0xFF254A45),
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final item in entry.value) ...[
                        _buildHistoryCard(item),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),

            // 4. Bottom Sticky Action
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
                  key: const Key('interaction-recheck-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF01554F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _handleRecheck,
                  icon: const Icon(Icons.sync, size: 20),
                  label: const Text(
                    'Kiểm tra lại ngay',
                    style: TextStyle(
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFE7F3F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF01554F),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không có lịch sử phù hợp',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF211D1D),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bạn chưa có lần kiểm tra nào thuộc bộ lọc này.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF5B6169),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(InteractionHistoryItem item) {
    final day = item.checkedAt.day.toString().padLeft(2, '0');
    final month = item.checkedAt.month.toString().padLeft(2, '0');
    final year = item.checkedAt.year;
    final hour = item.checkedAt.hour.toString().padLeft(2, '0');
    final minute = item.checkedAt.minute.toString().padLeft(2, '0');
    final dateStr = '$day/$month/$year lúc $hour:$minute';

    return InkWell(
      onTap: () => _openDetail(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E4E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Timestamp & Badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5B6169),
                    ),
                  ),
                ),
                _buildSeverityChip(item),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Drug interaction summary
            if (item.hasIssues) ...[
              for (final finding in item.findings) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.warning_amber_rounded,
                          size: 16, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${finding.ingredientAName} ⇄ ${finding.ingredientBName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF211D1D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ] else ...[
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Không phát hiện tương tác nguy cơ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),

            // Row 3: Footer count & Chevron
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.medicationCount} loại thuốc kiểm tra',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A7F85),
                    ),
                  ),
                ),
                const Text(
                  'Chi tiết',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF01554F),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: Color(0xFF01554F)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityChip(InteractionHistoryItem item) {
    if (!item.hasIssues) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F7EE),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: const Color(0xFFB7E4C7)),
        ),
        child: const Text(
          'An toàn',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF16A34A),
          ),
        ),
      );
    }

    final level = item.maxSeverity;
    final isDanger = level >= 4;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDanger ? const Color(0xFFFDECEC) : const Color(0xFFFEF3E2),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: isDanger ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A),
        ),
      ),
      child: Text(
        isDanger ? 'Mức 4: Chống chỉ định' : 'Mức $level: Cần theo dõi',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDanger ? const Color(0xFFDC2626) : const Color(0xFFD97706),
        ),
      ),
    );
  }
}

/// S06e-1 · Chi tiết lần kiểm tra (Figma node-id=846-18119)
class InteractionDetailSheet extends StatefulWidget {
  const InteractionDetailSheet({super.key, required this.item});

  final InteractionHistoryItem item;

  @override
  State<InteractionDetailSheet> createState() => _InteractionDetailSheetState();
}

class _InteractionDetailSheetState extends State<InteractionDetailSheet> {
  final Set<String> _selectedActions = {'Đã hỏi ý kiến bác sĩ'};

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final day = item.checkedAt.day.toString().padLeft(2, '0');
    final month = item.checkedAt.month.toString().padLeft(2, '0');
    final year = item.checkedAt.year;
    final hour = item.checkedAt.hour.toString().padLeft(2, '0');
    final minute = item.checkedAt.minute.toString().padLeft(2, '0');
    final dateStr = '$day/$month/$year · $hour:$minute';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFCFCFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCDCDA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chi tiết lần kiểm tra',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF211D1D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateStr · ${item.medicationCount} loại thuốc',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5B6169),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF5B6169)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Findings or Safe Box
            if (item.findings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7EE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFB7E4C7)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Không phát hiện tương tác nguy cơ nào giữa các thuốc trong lần kiểm tra này.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final finding in item.findings) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3E2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pair title
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${finding.ingredientAName} ⇄ ${finding.ingredientBName}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF211D1D),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDECEC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Mức độ ${finding.severityLevel}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Warning message
                      Text(
                        finding.warningMessage,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Mechanism & advice
                      Text(
                        finding.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5B6169),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

            // Section: Bạn đã làm gì? (Figma Action Checklist)
            const Text(
              'BẠN ĐÃ LÀM GÌ?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Color(0xFF254A45),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionChip('Đã hỏi ý kiến bác sĩ'),
                _buildActionChip('Đã giãn cách giờ uống'),
                _buildActionChip('Tạm hoãn dùng'),
                _buildActionChip('Theo dõi triệu chứng'),
              ],
            ),
            const SizedBox(height: 20),

            // List of medications checked
            const Text(
              'DANH SÁCH THUỐC TRONG LẦN KIỂM TRA',
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
                  for (int i = 0; i < item.allMedicationNames.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.medication_outlined,
                              size: 20, color: Color(0xFF01554F)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.allMedicationNames[i],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF211D1D),
                              ),
                            ),
                          ),
                          const Icon(Icons.check, size: 18, color: Color(0xFF16A34A)),
                        ],
                      ),
                    ),
                    if (i < item.allMedicationNames.length - 1)
                      const Divider(height: 1, color: Color(0xFFE4E4E1)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // NFR03 Disclaimer
            const Text(
              nfr03Disclaimer,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF7A7F85),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildActionChip(String label) {
    final isSelected = _selectedActions.contains(label);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          if (val) {
            _selectedActions.add(label);
          } else {
            _selectedActions.remove(label);
          }
        });
      },
      selectedColor: const Color(0xFFE7F3F1),
      checkmarkColor: const Color(0xFF01554F),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF01554F) : const Color(0xFFE4E4E1),
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? const Color(0xFF01554F) : const Color(0xFF5B6169),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9999),
      ),
    );
  }
}
