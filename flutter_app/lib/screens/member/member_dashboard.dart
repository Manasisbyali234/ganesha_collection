import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'add_devotee_screen.dart';
import 'donation_screen.dart';
import 'banner_screen.dart';
import 'pooja_booking_screen.dart';
import 'sankalp_booking_screen.dart';
import 'meeting_screen.dart';

class MemberDashboard extends StatefulWidget {
  const MemberDashboard({super.key});

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  Map<String, dynamic>? _devoteeSummary;
  List<dynamic> _donationSummary = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final devoteeSummary = await api.get('/devotees/summary/me');
      final donationSummary = await api.get('/donations/summary/me');
      setState(() {
        _devoteeSummary = devoteeSummary as Map<String, dynamic>;
        _donationSummary = donationSummary as List;
      });
    } catch (_) {
      // keep silent, user can pull to refresh
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic v) {
    final n = double.tryParse(v?.toString() ?? '0') ?? 0;
    return '₹${n.toStringAsFixed(0)}';
  }

  double get _totalDonations => _donationSummary.fold(
      0.0, (sum, e) => sum + (double.tryParse(e['total_paid'].toString()) ?? 0));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final devoteeCollected = double.tryParse(_devoteeSummary?['total_collected']?.toString() ?? '0') ?? 0;
    final outstanding = double.tryParse(_devoteeSummary?['total_outstanding']?.toString() ?? '0') ?? 0;
    final totalCollection = devoteeCollected + _totalDonations;

    final menuItems = <_MenuItem>[
      _MenuItem('Add User', Icons.person_add, Colors.blue, () => _open(const AddDevoteeScreen())),
      _MenuItem('Donations', Icons.volunteer_activism, Colors.pink, () => _open(const DonationScreen())),
      _MenuItem('Banner / Ads', Icons.campaign, Colors.deepPurple, () => _open(const BannerScreen())),
      _MenuItem('Pooja Booking', Icons.local_fire_department, Colors.orange, () => _open(const PoojaBookingScreen())),
      _MenuItem('Ana Sankalp', Icons.handshake, Colors.brown, () => _open(const SankalpBookingScreen())),
      _MenuItem('Sawal (Meeting)', Icons.groups_2, Colors.teal, () => _open(const MeetingScreen())),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: () => auth.logout()),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Welcome, ${auth.user?.name ?? ''}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()))
                : Row(
                    children: [
                      Expanded(child: _summaryCard('Total Collection', _fmt(totalCollection), Colors.green)),
                      const SizedBox(width: 12),
                      Expanded(child: _summaryCard('Outstanding', _fmt(outstanding), Colors.orange)),
                    ],
                  ),
            const SizedBox(height: 24),
            Text('Manage', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: menuItems.map((m) => _buildMenuTile(m)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => _load());
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(_MenuItem item) {
    return Card(
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 36, color: item.color),
            const SizedBox(height: 8),
            Text(item.label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _MenuItem(this.label, this.icon, this.color, this.onTap);
}
