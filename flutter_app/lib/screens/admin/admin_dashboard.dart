import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import 'create_member_screen.dart';
import 'member_detail_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _totals;
  List<MemberSummary> _members = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<AuthProvider>().api;
    try {
      final totals = await api.get('/members/dashboard/admin');
      final members = await api.get('/members');
      setState(() {
        _totals = totals as Map<String, dynamic>;
        _members = (members as List).map((e) => MemberSummary.fromJson(e)).toList();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to load dashboard. Pull down to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic v) {
    final n = double.tryParse(v?.toString() ?? '0') ?? 0;
    return '₹${n.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Create Member'),
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateMemberScreen()),
          );
          if (created == true) _load();
        },
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(_error!))])
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Welcome, ${auth.user?.name ?? ''}', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      if (_totals != null) _buildTotalsGrid(),
                      const SizedBox(height: 24),
                      Text('Members (${_members.length})', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ..._members.map(_buildMemberTile),
                      if (_members.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: Text('No members yet. Tap "Create Member" to add one.')),
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTotalsGrid() {
    final t = _totals!;
    final cards = [
      ('Total Collection', _fmt(t['total_collection']), Icons.savings, Colors.green),
      ('Total Outstanding', _fmt(t['total_outstanding']), Icons.pending_actions, Colors.orange),
      ('Members', t['total_members'].toString(), Icons.people, Colors.blue),
      ('Devotees', t['total_devotees'].toString(), Icons.groups, Colors.purple),
      ('Donations', t['total_donations'].toString(), Icons.volunteer_activism, Colors.pink),
      ('Bookings', '${int.parse(t['total_pooja_bookings'].toString()) + int.parse(t['total_sankalp_bookings'].toString())}',
          Icons.event_available, Colors.teal),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: cards
          .map((c) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(c.$3, color: c.$4),
                      const SizedBox(height: 6),
                      Text(c.$2, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(c.$1, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMemberTile(MemberSummary m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: m.status == 'active' ? Colors.green.shade100 : Colors.grey.shade300,
          child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?'),
        ),
        title: Text(m.name),
        subtitle: Text('${m.email}\nCollected: ${_fmt(m.totalCollection)}  •  Outstanding: ${_fmt(m.totalOutstanding)}'),
        isThreeLine: true,
        trailing: Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MemberDetailScreen(memberId: m.id, memberName: m.name)),
        ),
      ),
    );
  }
}
