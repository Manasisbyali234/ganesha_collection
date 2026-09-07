import 'package:flutter/material.dart';

const List<Map<String, String>> kPaymentMethods = [
  {'value': 'cash', 'label': 'Cash'},
  {'value': 'phone', 'label': 'Phone (UPI/GPay/PhonePe)'},
  {'value': 'card', 'label': 'Card'},
  {'value': 'bank', 'label': 'Bank Transfer'},
  {'value': 'other', 'label': 'Other'},
];

class PaymentMethodField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  const PaymentMethodField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Paid By',
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: kPaymentMethods
          .map((m) => DropdownMenuItem(value: m['value'], child: Text(m['label']!)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
