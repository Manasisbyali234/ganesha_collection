import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/payment_method_field.dart';

class AddDevoteeScreen extends StatefulWidget {
  const AddDevoteeScreen({super.key});

  @override
  State<AddDevoteeScreen> createState() => _AddDevoteeScreenState();
}

class _AddDevoteeScreenState extends State<AddDevoteeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Devotee> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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
      final res = await api.get('/devotees');
      setState(() => _all = (res as List).map((e) => Devotee.fromJson(e)).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(num v) => '₹${v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final paid = _all.where((d) => d.status == 'paid').toList();
    final pending = _all.where((d) => d.status != 'paid').toList();
    final totalCollection = _all.fold<double>(0, (s, d) => s + d.paidAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add User'),
        bottom: TabBar(controller: _tab, tabs: [
          const Tab(text: 'Add New'),
          Tab(text: 'Paid List (${paid.length})'),
          Tab(text: 'Pending List (${pending.length})'),
        ]),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _AddDevoteeForm(onSaved: _load),
          _DevoteeListView(list: paid, loading: _loading, totalLabel: 'Total Collected: ${_fmt(totalCollection)}'),
          _DevoteeListView(
            list: pending,
            loading: _loading,
            totalLabel:
                'Total Outstanding: ${_fmt(pending.fold<double>(0, (s, d) => s + d.outstandingAmount))}',
            onPay: _load,
          ),
        ],
      ),
    );
  }
}

class _AddDevoteeForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddDevoteeForm({required this.onSaved});

  @override
  State<_AddDevoteeForm> createState() => _AddDevoteeFormState();
}

class _AddDevoteeFormState extends State<_AddDevoteeForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _initialPaymentCtrl = TextEditingController();
  final _totalAmountCtrl = TextEditingController();
  String _paymentMethod = 'cash';
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      await api.post('/devotees', {
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'initial_payment': double.tryParse(_initialPaymentCtrl.text) ?? 0,
        'payment_method': _paymentMethod,
        'total_amount': double.tryParse(_totalAmountCtrl.text) ??
            double.tryParse(_initialPaymentCtrl.text) ??
            0,
      });
      _nameCtrl.clear();
      _addressCtrl.clear();
      _phoneCtrl.clear();
      _initialPaymentCtrl.clear();
      _totalAmountCtrl.clear();
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User added successfully')));
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
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _initialPaymentCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Initial Payment (₹)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _totalAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Total Pledged Amount (₹) — optional, defaults to initial payment',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          PaymentMethodField(value: _paymentMethod, onChanged: (v) => setState(() => _paymentMethod = v)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Save User'),
          ),
        ],
      ),
    );
  }
}

class _DevoteeListView extends StatelessWidget {
  final List<Devotee> list;
  final bool loading;
  final String totalLabel;
  final VoidCallback? onPay;

  const _DevoteeListView({required this.list, required this.loading, required this.totalLabel, this.onPay});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(totalLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No records.'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final d = list[i];
                    return ListTile(
                      title: Text(d.name),
                      subtitle: Text(
                          '${d.phone ?? ''}\nPaid ₹${d.paidAmount.toStringAsFixed(0)} of ₹${d.totalAmount.toStringAsFixed(0)}  •  via ${d.paymentMethod}'),
                      isThreeLine: true,
                      trailing: d.status != 'paid' && onPay != null
                          ? TextButton(
                              child: const Text('Collect'),
                              onPressed: () => _showCollectDialog(context, d),
                            )
                          : Chip(label: Text(d.status)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCollectDialog(BuildContext context, Devotee d) {
    final amountCtrl = TextEditingController();
    String method = 'cash';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Collect payment — ${d.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Outstanding: ₹${d.outstandingAmount.toStringAsFixed(0)}'),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount received', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              PaymentMethodField(value: method, onChanged: (v) => setSt(() => method = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                if (amt <= 0) return;
                final api = context.read<AuthProvider>().api;
                try {
                  await api.patch('/devotees/${d.id}/pay', {'amount': amt, 'payment_method': method});
                  if (ctx.mounted) Navigator.pop(ctx);
                  onPay?.call();
                } catch (_) {
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
