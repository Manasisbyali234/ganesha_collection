import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/local_db.dart';

class AuthProvider extends ChangeNotifier {
  AuthUser? _user;
  bool _loading = true;

  AuthUser? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.role == 'admin';

  ApiService get api => ApiService(memberId: _user?.id, role: _user?.role);

  AuthProvider() {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final storedRole = prefs.getString('role');
    final storedId = prefs.getInt('id');
    final storedName = prefs.getString('name');
    final storedEmail = prefs.getString('email');
    final storedPhone = prefs.getString('phone');
    if (storedRole != null && storedId != null) {
      _user = AuthUser(
        id: storedId,
        name: storedName ?? '',
        email: storedEmail ?? '',
        phone: storedPhone,
        role: storedRole,
      );
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', _user?.role ?? '');
    await prefs.setInt('id', _user?.id ?? 0);
    await prefs.setString('name', _user?.name ?? '');
    await prefs.setString('email', _user?.email ?? '');
    await prefs.setString('phone', _user?.phone ?? '');
  }

  Future<void> loginAdmin(String email, String password) async {
    final row = await LocalDb.login(email, password, 'admin');
    if (row == null) throw ApiException('Invalid admin credentials');
    _user = AuthUser(
      id: row['id'] as int,
      name: row['name'] as String,
      email: row['email'] as String,
      phone: row['phone'] as String?,
      role: 'admin',
    );
    await _persistSession();
    notifyListeners();
  }

  Future<void> loginMember(String email, String password) async {
    final row = await LocalDb.login(email, password, 'member');
    if (row == null) throw ApiException('Invalid credentials or account inactive');
    _user = AuthUser(
      id: row['id'] as int,
      name: row['name'] as String,
      email: row['email'] as String,
      phone: row['phone'] as String?,
      role: 'member',
    );
    await _persistSession();
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
