import 'dart:convert';

String money(int paise) =>
    '₹${(paise / 100).toStringAsFixed(paise % 100 == 0 ? 0 : 2)}';
String shortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String clockTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

enum PaymentState { unpaid, paid, refunded }

enum OrderStage { preparing, ready, completed, cancelled }

class BusinessProfile {
  final String phone, address, gstin, invoicePrefix, greeting, reviewUrl, logo;
  final int taxBasisPoints;
  const BusinessProfile({
    this.phone = '',
    this.address = '',
    this.gstin = '',
    this.invoicePrefix = 'HY',
    this.greeting = 'Thank you for visiting us!',
    this.reviewUrl = '',
    this.logo = '',
    this.taxBasisPoints = 0,
  });
  Map<String, dynamic> toJson() => {
    'phone': phone,
    'address': address,
    'gstin': gstin,
    'invoicePrefix': invoicePrefix,
    'greeting': greeting,
    'reviewUrl': reviewUrl,
    'logo': logo,
    'taxBasisPoints': taxBasisPoints,
  };
  BusinessProfile copyWith({
    String? phone,
    String? address,
    String? gstin,
    String? invoicePrefix,
    String? greeting,
    String? reviewUrl,
    String? logo,
    int? taxBasisPoints,
  }) =>
      BusinessProfile(
        phone: phone ?? this.phone,
        address: address ?? this.address,
        gstin: gstin ?? this.gstin,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        greeting: greeting ?? this.greeting,
        reviewUrl: reviewUrl ?? this.reviewUrl,
        logo: logo ?? this.logo,
        taxBasisPoints: taxBasisPoints ?? this.taxBasisPoints,
      );
  factory BusinessProfile.fromJson(Map<String, dynamic> j) => BusinessProfile(
    phone: j['phone'] ?? '',
    address: j['address'] ?? '',
    gstin: j['gstin'] ?? '',
    invoicePrefix: j['invoicePrefix'] ?? 'HY',
    greeting: j['greeting'] ?? 'Thank you for visiting us!',
    reviewUrl: j['reviewUrl'] ?? '',
    logo: j['logo'] ?? '',
    taxBasisPoints: j['taxBasisPoints'] ?? 0,
  );
}

class MenuItem {
  final String id;
  final String name;
  final String category;
  final int price;
  final bool available;
  final String image;
  final bool availableStock;

  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.available = true,
    this.image = '',
    this.availableStock = false,
  });

  MenuItem copyWith({
    String? id,
    String? name,
    String? category,
    int? price,
    bool? available,
    String? image,
    bool? availableStock,
  }) =>
      MenuItem(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        price: price ?? this.price,
        available: available ?? this.available,
        image: image ?? this.image,
        availableStock: availableStock ?? this.availableStock,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'price': price,
    'available': available,
    'image': image,
    'availableStock': availableStock,
  };

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
    id: j['id'],
    name: j['name'],
    category: j['category'],
    price: j['price'],
    available: j['available'] ?? true,
    image: j['image'] ?? '',
    availableStock: j['availableStock'] ?? false,
  );
}

class OrderLine {
  final String itemId;
  final String name;
  final int unitPrice;
  final int quantity;
  const OrderLine({
    required this.itemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });
  int get total => unitPrice * quantity;
  OrderLine withQuantity(int value) => OrderLine(
    itemId: itemId,
    name: name,
    unitPrice: unitPrice,
    quantity: value,
  );
  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'name': name,
    'unitPrice': unitPrice,
    'quantity': quantity,
  };
  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
    itemId: j['itemId'],
    name: j['name'],
    unitPrice: j['unitPrice'],
    quantity: j['quantity'],
  );
}

