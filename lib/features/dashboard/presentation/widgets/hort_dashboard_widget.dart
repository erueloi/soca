import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../horticulture/data/repositories/hort_repository.dart';
import '../../../horticulture/domain/entities/espai_hort.dart';
import '../../../horticulture/domain/entities/garden_layout_config.dart';
import '../../../horticulture/domain/entities/planta_hort.dart';
import '../../../horticulture/domain/services/assistent_hort_service.dart';
import '../../../horticulture/domain/services/garden_irrigation_service.dart';
import '../../../horticulture/presentation/pages/garden_designer_page.dart';
import '../../../horticulture/presentation/pages/horticulture_page.dart';
import '../../../nursery/presentation/pages/nursery_page.dart';

class HortDashboardCarousel extends ConsumerStatefulWidget {
  const HortDashboardCarousel({super.key});

  @override
  ConsumerState<HortDashboardCarousel> createState() =>
      _HortDashboardCarouselState();
}

class _HortDashboardCarouselState extends ConsumerState<HortDashboardCarousel> {
  int _currentPage = 0;

  Future<void> _syncEspais(List<EspaiHort> espais) async {
    final irrigationService = ref.read(gardenIrrigationServiceProvider);
    final repo = ref.read(hortRepositoryProvider);

    for (final espai in espais) {
      try {
        final updatedEspai = await irrigationService.syncSoilBalance(espai);
        if (updatedEspai != espai) {
          await repo.saveEspai(updatedEspai);
        }
      } catch (e) {
        debugPrint('Error syncing soil balance for ${espai.nom}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(hortRepositoryProvider);

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: StreamBuilder<List<EspaiHort>>(
        stream: repo.getEspaisStream(),
        builder: (context, espaisSnap) {
          if (espaisSnap.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final espais = espaisSnap.data ?? [];

          if (espais.isNotEmpty) {
            _syncEspais(espais);
          }

          if (espais.isEmpty) {
            return _buildEmptyState(context);
          }

          return StreamBuilder<List<PlantaHort>>(
            stream: repo.getPlantsStream(),
            builder: (context, plantsSnap) {
              final plants = plantsSnap.data ?? [];

              return SizedBox(
                height: 280,
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        itemCount: espais.length,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (context, index) {
                          return _buildEspaiCard(
                            context,
                            espais[index],
                            plants,
                          );
                        },
                      ),
                    ),
                    if (espais.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            espais.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _currentPage == i ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: _currentPage == i
                                    ? const Color(0xFF556B2F)
                                    : Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: 280,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HorticulturePage()),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.grass, size: 56, color: Colors.green.shade300),
              const SizedBox(height: 12),
              Text(
                '+ Crear nou Espai',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dissenya el teu primer hort!',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEspaiCard(
    BuildContext context,
    EspaiHort espai,
    List<PlantaHort> plants,
  ) {
    final totalPlants = espai.placedPlants.length;
    final config = espai.layoutConfig;
    final numBeds = config?.numberOfBeds ?? 0;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GardenDesignerPage(espai: espai)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Row(
              children: [
                const Icon(Icons.grass, color: Color(0xFF556B2F), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    espai.nom,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: const Color(0xFF556B2F),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF556B2F).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🌱 $totalPlants plantes',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF556B2F),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: Icon(Icons.yard_outlined, color: Colors.green.shade600),
                    tooltip: '🌱 Incubadora',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NurseryPage()),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: Icon(Icons.info_outline, color: Colors.grey.shade400),
                    onPressed: () => _showInfoDialog(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // --- Bed Grid ---
            if (numBeds == 0)
              Expanded(
                child: Center(
                  child: Text(
                    'Cap bancal configurat',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.0,
                  ),
                  itemCount: numBeds > 6 ? 6 : numBeds, // Cap at 6
                  itemBuilder: (context, bedIdx) {
                    return _buildBedChip(espai, bedIdx, plants, config!);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBedChip(
    EspaiHort espai,
    int bedIndex,
    List<PlantaHort> plants,
    dynamic config,
  ) {
    // Bed name
    final bedData = config.beds[bedIndex];
    final bedName = bedData?.name ?? 'B${bedIndex + 1}';

    // Find dominant species in this bed
    final bedStartX = config.getBedStartX(bedIndex) * 100; // cm
    final bedEndX = bedStartX + config.getBedWidth(bedIndex) * 100;

    final Map<String, int> speciesCount = {};
    for (var p in espai.placedPlants) {
      double cx = p.x + p.width / 2;
      if (cx >= bedStartX && cx < bedEndX) {
        speciesCount[p.speciesId] = (speciesCount[p.speciesId] ?? 0) + 1;
      }
    }

    String mainCropName = 'Lliure';
    Color mainCropColor = Colors.grey;
    if (speciesCount.isNotEmpty) {
      final topSpeciesId = speciesCount.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      try {
        final plant = plants.firstWhere((p) => p.id == topSpeciesId);
        mainCropName = plant.nomComu;
        mainCropColor = plant.color;
      } catch (_) {
        mainCropName = '?';
      }
    }

    // Rotation health
    final health = _getBedHealth(espai, bedIndex, plants, config);
    final healthIcon = switch (health) {
      RotacioNivell.optim => '🟢',
      RotacioNivell.mitja => '🟡',
      RotacioNivell.alt => '🔴',
    };

    final bedDataSafe = (bedData ?? BedData()).copyWith(name: bedName);

    // Watering logic
    final irrigationService = ref.read(gardenIrrigationServiceProvider);
    final bedAreaSqm = config.getBedWidth(bedIndex) * config.totalLength;
    final wateringReq = irrigationService.getWateringRecommendation(
      bedDataSafe,
      bedAreaSqm,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: mainCropColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: mainCropColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(healthIcon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bedName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  mainCropName,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  wateringReq.actionText,
                  style: TextStyle(
                    fontSize: 10,
                    color: switch (wateringReq.status) {
                      WateringStatus.satiated => Colors.green.shade900,
                      WateringStatus.forecast => Colors.orange.shade900,
                      WateringStatus.critical => Colors.red.shade900,
                    },
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.grass, color: Color(0xFF556B2F)),
            SizedBox(width: 8),
            Text('Widget d\'Hort'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Indicadors de Salut (Rotació)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Text('🟢', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Òptim — La rotació de cultius és correcta.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Text('🟡', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Atenció — Mateixa part comestible o dues plantes exigents seguides.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Text('🔴', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alerta — Mateixa família botànica que l\'últim cicle. Risc de plagues.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Graella de Bancals',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                'Cada chip mostra el nom del bancal, el cultiu dominant '
                '(l\'espècie amb més plantes), i l\'indicador de salut.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 8),
              Text(
                'Si un bancal mostra "Lliure", no té cap planta assignada.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              SizedBox(height: 16),
              Text(
                'Navegació',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                'Toca la targeta per obrir el dissenyador d\'hort '
                'directament amb les dades de l\'espai seleccionat.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entès'),
          ),
        ],
      ),
    );
  }

  RotacioNivell _getBedHealth(
    EspaiHort espai,
    int bedIndex,
    List<PlantaHort> plants,
    dynamic config,
  ) {
    try {
      return AssistentHort.saludBancal(
        historic: espai.historic,
        bedIndex: bedIndex,
        plants: plants,
        currentPlants: espai.placedPlants,
        getBedStartCm: (xMeters) => config.getBedStartX(0) * 100,
        getBedEndCm: (xMeters) =>
            (config.getBedStartX(config.numberOfBeds - 1) +
                config.getBedWidth(config.numberOfBeds - 1)) *
            100,
        getBedIndexFromX: (xMeters) {
          for (int i = 0; i < config.numberOfBeds; i++) {
            double start = config.getBedStartX(i);
            double end = start + config.getBedWidth(i);
            if (xMeters >= start && xMeters < end) return i;
          }
          return null;
        },
      );
    } catch (_) {
      return RotacioNivell.optim;
    }
  }
}
