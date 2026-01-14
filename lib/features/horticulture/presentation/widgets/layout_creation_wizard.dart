import 'package:flutter/material.dart';
import '../../domain/entities/garden_layout_config.dart';

class LayoutCreationWizard extends StatefulWidget {
  final Function(GardenLayoutConfig) onConfigCompleted;

  const LayoutCreationWizard({super.key, required this.onConfigCompleted});

  @override
  State<LayoutCreationWizard> createState() => _LayoutCreationWizardState();
}

class _LayoutCreationWizardState extends State<LayoutCreationWizard> {
  final _formKey = GlobalKey<FormState>();

  final _widthCtrl = TextEditingController(text: '7');
  final _lengthCtrl = TextEditingController(text: '5');
  final _numBedsCtrl = TextEditingController(text: '4');
  // _bedWidthCtrl removed, it's calculated
  final _pathWidthCtrl = TextEditingController(text: '0.5');
  final _cellSizeCtrl = TextEditingController(text: '0.2');

  String _calcResult = '';
  Color _calcColor = Colors.grey;

  void _calculateBedWidth() {
    final w = double.tryParse(_widthCtrl.text) ?? 0;
    final n = int.tryParse(_numBedsCtrl.text) ?? 0;
    final p = double.tryParse(_pathWidthCtrl.text) ?? 0;

    if (w <= 0 || n <= 0 || p <= 0) {
      setState(() {
        _calcResult = 'Introdueix valors vàlids';
        _calcColor = Colors.grey;
      });
      return;
    }

    // Logic: Ep = (N+1) * P
    final totalPathSpace = (n + 1) * p;
    final totalBedSpace = w - totalPathSpace;

    if (totalBedSpace <= 0) {
      setState(() {
        _calcResult = '⚠️ L\'espai és massa estret (Passadissos > Total)!';
        _calcColor = Colors.red;
      });
    } else {
      final bedWidth = totalBedSpace / n;
      setState(() {
        _calcResult =
            '✅ Amplada de cada bancal: ${bedWidth.toStringAsFixed(2)} m';
        _calcColor = Colors.green[700]!;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _widthCtrl.addListener(_calculateBedWidth);
    _numBedsCtrl.addListener(_calculateBedWidth);
    _pathWidthCtrl.addListener(_calculateBedWidth);
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateBedWidth());
  }

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '📐 Configuració Universal de l\'Espai',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue[50],
              child: const Text(
                'Aquest assistent calcularà automàticament l\'amplada dels bancals basant-se en l\'espai disponible. \nFórmula: N+1 Passadissos.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Dimensions Totals (metres)'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _widthCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amplada Total (m)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Invàlid',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lengthCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Llargada Total (m)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Invàlid',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Paràmetres de Distribució'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _numBedsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de Bancals',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Invàlid',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _pathWidthCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amplada Passadís (m)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Invàlid',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cellSizeCtrl,
              decoration: const InputDecoration(
                labelText: 'Mida de la cel·la (m)',
                helperText: 'Per defecte 0.2 (20cm)',
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Invàlid',
            ),
            const SizedBox(height: 24),
            // Result preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _calcColor.withValues(alpha: 0.1),
                border: Border.all(color: _calcColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _calcResult,
                style: TextStyle(
                  color: _calcColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _isLoading = true);

                        // UX Delay to show the loader
                        await Future.delayed(const Duration(seconds: 1));

                        if (!mounted) return;

                        final w = double.parse(_widthCtrl.text);
                        final l = double.parse(_lengthCtrl.text);
                        final n = int.parse(_numBedsCtrl.text);
                        final p = double.parse(_pathWidthCtrl.text);

                        final totalPathSpace = (n + 1) * p;
                        final totalBedSpace = w - totalPathSpace;

                        if (totalBedSpace <= 0) {
                          if (!mounted) return;
                          setState(() => _isLoading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '⚠️ Error: L\'espai és massa estret!',
                                ),
                              ),
                            );
                          }
                          return;
                        }

                        final bedWidth = totalBedSpace / n;
                        final cellSize = double.parse(_cellSizeCtrl.text);

                        final config = GardenLayoutConfig(
                          totalWidth: w,
                          totalLength: l,
                          numberOfBeds: n,
                          bedWidth: bedWidth,
                          pathWidth: p,
                          cellSize: cellSize,
                        );

                        widget.onConfigCompleted(config);
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_view),
                        SizedBox(width: 8),
                        Text('Generar Graella'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
