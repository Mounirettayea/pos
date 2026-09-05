class CashShift {
  final String id;
  final double openingCash;
  final double? expectedCash;
  final double? actualCash;
  final double? difference;
  final String status;
  final DateTime openedAt;
  final DateTime? closedAt;
  const CashShift({required this.id, required this.openingCash, this.expectedCash, this.actualCash, this.difference, required this.status, required this.openedAt, this.closedAt});
  factory CashShift.fromMap(Map<String,dynamic> m) => CashShift(id:'${m['id']}', openingCash:(m['opening_cash'] as num?)?.toDouble()??0, expectedCash:(m['expected_cash'] as num?)?.toDouble(), actualCash:(m['actual_cash'] as num?)?.toDouble(), difference:(m['difference'] as num?)?.toDouble(), status:'${m['status']??'open'}', openedAt:DateTime.parse('${m['opened_at']}'), closedAt:m['closed_at']==null?null:DateTime.tryParse('${m['closed_at']}'));
}

class Purchase {
  final String id;
  final String? supplierId;
  final double total;
  final double paidAmount;
  final String status;
  final DateTime date;
  const Purchase({required this.id,this.supplierId,required this.total,required this.paidAmount,required this.status,required this.date});
  factory Purchase.fromMap(Map<String,dynamic> m)=>Purchase(id:'${m['id']}',supplierId:m['supplier_id']?.toString(),total:(m['total'] as num?)?.toDouble()??0,paidAmount:(m['paid_amount'] as num?)?.toDouble()??0,status:'${m['status']??'received'}',date:DateTime.parse('${m['purchase_date']}'));
}

class SaleReturn {
  final String id;
  final String? saleId;
  final double refundAmount;
  final String paymentMethod;
  final DateTime createdAt;
  const SaleReturn({required this.id,this.saleId,required this.refundAmount,required this.paymentMethod,required this.createdAt});
  factory SaleReturn.fromMap(Map<String,dynamic> m)=>SaleReturn(id:'${m['id']}',saleId:m['sale_id']?.toString(),refundAmount:(m['refund_amount'] as num?)?.toDouble()??0,paymentMethod:'${m['payment_method']??'cash'}',createdAt:DateTime.parse('${m['created_at']}'));
}
