import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'payment_method_field.dart';

/// Generic booking form reused by Pooja Booking and Ana Sankalp Booking screens.
class BookingForm extends StatefulWidget {
  final String endpoint; // e.g. '/pooja-bookings'
  final String typeLabel; // e.g. 'Pooja Name'
  final String typeKey; // e.g. 'pooja_name' or 'sankalp_type'
  final VoidCallback onSaved;

  const BookingForm({
    super.key,
    required this.endpoint,
    required this.typeLabel,
    required this.typeKey,
    required this.onSaved,
  });

  @override
  State<BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<BookingForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  String _paymentMethod = 'cash';
  bool _loading = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a booking date')));
      return;
    }
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      await api.post(widget.endpoint, {
        'devotee_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        widget.typeKey: _typeCtrl.text.trim(),
        'booking_date': DateFormat('yyyy-MM-dd').format(_date!),
        'booking_time': _time != null ? '${_time!.hour}:${_time!.minute}:00' : null,
        'amount': double.tryParse(_amountCtrl.text) ?? 0,
        'payment_method': _paymentMethod,
      });
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _typeCtrl.clear();
      _amountCtrl.clear();
      setState(() {
        _date = null;
        _time = null;
      });
      widget.onSaved();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking saved')));
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
            decoration: const InputDecoration(labelText: 'Devotee Name', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _typeCtrl,
            decoration: InputDecoration(labelText: widget.typeLabel, border: const OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_date == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(_date!)),
                  onPressed: _pickDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: Text(_time == null ? 'Select Time' : _time!.format(context)),
                  onPressed: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          PaymentMethodField(value: _paymentMethod, onChanged: (v) => setState(() => _paymentMethod = v)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Save Booking'),
          ),
        ],
      ),
    );
  }
}
