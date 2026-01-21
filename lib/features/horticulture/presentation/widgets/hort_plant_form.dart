import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/ai_service.dart';
import '../../domain/entities/planta_hort.dart';
import '../../data/repositories/hort_repository.dart';

class HortPlantForm extends ConsumerStatefulWidget {
  final PlantaHort? plant; // If null, creating new
  const HortPlantForm({super.key, this.plant});

  @override
  ConsumerState<HortPlantForm> createState() => _HortPlantFormState();
}

class _HortPlantFormState extends ConsumerState<HortPlantForm> {
  final _formKey = GlobalKey<FormState>();
  // Removed local _repository
  bool _isLoading = false;
  bool _isAiLoading = false;

  late TextEditingController _nomComuCtrl;
  late TextEditingController _nomCientificCtrl;
  late TextEditingController _familiaCtrl;
  late TextEditingController _distanciaCtrl;
  late TextEditingController _linesCtrl;
  late TextEditingController _aliatsCtrl;
  late TextEditingController _enemicsCtrl;

  // Enums
  HortPartComestible _partComestible = HortPartComestible.fulla;
  HortExigenciaNutrients _exigencia = HortExigenciaNutrients.mitjanamentExigent;
  Color _color = Colors.green;

  // New Enum State
  // New Enum State
  HortTipusSembra _tipusSembra = HortTipusSembra.trasplantament;
  // _grupRotacio removed (Calculated)
  HortViaMetabolica _viaMetabolica = HortViaMetabolica.c3;
  late TextEditingController _rendimentCtrl;
  late TextEditingController _cicleCtrl;

  // Lists (Aliats/Enemics) now handled via text controllers

  @override
  void initState() {
    super.initState();
    _nomComuCtrl = TextEditingController(text: widget.plant?.nomComu ?? '');
    _nomCientificCtrl = TextEditingController(
      text: widget.plant?.nomCientific ?? '',
    );
    _familiaCtrl = TextEditingController(
      text: widget.plant?.familiaBotanica ?? '',
    );
    _distanciaCtrl = TextEditingController(
      text: widget.plant?.distanciaPlantacio.toString() ?? '30',
    );
    _linesCtrl = TextEditingController(
      text: widget.plant?.distanciaLinies.toString() ?? '40',
    );
    _aliatsCtrl = TextEditingController(
      text: widget.plant?.aliats.join(', ') ?? '',
    );
    _enemicsCtrl = TextEditingController(
      text: widget.plant?.enemics.join(', ') ?? '',
    );

    if (widget.plant != null) {
      _partComestible = widget.plant!.partComestible;
      _exigencia = widget.plant!.exigenciaNutrients;
      _color = widget.plant!.color;
      _tipusSembra = widget.plant!.tipusSembra;
      // _grupRotacio calculated from partComestible
      _viaMetabolica = widget.plant!.viaMetabolica;
    }

    _rendimentCtrl = TextEditingController(
      text: widget.plant?.rendiment.toString() ?? '',
    );
    _cicleCtrl = TextEditingController(
      text: widget.plant?.diesEnCamp.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nomComuCtrl.dispose();
    _nomCientificCtrl.dispose();
    _familiaCtrl.dispose();
    _distanciaCtrl.dispose();
    _linesCtrl.dispose();
    _aliatsCtrl.dispose();
    _enemicsCtrl.dispose();
    _rendimentCtrl.dispose();
    _cicleCtrl.dispose();
    super.dispose();
  }

  // Helper Methods for Calculated Logic
  HortGrupRotacio _calculateRotationGroup(HortPartComestible part) {
    // 1. Priority: Exigency
    if (_exigencia == HortExigenciaNutrients.moltExigent) {
      return HortGrupRotacio.fruit; // Grup 1
    }
    if (_exigencia == HortExigenciaNutrients.millorant) {
      return HortGrupRotacio.millorant; // Grup 4
    }

    // 2. Secondary: Part (for Mitjanament/Poc)
    if (part == HortPartComestible.arrel) {
      return HortGrupRotacio.arrel; // Grup 3
    }

    // Default to Grup 2 (Leaf) for others (Leaf, Flower) if not High/Imp
    return HortGrupRotacio.fulla;
  }

  String _getRotationLabel(HortPartComestible part) {
    return _calculateRotationGroup(part).label;
  }

  Color _getRotationColor(HortPartComestible part) {
    return _calculateRotationGroup(part).color;
  }

  Future<void> _fetchAI() async {
    // Prioritize Scientific Name, fallback to Common Name
    final query = _nomCientificCtrl.text.isNotEmpty
        ? _nomCientificCtrl.text
        : _nomComuCtrl.text;

    if (query.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escriu un nom (Científic o Comú) per buscar'),
        ),
      );
      return;
    }

