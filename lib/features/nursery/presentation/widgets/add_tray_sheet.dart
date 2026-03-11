import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/nursery_models.dart';
import '../../presentation/providers/nursery_provider.dart';

/// Bottom sheet for creating a new [SeedTray].
class AddTraySheet extends ConsumerStatefulWidget {
  const AddTraySheet({super.key});

  @override
  ConsumerState<AddTraySheet> createState() => _AddTraySheetState();
}

class _AddTraySheetState extends ConsumerState<AddTraySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late DateTime _plantedAt;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _plantedAt = DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ca', 'ES'),
    );
    if (picked != null) {
      setState(() => _plantedAt = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final tray = SeedTray(
        id: '', // Firestore will auto-generate
        fincaId: '', // Repository will inject fincaId
        name: _nameController.text.trim(),
        status: TrayStatus.germination,
        plantedAt: _plantedAt,
      );

      await ref.read(nurseryActionsProvider.notifier).addTray(tray);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creant safata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy', 'ca_ES');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Handle ---
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Title ---
            Text(
              '🌱 Nova Safata',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // --- Name field ---
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nom de la safata',
                hintText: 'Ex: Tomàquets Cherry F1',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.label_outline),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nom és obligatori';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // --- Date picker ---
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Data de sembra',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  dateFormat.format(_plantedAt),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Submit button ---
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_isLoading ? 'Creant...' : 'Crear Safata'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