class CafeOrder {
  final String id;
  final DateTime createdAt;
  final List<OrderLine> lines;
  final String customer;
  final String phone;
  final String service;
  final String table;
  final PaymentState payment;
  final OrderStage stage;
  final String? paymentMethod;
  final DateTime? paidAt;
  final DateTime? refundedAt;
  final String? refundReason;
  final int taxBasisPoints;
  final int discount;
  final String businessName;
  final BusinessProfile profile;
  CafeOrder({
    required this.id,
    required this.createdAt,
    required List<OrderLine> lines,
    this.customer = '',
    this.phone = '',
    this.service = 'Takeaway',
    this.table = '',
    this.payment = PaymentState.unpaid,
    this.stage = OrderStage.preparing,
    this.paymentMethod,
    this.paidAt,
    this.refundedAt,
    this.refundReason,
    this.taxBasisPoints = 0,
    this.discount = 0,
    this.businessName = '',
    this.profile = const BusinessProfile(),
  }) : lines = List.unmodifiable(lines);
  int get subtotal => lines.fold(0, (sum, line) => sum + line.total);
  int get tax => ((subtotal - discount) * taxBasisPoints + 5000) ~/ 10000;
  int get total => subtotal - discount + tax;
  int get count => lines.fold(0, (sum, line) => sum + line.quantity);
  bool get editable =>
      payment == PaymentState.unpaid && stage != OrderStage.cancelled;
  CafeOrder copyWith({
    List<OrderLine>? lines,
    PaymentState? payment,
    OrderStage? stage,
    String? paymentMethod,
    DateTime? paidAt,
    DateTime? refundedAt,
    String? refundReason,
    int? discount,
    String? customer,
    String? phone,
  }) => CafeOrder(
    id: id,
    createdAt: createdAt,
    lines: lines ?? this.lines,
    customer: customer ?? this.customer,
    phone: phone ?? this.phone,
    service: service,
    table: table,
    payment: payment ?? this.payment,
    stage: stage ?? this.stage,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    paidAt: paidAt ?? this.paidAt,
    refundedAt: refundedAt ?? this.refundedAt,
    refundReason: refundReason ?? this.refundReason,
    taxBasisPoints: taxBasisPoints,
    discount: discount ?? this.discount,
    businessName: businessName,
    profile: profile,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'lines': lines.map((e) => e.toJson()).toList(),
    'customer': customer,
    'phone': phone,
    'service': service,
    'table': table,
    'payment': payment.name,
    'stage': stage.name,
    'paymentMethod': paymentMethod,
    'paidAt': paidAt?.toIso8601String(),
    'refundedAt': refundedAt?.toIso8601String(),
    'refundReason': refundReason,
    'taxBasisPoints': taxBasisPoints,
    'discount': discount,
    'businessName': businessName,
    'profile': profile.toJson(),
  };
  factory CafeOrder.fromJson(Map<String, dynamic> j) => CafeOrder(
    id: j['id'],
    createdAt: DateTime.parse(j['createdAt']),
    lines: (j['lines'] as List).map((e) => OrderLine.fromJson(e)).toList(),
    customer: j['customer'],
    phone: j['phone'],
    service: j['service'],
    table: j['table'],
    payment: PaymentState.values.byName(j['payment']),
    stage: OrderStage.values.byName(j['stage']),
    paymentMethod: j['paymentMethod'],
    paidAt: j['paidAt'] == null ? null : DateTime.parse(j['paidAt']),
    refundedAt: j['refundedAt'] == null
        ? null
        : DateTime.parse(j['refundedAt']),
    refundReason: j['refundReason'],
    taxBasisPoints: j['taxBasisPoints'] ?? 0,
    discount: j['discount'] ?? 0,
    businessName: j['businessName'] ?? '',
    profile: BusinessProfile.fromJson(j['profile'] ?? {}),
  );
}

/// Pure application state. Money is always stored as integer paise.
/// Account authorization is enforced by the server.
class CafeData {
  String businessName;
  BusinessProfile profile;
  final DateTime trialStartedAt;
  int nextOrderNumber;
  final List<MenuItem> menu;
  final List<CafeOrder> orders;
  CafeData({
    required this.businessName,
    required this.trialStartedAt,
    required this.menu,
    required this.orders,
    this.nextOrderNumber = 1001,
    this.profile = const BusinessProfile(),
  });
  DateTime get trialEndsAt => trialStartedAt.add(const Duration(days: 15));
  int trialDaysLeft(DateTime now) =>
      ((trialEndsAt.difference(now).inSeconds / 86400).ceil()).clamp(0, 15);
  CafeOrder order(String id) => orders.firstWhere((o) => o.id == id);
  void _replace(CafeOrder value) =>
      orders[orders.indexWhere((o) => o.id == value.id)] = value;