    setState(() => _isAiLoading = true);

    try {
      final data = await ref
          .read(aiServiceProvider)
          .getHorticulturalData(query);

      setState(() {
        if (data['nom_cientific'] != null) {
          _nomCientificCtrl.text = data['nom_cientific'];
        }
        if (data['nom_comu'] != null && _nomComuCtrl.text.isEmpty) {
          _nomComuCtrl.text = data['nom_comu'];
        }
        if (data['familia'] != null) {
          _familiaCtrl.text = data['familia'];
        }
        if (data['distancia_plantes'] != null) {
          _distanciaCtrl.text = data['distancia_plantes'].toString();
        }
        if (data['distancia_linies'] != null) {
          _linesCtrl.text = data['distancia_linies'].toString();
        }
        if (data['aliats'] != null && data['aliats'] is List) {
          _aliatsCtrl.text = (data['aliats'] as List).join(', ');
        }
        if (data['enemics'] != null && data['enemics'] is List) {
          _enemicsCtrl.text = (data['enemics'] as List).join(', ');
        }

        if (data['rendiment'] != null) {
          _rendimentCtrl.text = data['rendiment'].toString();
        }
        if (data['dies_cicle'] != null) {
          _cicleCtrl.text = data['dies_cicle'].toString();
        }

        // Parse Enums
        if (data['tipus_sembra'] != null) {
          final s = data['tipus_sembra'].toString().toLowerCase();
          if (s.contains('direct')) {
            _tipusSembra = HortTipusSembra.directa;
          } else {
            _tipusSembra = HortTipusSembra.trasplantament;
          }
        }

        if (data['via_metabolica'] != null) {
          final v = data['via_metabolica'].toString().toLowerCase();
          if (v == 'c4') {
            _viaMetabolica = HortViaMetabolica.c4;
          } else if (v == 'cam') {
            _viaMetabolica = HortViaMetabolica.cam;
          } else {
            _viaMetabolica = HortViaMetabolica.c3;
          }
        }

        // Parse Part Comestible
        if (data['part_comestible'] != null) {
          final p = data['part_comestible'].toString().toLowerCase();
          if (p.contains('fruit')) {
            _partComestible = HortPartComestible.fruit;
          }
          if (p.contains('fulla')) {
            _partComestible = HortPartComestible.fulla;
          }
          if (p.contains('arrel')) {
            _partComestible = HortPartComestible.arrel;
          }
          if (p.contains('flor') || p.contains('llegum')) {
            _partComestible = HortPartComestible.florLlegum;
          }
        }

        if (data['exigencia'] != null) {
          final e = data['exigencia'].toString().toLowerCase();
          if (e.contains('molt') || e.contains('exh')) {
            _exigencia = HortExigenciaNutrients.moltExigent;
          }
          if (e.contains('mitja') || e.contains('cons')) {
            _exigencia = HortExigenciaNutrients.mitjanamentExigent;
          }
          if (e.contains('poc')) {
            _exigencia = HortExigenciaNutrients.pocExigent;
          }
          if (e.contains('mil')) {
            _exigencia = HortExigenciaNutrients.millorant;
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Dades agronòmiques estimades per a Lleida (DARP)! 🚜',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error AI: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final aliatsList = _aliatsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final enemicsList = _enemicsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final newPlant = PlantaHort(
        id: widget.plant?.id ?? '', // Repo handles new ID if empty
        nomComu: _nomComuCtrl.text.trim(),
        nomCientific: _nomCientificCtrl.text.trim(),
        familiaBotanica: _familiaCtrl.text.trim(),
        partComestible: _partComestible,
        exigenciaNutrients: _exigencia,
        distanciaPlantacio: double.tryParse(_distanciaCtrl.text) ?? 30.0,
        distanciaLinies: double.tryParse(_linesCtrl.text) ?? 40.0,
        color: _color,
        // Agronomic Data
        rendiment: double.tryParse(_rendimentCtrl.text) ?? 0.0,
        diesEnCamp: int.tryParse(_cicleCtrl.text) ?? 90,
        tipusSembra: _tipusSembra,
        viaMetabolica: _viaMetabolica,
        grupRotacio: _calculateRotationGroup(_partComestible),
        // Preserve or default others
        aliats: aliatsList,
        enemics: enemicsList,
        funcio: _partComestible.label, // Default function to part
        marcPlantacio: '${_distanciaCtrl.text}x${_linesCtrl.text} cm',
      );

      await ref.read(hortRepositoryProvider).savePlant(newPlant);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Guardat correctament!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plant == null ? 'Nova Espècie' : 'Editar Espècie'),
        actions: [
          if (widget.plant != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar?'),
                    content: const Text(
                      'Estàs segur que vols eliminar aquesta planta?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sí'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await ref
                      .read(hortRepositoryProvider)
                      .deletePlant(widget.plant!.id);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name Section
            TextFormField(
              controller: _nomComuCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom Comú',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Cal un nom' : null,
            ),
            const SizedBox(height: 16),
            // Scientific Name with Magic Button
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nomCientificCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom Científic',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isAiLoading ? null : _fetchAI,
                  tooltip: 'Autocompletar amb IA',
                  icon: _isAiLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, color: Colors.purple),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.purple.shade50,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _familiaCtrl,
              decoration: const InputDecoration(
                labelText: 'Família Botànica (ex: Solanàcies)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Característiques',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Dropdowns for Enums
            DropdownButtonFormField<HortPartComestible>(
              key: ValueKey(_partComestible),
              initialValue: _partComestible,
              decoration: const InputDecoration(
                labelText: 'Part Comestible',
                border: OutlineInputBorder(),
              ),
              items: HortPartComestible.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Row(
                        children: [
                          Icon(e.icon, size: 20),
                          const SizedBox(width: 8),
                          Text(e.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _partComestible = v!),
            ),
            const SizedBox(height: 8),
            // Automatic Rotation Group Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getRotationColor(
                  _partComestible,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getRotationColor(_partComestible)),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync, color: _getRotationColor(_partComestible)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Grup Rotació Automàtic: ${_getRotationLabel(_partComestible)}',
                      style: TextStyle(
                        color: _getRotationColor(_partComestible),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<HortExigenciaNutrients>(
              key: ValueKey(_exigencia),
              initialValue: _exigencia,
              decoration: const InputDecoration(
                labelText: 'Exigència de Nutrients',
                border: OutlineInputBorder(),
              ),
              items: HortExigenciaNutrients.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Row(
                        children: [
                          Container(width: 16, height: 16, color: e.color),
                          const SizedBox(width: 8),
                          Text(e.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _exigencia = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<HortViaMetabolica>(
              key: ValueKey(_viaMetabolica),
              initialValue: _viaMetabolica,
              decoration: const InputDecoration(
                labelText: 'Fisiologia (C₃, C₄, CAM)',
                border: OutlineInputBorder(),
              ),
              items: HortViaMetabolica.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                  .toList(),
              onChanged: (v) => setState(() => _viaMetabolica = v!),
            ),

            const SizedBox(height: 24),
            const Text(
              'Cultiu',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _distanciaCtrl,
              decoration: const InputDecoration(
                labelText: 'Distància entre plantes (cm)',
                border: OutlineInputBorder(),
                suffixText: 'cm',
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  double.tryParse(v ?? '') != null ? null : 'Número invàlid',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _linesCtrl,
              decoration: const InputDecoration(
                labelText: 'Distància entre línies (cm)',
                border: OutlineInputBorder(),
                suffixText: 'cm',
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  double.tryParse(v ?? '') != null ? null : 'Número invàlid',
            ),

            const SizedBox(height: 24),
            const Text(
              'Dades Agronòmiques (Avançat)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rendimentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Rendiment Estim.',
                      border: OutlineInputBorder(),
                      suffixText: 'kg/m²',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _cicleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cicle',
                      border: OutlineInputBorder(),
                      suffixText: 'dies',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<HortTipusSembra>(
              key: ValueKey(_tipusSembra),
              initialValue: _tipusSembra,
              decoration: const InputDecoration(
                labelText: 'Mètode Inicial',
                border: OutlineInputBorder(),
              ),
              items: HortTipusSembra.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                  .toList(),
              onChanged: (v) => setState(() => _tipusSembra = v!),
            ),

            const SizedBox(height: 24),
            const Text(
              'Relacions (Al·lelopatia)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _aliatsCtrl,
              decoration: const InputDecoration(
                labelText: 'Plantes Aliades (separades per coma)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.favorite, color: Colors.pink),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _enemicsCtrl,
              decoration: const InputDecoration(
                labelText: 'Plantes Enemigues (separades per coma)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.cancel, color: Colors.red),
              ),
            ),

            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'Guardant...' : 'Guardar Espècie'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
