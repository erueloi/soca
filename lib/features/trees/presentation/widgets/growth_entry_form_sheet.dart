import 'package:flutter/material.dart';

class GrowthEntryFormSheet extends StatefulWidget {
  const GrowthEntryFormSheet({super.key});

  @override
  State<GrowthEntryFormSheet> createState() => _GrowthEntryFormSheetState();
}

class _GrowthEntryFormSheetState extends State<GrowthEntryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _diameterController = TextEditingController();
  final _observationsController = TextEditingController();
  String _selectedStatus = 'Viable';

  final List<String> _statusOptions = ['Viable', 'Malalt', 'Danyat', 'Mort'];

  @override
  void dispose() {
    _heightController.dispose();
    _diameterController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  void _submit() {
    debugPrint('Modal: Submit clicked');
    if (_formKey.currentState!.validate()) {
      debugPrint('Modal: Form Validated');
      final heightStr = _heightController.text.replaceAll(',', '.');
      final diameterStr = _diameterController.text.replaceAll(',', '.');

      final height = double.tryParse(heightStr) ?? 0.0;
      final diameter = double.tryParse(diameterStr) ?? 0.0;

      debugPrint('Modal: Parsed values - H: $height, D: $diameter');

      debugPrint('Modal: Popping with result...');
      Navigator.pop(context, {
        'height': height,
        'diameter': diameter,
        'status': _selectedStatus,
        'observations': _observationsController.text,
      });
    } else {
      debugPrint('Modal: Form Validation Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Detalls del Seguiment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Alçada (cm)',
                        border: OutlineInputBorder(),
                        suffixText: 'cm',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Requerit';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _diameterController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Diàmetre Tronc',
                        border: OutlineInputBorder(),
                        suffixText:
                            'cm', // Or mm? User didn't specify, assuming cm usually for diameter if not huge. Or mm. User prompt: "diametre_tronc (num)". Let's stick to cm or mm. Let's start with cm.
                      ),
                      validator: (value) {
                        return null; // Optional?
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                items: _statusOptions.map((status) {
                  return DropdownMenuItem(value: status, child: Text(status));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatus = val);
                },
                decoration: const InputDecoration(
                  labelText: 'Estat de Salut',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observationsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observacions',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('GUARDAR'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
