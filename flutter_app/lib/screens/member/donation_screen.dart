import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/payment_method_field.dart';

const List<Map<String, String>> kDonationSections = [
  {'value': 'gold', 'label': 'Gold'},
  {'value': 'silver', 'label': 'Silver'},
  {'value': 'food', 'label': 'Food'},
  {'value': 'cash', 'label': 'Cash'},
  {'value': 'other', 'label': 'Other'},
];

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Donation> _donations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.get('/donations');
      setState(() => _donations = (res as List).map((e) => Donation.fromJson(e)).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donations'),
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: 'Add Donation'), Tab(text: 'Donation List')]),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _AddDonationForm(onSaved: _load),
          _DonationListView(donations: _donations, loading: _loading),
        ],
      ),
    );
  }
}

class _AddDonationForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddDonationForm({required this.onSaved});

  @override
  State<_AddDonationForm> createState() => _AddDonationFormState();
}

class _AddDonationFormState extends State<_AddDonationForm> {
  final _formKey = GlobalKey<FormState>();
  final _donorCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _section = 'gold';
  String _paymentMethod = 'cash';
  bool _paid = true;
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      await api.post('/donations', {
        'donor_name': _donorCtrl.text.trim(),
        'donor_phone': _phoneCtrl.text.trim(),
        'section': _section,
        'description': _descCtrl.text.trim(),
        'amount': double.tryParse(_amountCtrl.text) ?? 0,
        'payment_method': _paymentMethod,
        'paid': _paid,
      });
      _donorCtrl.clear();
      _phoneCtrl.clear();
      _descCtrl.clear();
      _amountCtrl.clear();
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donation recorded')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _donorCtrl,
            decoration: const InputDecoration(labelText: 'Donor Name', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Donor Phone', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _section,
            decoration: const InputDecoration(labelText: 'Donation Section', border: OutlineInputBorder()),
            items: kDonationSections
                .map((s) => DropdownMenuItem(value: s['value'], child: Text(s['label']!)))
                .toList(),
            onChanged: (v) => setState(() => _section = v!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (e.g. "1 gold ring - 5gm")',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount / Value (₹)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          PaymentMethodField(value: _paymentMethod, onChanged: (v) => setState(() => _paymentMethod = v)),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _paid,
            title: const Text('Payment received (Paid)'),
            subtitle: const Text('Turn off if this donation is pledged but not yet received'),
            onChanged: (v) => setState(() => _paid = v),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Save Donation'),
          ),
        ],
      ),
    );
  }
}

class _DonationListView extends StatelessWidget {
  final List<Donation> donations;
  final bool loading;
  const _DonationListView({required this.donations, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final total = donations.where((d) => d.paid).fold<double>(0, (s, d) => s + d.amount);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text('Total Donations Collected: ₹${total.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: donations.isEmpty
              ? const Center(child: Text('No donations yet.'))
              : ListView.builder(
                  itemCount: donations.length,
                  itemBuilder: (_, i) {
                    final d = donations[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(d.section[0].toUpperCase())),
                      title: Text('${d.donorName} — ${d.section[0].toUpperCase()}${d.section.substring(1)}'),
                      subtitle: Text('${d.description ?? ''}\n${d.donationDate.toString().split(' ').first} • ${d.paymentMethod}'),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('₹${d.amount.toStringAsFixed(0)}'),
                          if (!d.paid) const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