  CafeOrder createOrder({
    required List<OrderLine> lines,
    required DateTime now,
    String customer = '',
    String phone = '',
    String service = 'Takeaway',
    String table = '',
    String? paymentMethod,
    int discount = 0,
  }) {
    _validateLines(lines);
    final subtotal = lines.fold(0, (sum, line) => sum + line.total);
    if (discount < 0 || discount >= subtotal) {
      throw StateError('Discount must be less than the subtotal.');
    }
    if (profile.taxBasisPoints < 0 || profile.taxBasisPoints > 10000) {
      throw StateError('Tax rate must be between 0 and 100%.');
    }
    validateCustomer(customer, phone);
    if (!['Takeaway', 'Dine-in'].contains(service)) {
      throw StateError('Choose a valid order type.');
    }
    if (service == 'Dine-in' && table.trim().isEmpty) {
      throw StateError('Enter a table number.');
    }
    if (paymentMethod != null) {
      _validateMethod(paymentMethod);
    }
    final value = CafeOrder(
      id: '${profile.invoicePrefix}-${nextOrderNumber++}',
      createdAt: now,
      lines: lines,
      customer: customer.trim(),
      phone: phone,
      service: service,
      table: service == 'Dine-in' ? table.trim() : '',
      payment: paymentMethod == null ? PaymentState.unpaid : PaymentState.paid,
      paymentMethod: paymentMethod,
      paidAt: paymentMethod == null ? null : now,
      discount: discount,
      taxBasisPoints: profile.taxBasisPoints,
      businessName: businessName,
      profile: profile,
    );
    orders.insert(0, value);
    return value;
  }

  void updateLines(String id, List<OrderLine> lines, {int? discount}) {
    final old = order(id);
    if (!old.editable) {
      throw StateError('Only unpaid, active orders can be edited.');
    }
    _validateLines(lines);
    final amount = discount ?? old.discount;
    if (amount < 0 ||
        amount >= lines.fold(0, (sum, line) => sum + line.total)) {
      throw StateError('Discount must be less than the subtotal.');
    }
    _replace(old.copyWith(lines: lines, discount: amount));
  }

  void recordPayment(String id, String method, DateTime now) {
    final old = order(id);
    if (!old.editable) {
      throw StateError('This order cannot accept another payment.');
    }
    _validateMethod(method);
    validateCustomer(old.customer, old.phone);
    _replace(
      old.copyWith(
        payment: PaymentState.paid,
        paymentMethod: method,
        paidAt: now,
      ),
    );
  }

  static void validateCustomer(String customer, String phone) {
    if (customer.trim().isEmpty || customer.trim().length > 80) {
      throw StateError('Enter the customer name (up to 80 characters).');
    }
    if (!RegExp(r'^\d{10}$').hasMatch(phone.trim())) {
      throw StateError('Enter a 10-digit WhatsApp number.');
    }
  }

  void updateCustomer(String id, String customer, String phone) {
    final old = order(id);
    if (!old.editable) {
      throw StateError('Paid customer details cannot be changed.');
    }
    validateCustomer(customer, phone);
    _replace(old.copyWith(customer: customer.trim(), phone: phone.trim()));
  }

  void setStage(String id, OrderStage stage) {
    final old = order(id);
    if (old.stage == OrderStage.cancelled ||
        old.stage == OrderStage.completed) {
      throw StateError('This order is already closed.');
    }
    if (stage == OrderStage.cancelled) {
      if (old.payment != PaymentState.unpaid) {
        throw StateError('Use a refund for paid orders.');
      }
    } else {
      if (old.payment == PaymentState.refunded) {
        throw StateError('This order has been refunded.');
      }
      if (stage.index != old.stage.index + 1) {
        throw StateError('Advance the order one step at a time.');
      }
      if (stage == OrderStage.completed && old.payment != PaymentState.paid) {
        throw StateError('Record payment before completing the order.');
      }
    }
    _replace(old.copyWith(stage: stage));
  }

