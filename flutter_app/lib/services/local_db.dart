import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static String _hash(String pw) =>
      sha256.convert(utf8.encode(pw)).toString();

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'temple.db');
    return openDatabase(path, version: 2, onCreate: _create, onUpgrade: _upgrade);
  }

  static Future<void> _upgrade(Database db, int oldV, int newV) async {
    final rows = await db.query('users', where: 'role = ?', whereArgs: ['admin']);
    if (rows.isEmpty) {
      await db.insert('users', {
        'name': 'Admin',
        'email': 'admin@temple.com',
        'phone': '',
        'password_hash': _hash('admin123'),
        'role': 'admin',
        'status': 'active',
      });
    }
  }

  static Future<void> _create(Database db, int v) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone TEXT,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'member',
        status TEXT NOT NULL DEFAULT 'active'
      )
    ''');
    await db.execute('''
      CREATE TABLE devotees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        initial_payment REAL DEFAULT 0,
        payment_method TEXT DEFAULT 'cash',
        total_amount REAL DEFAULT 0,
        paid_amount REAL DEFAULT 0,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE donations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        donor_name TEXT NOT NULL,
        donor_phone TEXT,
        section TEXT NOT NULL,
        description TEXT,
        amount REAL DEFAULT 0,
        payment_method TEXT DEFAULT 'cash',
        paid INTEGER DEFAULT 1,
        donation_date TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE banners (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        image_url TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        start_time TEXT,
        end_time TEXT,
        active INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE pooja_bookings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        devotee_name TEXT NOT NULL,
        phone TEXT,
        pooja_name TEXT NOT NULL,
        booking_date TEXT NOT NULL,
        booking_time TEXT,
        amount REAL DEFAULT 0,
        payment_method TEXT DEFAULT 'cash',
        status TEXT DEFAULT 'booked'
      )
    ''');
    await db.execute('''
      CREATE TABLE sankalp_bookings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        devotee_name TEXT NOT NULL,
        phone TEXT,
        sankalp_type TEXT NOT NULL,
        booking_date TEXT NOT NULL,
        booking_time TEXT,
        amount REAL DEFAULT 0,
        payment_method TEXT DEFAULT 'cash',
        status TEXT DEFAULT 'booked'
      )
    ''');
    await db.execute('''
      CREATE TABLE meetings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        meeting_date TEXT NOT NULL,
        meeting_time TEXT,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE meeting_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meeting_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        item_type TEXT,
        quantity TEXT,
        notes TEXT
      )
    ''');
    // Seed default admin
    await db.insert('users', {
      'name': 'Admin',
      'email': 'admin@temple.com',
      'phone': '',
      'password_hash': _hash('admin123'),
      'role': 'admin',
      'status': 'active',
    });
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> login(String email, String password, String role) async {
    final d = await db;
    final rows = await d.query('users',
        where: 'email = ? AND role = ? AND status = ? AND password_hash = ?',
        whereArgs: [email.trim().toLowerCase(), role, 'active', _hash(password)]);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<Map<String, dynamic>> createMember(Map<String, dynamic> data) async {
    final d = await db;
    final id = await d.insert('users', {
      'name': data['name'],
      'email': (data['email'] as String).toLowerCase(),
      'phone': data['phone'] ?? '',
      'password_hash': _hash(data['password']),
      'role': 'member',
      'status': 'active',
    });
    return {'id': id, 'name': data['name'], 'email': data['email'], 'role': 'member'};
  }

  // ── Members (admin view) ──────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMembers() async {
    final d = await db;
    final members = await d.query('users', where: 'role = ?', whereArgs: ['member']);
    final result = <Map<String, dynamic>>[];
    for (final m in members) {
      final mid = m['id'] as int;
      final devs = await d.query('devotees', where: 'member_id = ?', whereArgs: [mid]);
      final dons = await d.query('donations', where: 'member_id = ?', whereArgs: [mid]);
      final totalCollection = devs.fold<double>(0, (s, r) => s + (r['paid_amount'] as num).toDouble()) +
          dons.where((r) => r['paid'] == 1).fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
      final totalOutstanding = devs.fold<double>(
          0, (s, r) => s + ((r['total_amount'] as num) - (r['paid_amount'] as num)).toDouble());
      result.add({
        ...m,
        'total_collection': totalCollection,
        'total_outstanding': totalOutstanding,
        'devotee_count': devs.length,
        'donation_count': dons.length,
      });
    }
    return result;
  }

  static Future<Map<String, dynamic>> getAdminDashboard() async {
    final d = await db;
    final members = await d.query('users', where: 'role = ?', whereArgs: ['member']);
    final devs = await d.query('devotees');
    final dons = await d.query('donations');
    final pooja = await d.query('pooja_bookings');
    final sankalp = await d.query('sankalp_bookings');
    return {
      'total_members': members.length,
      'total_devotees': devs.length,
      'total_donations': dons.length,
      'total_pooja_bookings': pooja.length,
      'total_sankalp_bookings': sankalp.length,
      'total_collection': devs.fold<double>(0, (s, r) => s + (r['paid_amount'] as num).toDouble()) +
          dons.where((r) => r['paid'] == 1).fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble()),
      'total_outstanding': devs.fold<double>(
          0, (s, r) => s + ((r['total_amount'] as num) - (r['paid_amount'] as num)).toDouble()),
    };
  }

  static Future<Map<String, dynamic>> getMemberSummary(int memberId) async {
    final d = await db;
    final memberRows = await d.query('users', where: 'id = ?', whereArgs: [memberId]);
    if (memberRows.isEmpty) throw Exception('Member not found');
    final member = memberRows.first;
    final devs = await d.query('devotees', where: 'member_id = ?', whereArgs: [memberId]);
    final dons = await d.query('donations', where: 'member_id = ?', whereArgs: [memberId]);
    final pooja = await d.query('pooja_bookings', where: 'member_id = ?', whereArgs: [memberId]);
    final sankalp = await d.query('sankalp_bookings', where: 'member_id = ?', whereArgs: [memberId]);
    final totalCollection = devs.fold<double>(0, (s, r) => s + (r['paid_amount'] as num).toDouble()) +
        dons.where((r) => r['paid'] == 1).fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
    final totalOutstanding = devs.fold<double>(
        0, (s, r) => s + ((r['total_amount'] as num) - (r['paid_amount'] as num)).toDouble());
    return {
      'member': member,
      'totals': {
        'total_collection': totalCollection,
        'total_outstanding': totalOutstanding,
        'devotee_count': devs.length,
      },
      'devotees': devs,
      'donations': dons,
      'pooja_bookings': pooja,
      'sankalp_bookings': sankalp,
    };
  }

  static Future<void> updateMemberStatus(int memberId, String status) async {
    final d = await db;
    await d.update('users', {'status': status}, where: 'id = ?', whereArgs: [memberId]);
  }

  // ── Devotees ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getDevotees(int memberId) async {
    final d = await db;
    return d.query('devotees', where: 'member_id = ?', whereArgs: [memberId], orderBy: 'id DESC');
  }

  static Future<Map<String, dynamic>> addDevotee(int memberId, Map<String, dynamic> data) async {
    final d = await db;
    final total = (data['total_amount'] as num?)?.toDouble() ??
        (data['initial_payment'] as num?)?.toDouble() ?? 0.0;
    final paid = (data['initial_payment'] as num?)?.toDouble() ?? 0.0;
    final status = paid >= total ? 'paid' : paid > 0 ? 'partially_paid' : 'pending';
    final id = await d.insert('devotees', {
      'member_id': memberId,
      'name': data['name'],
      'address': data['address'] ?? '',
      'phone': data['phone'] ?? '',
      'initial_payment': paid,
      'payment_method': data['payment_method'] ?? 'cash',
      'total_amount': total,
      'paid_amount': paid,
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
    });
    final rows = await d.query('devotees', where: 'id = ?', whereArgs: [id]);
    return rows.first;
  }

  static Future<Map<String, dynamic>> payDevotee(int devoteeId, double amount, String method) async {
    final d = await db;
    final rows = await d.query('devotees', where: 'id = ?', whereArgs: [devoteeId]);
    if (rows.isEmpty) throw Exception('Not found');
    final dev = rows.first;
    final newPaid = (dev['paid_amount'] as num).toDouble() + amount;
    final total = (dev['total_amount'] as num).toDouble();
    final status = newPaid >= total ? 'paid' : 'partially_paid';
    await d.update('devotees', {'paid_amount': newPaid, 'status': status},
        where: 'id = ?', whereArgs: [devoteeId]);
    final updated = await d.query('devotees', where: 'id = ?', whereArgs: [devoteeId]);
    return updated.first;
  }

  static Future<Map<String, dynamic>> getDevoteeSummary(int memberId) async {
    final d = await db;
    final devs = await d.query('devotees', where: 'member_id = ?', whereArgs: [memberId]);
    return {
      'total_collected': devs.fold<double>(0, (s, r) => s + (r['paid_amount'] as num).toDouble()),
      'total_outstanding': devs.fold<double>(
          0, (s, r) => s + ((r['total_amount'] as num) - (r['paid_amount'] as num)).toDouble()),
      'count': devs.length,
    };
  }

  // ── Donations ─────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getDonations(int memberId) async {
    final d = await db;
    return d.query('donations', where: 'member_id = ?', whereArgs: [memberId], orderBy: 'id DESC');
  }

  static Future<Map<String, dynamic>> addDonation(int memberId, Map<String, dynamic> data) async {
    final d = await db;
    final id = await d.insert('donations', {
      'member_id': memberId,
      'donor_name': data['donor_name'],
      'donor_phone': data['donor_phone'] ?? '',
      'section': data['section'],
      'description': data['description'] ?? '',
      'amount': data['amount'] ?? 0,
      'payment_method': data['payment_method'] ?? 'cash',
      'paid': (data['paid'] == true) ? 1 : 0,
      'donation_date': DateTime.now().toIso8601String(),
    });
    final rows = await d.query('donations', where: 'id = ?', whereArgs: [id]);
    return rows.first;
  }

  static Future<List<Map<String, dynamic>>> getDonationSummary(int memberId) async {
    final d = await db;
    final dons = await d.query('donations',
        where: 'member_id = ? AND paid = 1', whereArgs: [memberId]);
    final Map<String, double> bySection = {};
    for (final r in dons) {
      final s = r['section'] as String;
      bySection[s] = (bySection[s] ?? 0) + (r['amount'] as num).toDouble();
    }
    return bySection.entries.map((e) => {'section': e.key, 'total_paid': e.value}).toList();
  }

  // ── Banners ───────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getBanners(int memberId) async {
    final d = await db;
    return d.query('banners', where: 'member_id = ?', whereArgs: [memberId], orderBy: 'id DESC');
  }

  static Future<Map<String, dynamic>> addBanner(int memberId, Map<String, dynamic> data) async {
    final d = await db;
    final id = await d.insert('banners', {
      'member_id': memberId,
      'title': data['title'],
      'description': data['description'] ?? '',
      'image_url': data['image_url'] ?? '',
      'start_date': data['start_date'],
      'end_date': data['end_date'],
      'start_time': data['start_time'],
      'end_time': data['end_time'],
      'active': 1,
    });
    final rows = await d.query('banners', where: 'id = ?', whereArgs: [id]);
    return rows.first;
  }

  // ── Pooja Bookings ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getPoojaBookings(int memberId) async {
    final d = await db;
    return d.query('pooja_bookings', where: 'member_id = ?', whereArgs: [memberId], orderBy: 'id DESC');
  }

  static Future<Map<String, dynamic>> addPoojaBooking(int memberId, Map<String, dynamic> data) async {
    final d = await db;
    final id = await d.insert('pooja_bookings', {
      'member_id': memberId,
      'devotee_name': data['devotee_name'],
      'phone': data['phone'] ?? '',
      'pooja_name': data['pooja_name'],
      'booking_date': data['booking_date'],
      'booking_time': data['booking_time'],
      'amount': data['amount'] ?? 0,
      'payment_method': data['payment_method'] ?? 'cash',
      'status': 'booked',
    });
    final rows = await d.query('pooja_bookings', where: 'id = ?', whereArgs: [id]);
    return rows.first;
  }

  // ── Sankalp Bookings ──────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSankalpBookings(int memberId) async {
    final d = await db;
    return d.query('sankalp_bookings', where: 'member_id = ?', whereArgs: [memberId], orderBy: 'id DESC');
  }

  static Future<Map<String, dynamic>> addSankalpBooking(int memberId, Map<String, dynamic> data) async {
    final d = await db;
    final id = await d.insert('sankalp_bookings', {
      'member_id': memberId,
      'devotee_name': data['devotee_name'],
      'phone': data['phone'] ?? '',
      'sankalp_type': data['sankalp_type'],
      'booking_date': data['booking_date'],
      'booking_time': data['booking_time'],
      'amount': data['amount'] ?? 0,
      'payment_method': data['payment_method'] ?? 'cash',
      'status': 'booked',
    });
    final rows = await d.query('sankalp_bookings', where: 'id = ?', whereArgs: [id]);
    return rows.first;
  }

  // ── Meetings ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMeetings(int memberId) async {
    final d = await db;
    final meetings = await d.query('meetings',
        where: 'member_id = ?', whereArgs: [memberId], orderBy: 'id DESC');
    final result = <Map<String, dynamic>>[];
    for (final m in meetings) {
      final items = await d.query('meeting_items',
          where: 'meeting_id = ?', whereArgs: [m['id']]);
      result.add({...m, 'items': items});
    }
    return result;
  }

  static Future<Map<String, dynamic>> addMeeting(int memberId, Map<String, dynamic> data) async {
    final d = await db;
    final id = await d.insert('meetings', {
      'member_id': memberId,
      'title': data['title'],
      'meeting_date': data['meeting_date'],
      'meeting_time': data['meeting_time'],
      'notes': data['notes'] ?? '',
    });
    final items = data['items'] as List<dynamic>? ?? [];
    for (final item in items) {
      await d.insert('meeting_items', {
        'meeting_id': id,
        'item_name': item['item_name'],
        'item_type': item['item_type'] ?? '',
        'quantity': item['quantity'] ?? '',
        'notes': item['notes'] ?? '',
      });
    }
    final rows = await d.query('meetings', where: 'id = ?', whereArgs: [id]);
    final itemRows = await d.query('meeting_items', where: 'meeting_id = ?', whereArgs: [id]);
    return {...rows.first, 'items': itemRows};
  }
}
