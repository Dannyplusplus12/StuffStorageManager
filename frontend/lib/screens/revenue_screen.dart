import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils.dart';

enum _RevenuePeriod { day, month, year }

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  List<Order> _orders = [];
  List<Customer> _customers = [];
  List<AreaSummary> _areas = [];
  bool _loading = false;

  _RevenuePeriod _period = _RevenuePeriod.month;
  DateTime _anchorDate = DateTime.now();
  int? _selectedAreaId;
  int? _selectedCustomerId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rs = await Future.wait([
        ApiService.getManagementOrders(limit: 5000),
        ApiService.getCustomers(),
        ApiService.getAreas(),
      ]);
      if (!mounted) return;
      setState(() {
        _orders = rs[0] as List<Order>;
        _customers = rs[1] as List<Customer>;
        _areas = rs[2] as List<AreaSummary>;
        if (_selectedAreaId != null && !_areas.any((a) => a.id == _selectedAreaId)) {
          _selectedAreaId = null;
        }
        if (_selectedCustomerId != null && !_customers.any((c) => c.id == _selectedCustomerId)) {
          _selectedCustomerId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  DateTime? _parseOrderDate(String raw) {
    if (raw.trim().isEmpty) return null;
    final normalized = raw.replaceAll(' ', 'T');
    final direct = DateTime.tryParse(normalized);
    if (direct != null) return direct;

    final m = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{4})(?:\s+(\d{1,2}):(\d{1,2}))?$').firstMatch(raw.trim());
    if (m == null) return null;
    final d = int.tryParse(m.group(1) ?? '') ?? 1;
    final mo = int.tryParse(m.group(2) ?? '') ?? 1;
    final y = int.tryParse(m.group(3) ?? '') ?? 1970;
    final hh = int.tryParse(m.group(4) ?? '') ?? 0;
    final mm = int.tryParse(m.group(5) ?? '') ?? 0;
    return DateTime(y, mo, d, hh, mm);
  }

  bool _inCurrentPeriod(DateTime dt) {
    final anchor = _anchorDate;
    switch (_period) {
      case _RevenuePeriod.day:
        return dt.year == anchor.year && dt.month == anchor.month && dt.day == anchor.day;
      case _RevenuePeriod.month:
        return dt.year == anchor.year && dt.month == anchor.month;
      case _RevenuePeriod.year:
        return dt.year == anchor.year;
    }
  }

  List<Order> get _filteredOrders {
    final customerById = {for (final c in _customers) c.id: c};
    return _orders.where((o) {
      if (o.status != 'completed') return false;
      final createdAt = _parseOrderDate(o.createdAt);
      if (createdAt == null || !_inCurrentPeriod(createdAt)) return false;
      if (_selectedCustomerId != null && o.customerId != _selectedCustomerId) return false;
      if (_selectedAreaId != null) {
        final c = customerById[o.customerId];
        if (c == null || c.areaId != _selectedAreaId) return false;
      }
      return true;
    }).toList();
  }

  List<Customer> get _customersForFilter {
    final list = _selectedAreaId == null ? _customers : _customers.where((c) => c.areaId == _selectedAreaId).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  int get _totalRevenue => _filteredOrders.fold<int>(0, (s, o) => s + o.totalAmount);

  int get _orderCount => _filteredOrders.length;

  int get _customerCount {
    final keys = <String>{};
    for (final o in _filteredOrders) {
      if (o.customerId != null) {
        keys.add('id_${o.customerId}');
      } else {
        final name = o.customerName.trim();
        keys.add(name.isEmpty ? 'guest' : 'name_${name.toLowerCase()}');
      }
    }
    return keys.length;
  }

  List<_RevenueBucket> get _breakdown {
    final orders = _filteredOrders;
    final amountByKey = <String, int>{};
    final countByKey = <String, int>{};

    for (final o in orders) {
      final dt = _parseOrderDate(o.createdAt);
      if (dt == null) continue;
      final key = _bucketKeyForDate(dt);
      amountByKey[key] = (amountByKey[key] ?? 0) + o.totalAmount;
      countByKey[key] = (countByKey[key] ?? 0) + 1;
    }

    return _periodSlots()
        .map(
          (s) => _RevenueBucket(
            key: s.key,
            label: s.label,
            amount: amountByKey[s.key] ?? 0,
            orderCount: countByKey[s.key] ?? 0,
            nextPeriod: s.nextPeriod,
            nextAnchorDate: s.nextAnchorDate,
          ),
        )
        .toList();
  }

  String _bucketKeyForDate(DateTime dt) {
    switch (_period) {
      case _RevenuePeriod.day:
        return 'h_${dt.hour}';
      case _RevenuePeriod.month:
        return 'd_${dt.day}';
      case _RevenuePeriod.year:
        return 'm_${dt.month}';
    }
  }

  List<_PeriodSlot> _periodSlots() {
    final anchor = _anchorDate;
    switch (_period) {
      case _RevenuePeriod.day:
        return List.generate(
          24,
          (i) => _PeriodSlot(
            key: 'h_$i',
            label: '${i.toString().padLeft(2, '0')}:00 - ${i.toString().padLeft(2, '0')}:59',
          ),
        );
      case _RevenuePeriod.month:
        final lastDay = DateTime(anchor.year, anchor.month + 1, 0);
        final out = <_PeriodSlot>[];
        for (var day = 1; day <= lastDay.day; day++) {
          final d = DateTime(anchor.year, anchor.month, day);
          out.add(
            _PeriodSlot(
              key: 'd_$day',
              label: '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
              nextPeriod: _RevenuePeriod.day,
              nextAnchorDate: d,
            ),
          );
        }
        return out;
      case _RevenuePeriod.year:
        return List.generate(
          12,
          (i) {
            final month = i + 1;
            return _PeriodSlot(
              key: 'm_$month',
              label: 'Tháng ${month.toString().padLeft(2, '0')}/${anchor.year}',
              nextPeriod: _RevenuePeriod.month,
              nextAnchorDate: DateTime(anchor.year, month, 1),
            );
          },
        );
    }
  }

  String _dateOnly(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String get _selectedTimeLabel {
    final anchor = _anchorDate;
    switch (_period) {
      case _RevenuePeriod.day:
        return 'Ngày ${_dateOnly(anchor)}';
      case _RevenuePeriod.month:
        return 'Tháng ${anchor.month.toString().padLeft(2, '0')}/${anchor.year}';
      case _RevenuePeriod.year:
        return 'Năm ${anchor.year}';
    }
  }

  void _onBucketTap(_RevenueBucket b) {
    if (b.nextPeriod == null || b.nextAnchorDate == null) return;
    setState(() {
      _period = b.nextPeriod!;
      _anchorDate = b.nextAnchorDate!;
    });
  }

  ({_RevenuePeriod period, DateTime anchor})? get _backTarget {
    switch (_period) {
      case _RevenuePeriod.day:
        return (period: _RevenuePeriod.month, anchor: DateTime(_anchorDate.year, _anchorDate.month, 1));
      case _RevenuePeriod.month:
        return (period: _RevenuePeriod.year, anchor: DateTime(_anchorDate.year, 1, 1));
      case _RevenuePeriod.year:
        return null;
    }
  }

  void _goBackLevel() {
    final target = _backTarget;
    if (target == null) return;
    setState(() {
      _period = target.period;
      _anchorDate = target.anchor;
    });
  }

  Future<void> _pickAnchorDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      locale: const Locale('vi', 'VN'),
      helpText: 'Chọn mốc thời gian',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked == null) return;
    setState(() {
      _anchorDate = _period == _RevenuePeriod.day
          ? DateTime(picked.year, picked.month, picked.day)
          : (_period == _RevenuePeriod.month ? DateTime(picked.year, picked.month, 1) : DateTime(picked.year, 1, 1));
    });
  }

  List<_TopCustomerRevenue> get _topCustomers {
    final customerById = {for (final c in _customers) c.id: c};
    final map = <int, int>{};
    for (final o in _filteredOrders) {
      final cid = o.customerId;
      if (cid == null) continue;
      map[cid] = (map[cid] ?? 0) + o.totalAmount;
    }

    final items = map.entries
        .map((e) => _TopCustomerRevenue(
              customerId: e.key,
              customerName: customerById[e.key]?.name ?? 'Khách #${e.key}',
              areaName: customerById[e.key]?.areaName ?? '',
              revenue: e.value,
            ))
        .toList();

    items.sort((a, b) => b.revenue.compareTo(a.revenue));
    return items;
  }

  List<Order> get _dayOrders {
    final list = _filteredOrders.toList();
    list.sort((a, b) {
      final ad = _parseOrderDate(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = _parseOrderDate(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return list;
  }

  ({String color, String size}) _splitVariantInfo(String raw) {
    if (raw.contains('-')) {
      final p = raw.split('-');
      return (color: p.first.trim(), size: p.sublist(1).join('-').trim());
    }
    if (raw.contains('/')) {
      final p = raw.split('/');
      return (color: p.first.trim(), size: p.sublist(1).join('/').trim());
    }
    return (color: raw.trim(), size: '');
  }

  String _timeOnly(String raw) {
    final dt = _parseOrderDate(raw);
    if (dt == null) return raw;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _periodLabel(_RevenuePeriod p) {
    switch (p) {
      case _RevenuePeriod.day:
        return 'Ngày';
      case _RevenuePeriod.month:
        return 'Tháng';
      case _RevenuePeriod.year:
        return 'Năm';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = appTextPrimary(context);
    final textSecondary = appTextSecondary(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Doanh thu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 2),
                    Text('Theo dõi doanh thu theo thời gian, khu vực và khách hàng', style: TextStyle(color: textSecondary)),
                    const SizedBox(height: 2),
                    Text('Đang xem: $_selectedTimeLabel', style: TextStyle(color: textSecondary, fontSize: 13)),
                    const SizedBox(height: 10),
                    _filterPanel(),
                    const SizedBox(height: 10),
                    _summaryPanel(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: _breakdownPanel()),
                          const SizedBox(width: 10),
                          Expanded(flex: 2, child: _topCustomerPanel()),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _filterPanel() {
    final customerOptions = _customersForFilter;
    final selectedCustomerStillValid = _selectedCustomerId == null || customerOptions.any((c) => c.id == _selectedCustomerId);
    final customerSelection = selectedCustomerStillValid ? _selectedCustomerId : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appPanelBg(context),
        border: Border.all(color: appBorderColor(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<_RevenuePeriod>(
              initialValue: _period,
              decoration: const InputDecoration(labelText: 'Theo kỳ'),
              items: _RevenuePeriod.values
                  .map((p) => DropdownMenuItem<_RevenuePeriod>(value: p, child: Text(_periodLabel(p))))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _period = v);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: OutlinedButton.icon(
                onPressed: _pickAnchorDate,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(_selectedTimeLabel),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<int?>(
              initialValue: _selectedAreaId,
              decoration: const InputDecoration(labelText: 'Khu vực'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Tất cả khu vực')),
                ..._areas.map((a) => DropdownMenuItem<int?>(value: a.id, child: Text(a.name))),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedAreaId = v;
                  if (_selectedCustomerId != null && !_customersForFilter.any((c) => c.id == _selectedCustomerId)) {
                    _selectedCustomerId = null;
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownMenu<int?>(
              key: ValueKey('customer_filter_$customerSelection'),
              initialSelection: customerSelection,
              requestFocusOnTap: true,
              enableFilter: true,
              enableSearch: true,
              expandedInsets: EdgeInsets.zero,
              hintText: 'Tất cả khách hàng',
              label: const Text('Khách hàng'),
              menuHeight: 340,
              dropdownMenuEntries: [
                const DropdownMenuEntry<int?>(value: null, label: 'Tất cả khách hàng'),
                ...customerOptions.map(
                  (c) => DropdownMenuEntry<int?>(value: c.id, label: c.name),
                ),
              ],
              onSelected: (v) {
                setState(() => _selectedCustomerId = v);
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Làm mới'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPanel() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: 'Tổng doanh thu',
            value: '${formatCurrency(_totalRevenue)} k',
            icon: Icons.payments_outlined,
            iconColor: kSuccess,
            bgColor: const Color(0xFFF0FDF4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: 'Số đơn hoàn tất',
            value: '$_orderCount đơn',
            icon: Icons.receipt_long_outlined,
            iconColor: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: 'Số lượng khách hàng',
            value: '$_customerCount khách',
            icon: Icons.people_alt_outlined,
            iconColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appPanelBg(context),
        border: Border.all(color: appBorderColor(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: appTextSecondary(context), fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: appTextPrimary(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownPanel() {
    if (_period == _RevenuePeriod.day) {
      return _dayOrdersPanel();
    }

    final buckets = _breakdown;
    final maxAmount = buckets.fold<int>(0, (s, b) => b.amount > s ? b.amount : s);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appPanelBg(context),
        border: Border.all(color: appBorderColor(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text('Chi tiết theo ${_periodLabel(_period).toLowerCase()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: appTextPrimary(context))),
              ),
              if (_backTarget != null)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: TextButton.icon(
                    onPressed: _goBackLevel,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text('Về ${_periodLabel(_backTarget!.period).toLowerCase()}'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(_selectedTimeLabel, style: TextStyle(fontSize: 12, color: appTextSecondary(context))),
          const SizedBox(height: 2),
          if (_period != _RevenuePeriod.day)
            Text('Bấm vào từng dòng để xem cấp chi tiết tiếp theo', style: TextStyle(fontSize: 12, color: appTextSecondary(context))),
          const SizedBox(height: 8),
          Expanded(
            child: buckets.isEmpty
                ? Center(child: Text('Chưa có dữ liệu doanh thu', style: TextStyle(color: appTextSecondary(context))))
                : ListView.separated(
                    itemCount: buckets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final b = buckets[i];
                      final ratio = maxAmount <= 0 ? 0.0 : b.amount / maxAmount;
                      final canDrilldown = b.nextPeriod != null && b.nextAnchorDate != null;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          mouseCursor: canDrilldown ? SystemMouseCursors.click : SystemMouseCursors.basic,
                          onTap: canDrilldown ? () => _onBucketTap(b) : null,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: appPanelSoftBg(context),
                              border: Border.all(color: appBorderColor(context)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(b.label, style: TextStyle(fontWeight: FontWeight.w600, color: appTextPrimary(context))),
                                    ),
                                    if (canDrilldown)
                                      Padding(
                                        padding: EdgeInsets.only(right: 6),
                                       child: Icon(Icons.subdirectory_arrow_right, size: 16, color: appTextSecondary(context)),
                                      ),
                                    Text('${formatCurrency(b.amount)} k', style: TextStyle(fontWeight: FontWeight.w700, color: appTextPrimary(context))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    minHeight: 9,
                                    value: ratio,
                                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF263449) : const Color(0xFFE2E8F0),
                                    color: kPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('${b.orderCount} đơn', style: TextStyle(fontSize: 12, color: appTextSecondary(context))),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _topCustomerPanel() {
    final list = _topCustomers;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appPanelBg(context),
        border: Border.all(color: appBorderColor(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top khách hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: appTextPrimary(context))),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text('Chưa có dữ liệu', style: TextStyle(color: appTextSecondary(context))))
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final t = list[i];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: appPanelSoftBg(context),
                          border: Border.all(color: appBorderColor(context)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF263449) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                               child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w700, color: appTextPrimary(context))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                   Text(t.customerName, style: TextStyle(fontWeight: FontWeight.w600, color: appTextPrimary(context))),
                                  if (t.areaName.trim().isNotEmpty)
                                     Text(t.areaName, style: TextStyle(fontSize: 12, color: appTextSecondary(context))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${formatCurrency(t.revenue)} k', style: const TextStyle(fontWeight: FontWeight.w700, color: kSuccess)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dayOrdersPanel() {
    final orders = _dayOrders;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appPanelBg(context),
        border: Border.all(color: appBorderColor(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Chi tiết hóa đơn theo ngày', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: appTextPrimary(context))),
              ),
              if (_backTarget != null)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: TextButton.icon(
                    onPressed: _goBackLevel,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text('Về ${_periodLabel(_backTarget!.period).toLowerCase()}'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(_selectedTimeLabel, style: TextStyle(fontSize: 12, color: appTextSecondary(context))),
          const SizedBox(height: 8),
          Expanded(
            child: orders.isEmpty
                ? Center(child: Text('Không có hóa đơn trong ngày đã chọn', style: TextStyle(color: appTextSecondary(context))))
                : ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final o = orders[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: appPanelSoftBg(context),
                          border: Border.all(color: appBorderColor(context)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '#${o.id} · ${o.customerName.isEmpty ? 'Khách lẻ' : o.customerName}',
                                     style: TextStyle(fontWeight: FontWeight.w600, color: appTextPrimary(context)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('${formatCurrency(o.totalAmount)} k', style: TextStyle(fontWeight: FontWeight.w700, color: appTextPrimary(context))),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Text('Giờ ${_timeOnly(o.createdAt)}', style: TextStyle(color: appTextSecondary(context), fontSize: 12)),
                                  const SizedBox(width: 10),
                                  Text('SL ${o.totalQty}', style: TextStyle(color: appTextSecondary(context), fontSize: 12)),
                                  const SizedBox(width: 10),
                                  Text('Mục hàng ${o.items.length}', style: TextStyle(color: appTextSecondary(context), fontSize: 12)),
                                ],
                              ),
                            ),
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: kBorder),
                                  borderRadius: BorderRadius.circular(6),
                                   color: appPanelBg(context),
                                ),
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(2.2),
                                    1: FlexColumnWidth(1.3),
                                    2: FlexColumnWidth(1),
                                    3: FlexColumnWidth(0.7),
                                    4: FlexColumnWidth(1.2),
                                    5: FlexColumnWidth(1.3),
                                  },
                                   border: TableBorder.symmetric(inside: BorderSide(color: appBorderColor(context))),
                                  children: [
                                     TableRow(
                                       decoration: BoxDecoration(color: appPanelSoftBg(context)),
                                      children: [
                                        Padding(padding: EdgeInsets.all(6), child: Text('Mẫu', style: TextStyle(fontWeight: FontWeight.bold))),
                                        Padding(padding: EdgeInsets.all(6), child: Text('Màu', style: TextStyle(fontWeight: FontWeight.bold))),
                                        Padding(padding: EdgeInsets.all(6), child: Text('Size', style: TextStyle(fontWeight: FontWeight.bold))),
                                        Padding(padding: EdgeInsets.all(6), child: Text('SL', style: TextStyle(fontWeight: FontWeight.bold))),
                                        Padding(padding: EdgeInsets.all(6), child: Text('Đơn giá', style: TextStyle(fontWeight: FontWeight.bold))),
                                        Padding(padding: EdgeInsets.all(6), child: Text('Tiền', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                    ...o.items.map((it) {
                                      final parsed = _splitVariantInfo(it.variantInfo);
                                      final lineMoney = it.quantity * it.price;
                                      return TableRow(
                                        children: [
                                          Padding(padding: const EdgeInsets.all(6), child: Text(it.productName)),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(parsed.color.isEmpty ? '-' : parsed.color)),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(parsed.size.isEmpty ? '-' : parsed.size)),
                                          Padding(padding: const EdgeInsets.all(6), child: Text('${it.quantity}')),
                                          Padding(padding: const EdgeInsets.all(6), child: Text('${formatCurrency(it.price)} k')),
                                          Padding(padding: const EdgeInsets.all(6), child: Text('${formatCurrency(lineMoney)} k')),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RevenueBucket {
  final String key;
  final String label;
  final int amount;
  final int orderCount;
  final _RevenuePeriod? nextPeriod;
  final DateTime? nextAnchorDate;

  const _RevenueBucket({
    required this.key,
    required this.label,
    required this.amount,
    required this.orderCount,
    this.nextPeriod,
    this.nextAnchorDate,
  });
}

class _PeriodSlot {
  final String key;
  final String label;
  final _RevenuePeriod? nextPeriod;
  final DateTime? nextAnchorDate;

  const _PeriodSlot({
    required this.key,
    required this.label,
    this.nextPeriod,
    this.nextAnchorDate,
  });
}

class _TopCustomerRevenue {
  final int customerId;
  final String customerName;
  final String areaName;
  final int revenue;

  const _TopCustomerRevenue({
    required this.customerId,
    required this.customerName,
    required this.areaName,
    required this.revenue,
  });
}
