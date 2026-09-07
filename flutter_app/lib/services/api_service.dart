import 'local_db.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Drop-in replacement for the HTTP ApiService.
/// Routes every call to the local SQLite database instead of a backend server.
class ApiService {
  final int? memberId;
  final String? role;

  ApiService({String? token, this.memberId, this.role});

  Future<dynamic> get(String path) async {
    // Admin dashboard
    if (path == '/members/dashboard/admin') {
      return LocalDb.getAdminDashboard();
    }
    // Member list
    if (path == '/members') {
      return LocalDb.getMembers();
    }
    // Member summary: /members/{id}/summary
    final memberSummaryMatch = RegExp(r'^/members/(\d+)/summary$').firstMatch(path);
    if (memberSummaryMatch != null) {
      return LocalDb.getMemberSummary(int.parse(memberSummaryMatch.group(1)!));
    }
    // Devotee summary for current member
    if (path == '/devotees/summary/me') {
      return LocalDb.getDevoteeSummary(memberId!);
    }
    // Donation summary for current member
    if (path == '/donations/summary/me') {
      return LocalDb.getDonationSummary(memberId!);
    }
    if (path == '/devotees') return LocalDb.getDevotees(memberId!);
    if (path == '/donations') return LocalDb.getDonations(memberId!);
    if (path == '/banners') return LocalDb.getBanners(memberId!);
    if (path == '/pooja-bookings') return LocalDb.getPoojaBookings(memberId!);
    if (path == '/sankalp-bookings') return LocalDb.getSankalpBookings(memberId!);
    if (path == '/meetings') return LocalDb.getMeetings(memberId!);
    throw ApiException('Unknown path: $path');
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    // Create member (admin action)
    if (path == '/auth/members') {
      return LocalDb.createMember(body);
    }
    if (path == '/devotees') return LocalDb.addDevotee(memberId!, body);
    if (path == '/donations') return LocalDb.addDonation(memberId!, body);
    if (path == '/banners') return LocalDb.addBanner(memberId!, body);
    if (path == '/pooja-bookings') return LocalDb.addPoojaBooking(memberId!, body);
    if (path == '/sankalp-bookings') return LocalDb.addSankalpBooking(memberId!, body);
    if (path == '/meetings') return LocalDb.addMeeting(memberId!, body);
    throw ApiException('Unknown path: $path');
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    // Pay devotee: /devotees/{id}/pay
    final payMatch = RegExp(r'^/devotees/(\d+)/pay$').firstMatch(path);
    if (payMatch != null) {
      return LocalDb.payDevotee(
        int.parse(payMatch.group(1)!),
        (body['amount'] as num).toDouble(),
        body['payment_method'] ?? 'cash',
      );
    }
    // Toggle member status: /members/{id}/status
    final statusMatch = RegExp(r'^/members/(\d+)/status$').firstMatch(path);
    if (statusMatch != null) {
      await LocalDb.updateMemberStatus(int.parse(statusMatch.group(1)!), body['status']);
      return {'ok': true};
    }
    throw ApiException('Unknown path: $path');
  }
}
