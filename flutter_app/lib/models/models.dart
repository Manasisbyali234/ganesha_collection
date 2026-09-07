class AuthUser {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role; // 'admin' or 'member'

  AuthUser({required this.id, required this.name, required this.email, this.phone, required this.role});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'],
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'],
        role: json['role'] ?? 'member',
      );
}

class MemberSummary {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String status;
  final double totalCollection;
  final double totalOutstanding;
  final int devoteeCount;
  final int donationCount;

  MemberSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.status,
    required this.totalCollection,
    required this.totalOutstanding,
    required this.devoteeCount,
    required this.donationCount,
  });

  factory MemberSummary.fromJson(Map<String, dynamic> json) => MemberSummary(
        id: json['id'],
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        status: json['status'] ?? 'active',
        totalCollection: double.tryParse(json['total_collection'].toString()) ?? 0,
        totalOutstanding: double.tryParse(json['total_outstanding'].toString()) ?? 0,
        devoteeCount: int.tryParse(json['devotee_count'].toString()) ?? 0,
        donationCount: int.tryParse(json['donation_count'].toString()) ?? 0,
      );
}

class Devotee {
  final int id;
  final String name;
  final String? address;
  final String? phone;
  final double initialPayment;
  final String paymentMethod;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final String status;
  final DateTime createdAt;

  Devotee({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.initialPayment,
    required this.paymentMethod,
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.status,
    required this.createdAt,
  });

  factory Devotee.fromJson(Map<String, dynamic> json) => Devotee(
        id: json['id'],
        name: json['name'] ?? '',
        address: json['address'],
        phone: json['phone'],
        initialPayment: double.tryParse(json['initial_payment'].toString()) ?? 0,
        paymentMethod: json['payment_method'] ?? 'cash',
        totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0,
        paidAmount: double.tryParse(json['paid_amount'].toString()) ?? 0,
        outstandingAmount: double.tryParse(json['outstanding_amount'].toString()) ?? 0,
        status: json['status'] ?? 'pending',
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}

class Donation {
  final int id;
  final String donorName;
  final String? donorPhone;
  final String section; // gold / silver / food / cash / other
  final String? description;
  final double amount;
  final String paymentMethod;
  final bool paid;
  final DateTime donationDate;

  Donation({
    required this.id,
    required this.donorName,
    this.donorPhone,
    required this.section,
    this.description,
    required this.amount,
    required this.paymentMethod,
    required this.paid,
    required this.donationDate,
  });

  factory Donation.fromJson(Map<String, dynamic> json) => Donation(
        id: json['id'],
        donorName: json['donor_name'] ?? '',
        donorPhone: json['donor_phone'],
        section: json['section'] ?? 'other',
        description: json['description'],
        amount: double.tryParse(json['amount'].toString()) ?? 0,
        paymentMethod: json['payment_method'] ?? 'cash',
        paid: json['paid'] == true || json['paid'] == 1,
        donationDate: DateTime.tryParse(json['donation_date'] ?? '') ?? DateTime.now(),
      );
}

class BannerAd {
  final int id;
  final String title;
  final String? imageUrl;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String? startTime;
  final String? endTime;
  final bool active;

  BannerAd({
    required this.id,
    required this.title,
    this.imageUrl,
    this.description,
    required this.startDate,
    required this.endDate,
    this.startTime,
    this.endTime,
    required this.active,
  });

  factory BannerAd.fromJson(Map<String, dynamic> json) => BannerAd(
        id: json['id'],
        title: json['title'] ?? '',
        imageUrl: json['image_url'],
        description: json['description'],
        startDate: DateTime.tryParse(json['start_date'] ?? '') ?? DateTime.now(),
        endDate: DateTime.tryParse(json['end_date'] ?? '') ?? DateTime.now(),
        startTime: json['start_time'],
        endTime: json['end_time'],
        active: json['active'] == true || json['active'] == 1,
      );
}

class Booking {
  final int id;
  final String devoteeName;
  final String? phone;
  final String typeName; // pooja_name or sankalp_type
  final DateTime bookingDate;
  final String? bookingTime;
  final double amount;
  final String paymentMethod;
  final String status;

  Booking({
    required this.id,
    required this.devoteeName,
    this.phone,
    required this.typeName,
    required this.bookingDate,
    this.bookingTime,
    required this.amount,
    required this.paymentMethod,
    required this.status,
  });

  factory Booking.fromJson(Map<String, dynamic> json, {required String typeKey}) => Booking(
        id: json['id'],
        devoteeName: json['devotee_name'] ?? '',
        phone: json['phone'],
        typeName: json[typeKey] ?? '',
        bookingDate: DateTime.tryParse(json['booking_date'] ?? '') ?? DateTime.now(),
        bookingTime: json['booking_time'],
        amount: double.tryParse(json['amount'].toString()) ?? 0,
        paymentMethod: json['payment_method'] ?? 'cash',
        status: json['status'] ?? 'booked',
      );
}

class MeetingItem {
  final String itemName;
  final String? itemType;
  final String? quantity;
  final String? notes;

  MeetingItem({required this.itemName, this.itemType, this.quantity, this.notes});

  Map<String, dynamic> toJson() => {
        'item_name': itemName,
        'item_type': itemType,
        'quantity': quantity,
        'notes': notes,
      };

  factory MeetingItem.fromJson(Map<String, dynamic> json) => MeetingItem(
        itemName: json['item_name'] ?? '',
        itemType: json['item_type'],
        quantity: json['quantity']?.toString(),
        notes: json['notes'],
      );
}

class Meeting {
  final int id;
  final String title;
  final DateTime meetingDate;
  final String? meetingTime;
  final String? notes;
  final List<MeetingItem> items;

  Meeting({
    required this.id,
    required this.title,
    required this.meetingDate,
    this.meetingTime,
    this.notes,
    required this.items,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
        id: json['id'],
        title: json['title'] ?? '',
        meetingDate: DateTime.tryParse(json['meeting_date'] ?? '') ?? DateTime.now(),
        meetingTime: json['meeting_time'],
        notes: json['notes'],
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => MeetingItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
