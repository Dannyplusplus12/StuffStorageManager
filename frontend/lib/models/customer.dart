class Customer {
  final int id;
  final String name;
  final String phone;
  final int debt;
  final int? areaId;
  final String areaName;

  Customer({required this.id, required this.name, required this.phone, required this.debt, this.areaId, this.areaName = ''});

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'],
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        debt: (j['debt'] ?? 0) as int,
        areaId: j['area_id'] as int?,
        areaName: j['area_name'] ?? '',
      );
}

class AreaSummary {
  final int id;
  final String name;
  final int customerCount;
  final int totalDebt;

  AreaSummary({required this.id, required this.name, required this.customerCount, required this.totalDebt});

  factory AreaSummary.fromJson(Map<String, dynamic> j) => AreaSummary(
        id: j['id'] as int,
        name: j['name'] ?? '',
        customerCount: (j['customer_count'] ?? 0) as int,
        totalDebt: (j['total_debt'] ?? 0) as int,
      );
}

class HistoryItem {
  final String type;
  final String date;
  final int sortTs;
  final String desc;
  final int amount;
  final Map<String, dynamic>? data;
  final int? logId;

  HistoryItem({
    required this.type,
    required this.date,
    required this.sortTs,
    required this.desc,
    required this.amount,
    this.data,
    this.logId,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        type: j['type'] ?? '',
        date: j['date'] ?? '',
        sortTs: j['sort_ts'] ?? 0,
        desc: j['desc'] ?? '',
        amount: (j['amount'] is int) ? j['amount'] : (j['amount'] as num).toInt(),
        data: j['data'] as Map<String, dynamic>?,
        logId: j['log_id'],
      );
}