  void refund(String id, String reason, DateTime now) {
    final old = order(id);
    if (old.payment != PaymentState.paid) {
      throw StateError('Only a paid order can be refunded.');
    }
    if (reason.trim().isEmpty) {
      throw StateError('Enter a refund reason.');
    }
    _replace(
      old.copyWith(
        payment: PaymentState.refunded,
        refundedAt: now,
        refundReason: reason.trim(),
      ),
    );
  }

  int collectedOn(DateTime day) => orders
      .where((o) => o.paidAt != null && sameDay(o.paidAt!, day))
      .fold(0, (sum, o) => sum + o.total);
  int refundedOn(DateTime day) => orders
      .where((o) => o.refundedAt != null && sameDay(o.refundedAt!, day))
      .fold(0, (sum, o) => sum + o.total);
  int netOn(DateTime day) => collectedOn(day) - refundedOn(day);
  int get unpaidTotal =>
      orders.where((o) => o.editable).fold(0, (sum, o) => sum + o.total);
  void saveMenuItem(MenuItem item) {
    if (item.name.trim().isEmpty ||
        item.category.trim().isEmpty ||
        item.price <= 0 ||
        item.price > 10000000) {
      throw StateError(
        'Use a name, category, and price between ₹0.01 and ₹100,000.',
      );
    }
    final index = menu.indexWhere((e) => e.id == item.id);
    if (index == -1) {
      menu.add(item);
    } else {
      menu[index] = item;
    }
  }

  void _validateMethod(String method) {
    if (!['Cash', 'UPI', 'Card'].contains(method)) {
      throw StateError('Choose Cash, UPI, or Card.');
    }
  }

  void _validateLines(List<OrderLine> lines) {
    if (lines.isEmpty) {
      throw StateError('Add at least one item.');
    }
    if (lines.any(
      (e) => e.quantity < 1 || e.quantity > 99 || e.unitPrice <= 0,
    )) {
      throw StateError(
        'Each item needs a positive price and quantity from 1 to 99.',
      );
    }
    if (lines.map((e) => e.itemId).toSet().length != lines.length) {
      throw StateError('Combine duplicate items before saving.');
    }
  }

  String encode() => jsonEncode({
    'schemaVersion': 1,
    'businessName': businessName,
    'profile': profile.toJson(),
    'trialStartedAt': trialStartedAt.toIso8601String(),
    'nextOrderNumber': nextOrderNumber,
    'menu': menu.map((e) => e.toJson()).toList(),
    'orders': orders.map((e) => e.toJson()).toList(),
  });
  factory CafeData.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['schemaVersion'] != 1) {
      throw const FormatException('Unsupported data version.');
    }
    return CafeData(
      businessName: j['businessName'],
      profile: BusinessProfile.fromJson(j['profile'] ?? {}),
      trialStartedAt: DateTime.parse(j['trialStartedAt']),
      nextOrderNumber: j['nextOrderNumber'],
      menu: (j['menu'] as List).map((e) => MenuItem.fromJson(e)).toList(),
      orders: (j['orders'] as List).map((e) => CafeOrder.fromJson(e)).toList(),
    );
  }
  factory CafeData.seed(DateTime now) => CafeData(
    businessName: 'The Daily Brew',
    trialStartedAt: now,
    menu: [
      const MenuItem(
        id: 'm1',
        name: 'Filter coffee',
        category: 'Coffee',
        price: 6000,
      ),
      const MenuItem(
        id: 'm2',
        name: 'Cappuccino',
        category: 'Coffee',
        price: 12000,
      ),
      const MenuItem(
        id: 'm3',
        name: 'Iced latte',
        category: 'Coffee',
        price: 15000,
      ),
      const MenuItem(
        id: 'm4',
        name: 'Masala chai',
        category: 'Tea',
        price: 4000,
      ),
      const MenuItem(
        id: 'm5',
        name: 'Lemon iced tea',
        category: 'Tea',
        price: 9000,
      ),
      const MenuItem(
        id: 'm6',
        name: 'Grilled sandwich',
        category: 'Bites',
        price: 14000,
      ),
      const MenuItem(
        id: 'm7',
        name: 'Butter croissant',
        category: 'Bites',
        price: 11000,
      ),
      const MenuItem(
        id: 'm8',
        name: 'Chocolate brownie',
        category: 'Bites',
        price: 9500,
      ),
    ],
    orders: [],
  );
}
