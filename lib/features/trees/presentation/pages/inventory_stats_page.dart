import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/tree.dart';
import 'species_library_page.dart';

class InventoryStatsPage extends StatefulWidget {
  final List<Tree> trees;

  const InventoryStatsPage({super.key, required this.trees});

  @override
  State<InventoryStatsPage> createState() => _InventoryStatsPageState();
}

class _InventoryStatsPageState extends State<InventoryStatsPage> {
  int? _selectedYear;

  @override
  Widget build(BuildContext context) {
    // 0. Filter Logic
    final availableYears =
        widget.trees.map((t) => t.plantingDate.year).toSet().toList()
          ..sort((a, b) => b.compareTo(a)); // Descending

    final filteredTrees = _selectedYear == null
        ? widget.trees
        : widget.trees
              .where((t) => t.plantingDate.year == _selectedYear)
              .toList();

    // 1. Calculations
    final speciesMap = <String, _SpeciesStat>{};
    final vigorMap = <String, int>{};
    final ecoMap = <String, int>{};
    final statusMap = <String, int>{};
    final formatMap = <String, int>{};

    double totalHeight = 0;
    int heightCount = 0;
    double totalDiameter = 0;
    int diameterCount = 0;
    double totalInvestment = 0;

    for (final tree in filteredTrees) {
      // Species (Group by Common Name, store Scientific)
      final common = tree.commonName.isEmpty ? 'Desconegut' : tree.commonName;
      if (!speciesMap.containsKey(common)) {
        speciesMap[common] = _SpeciesStat(
          commonName: common,
          scientificName: tree.species,
          count: 0,
        );
      }
      speciesMap[common]!.count++;

      // Vigor
      final vigor = tree.vigor ?? 'Desconegut';
      vigorMap[vigor] = (vigorMap[vigor] ?? 0) + 1;

      // Ecological Function
      final eco = tree.ecologicalFunction ?? 'Sense definir';
      ecoMap[eco] = (ecoMap[eco] ?? 0) + 1;

      // Status (Survival)
      final status = tree.status;
      statusMap[status] = (statusMap[status] ?? 0) + 1;

      // Planting Format
      final format = tree.plantingFormat ?? 'Desconegut';
      formatMap[format] = (formatMap[format] ?? 0) + 1;

      // KPIs
      if (tree.height != null && tree.height! > 0) {
        totalHeight += tree.height!;
        heightCount++;
      }
      if (tree.trunkDiameter != null && tree.trunkDiameter! > 0) {
        totalDiameter += tree.trunkDiameter!;
        diameterCount++;
      }
      if (tree.price != null) {
        totalInvestment += tree.price!;
      }
    }

    final avgHeight = heightCount > 0 ? totalHeight / heightCount : 0.0;
    final avgDiameter = diameterCount > 0 ? totalDiameter / diameterCount : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadístiques d\'Inventari'),
        actions: [
          // Year Filter
          DropdownButton<int>(
            value: _selectedYear,
            dropdownColor: Colors.white,
            icon: const Icon(Icons.filter_list, color: Colors.indigo),
            underline: Container(),
            hint: const Text(
              'Tots els anys',
              style: TextStyle(color: Colors.black),
            ),
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text('Tots els anys'),
              ),
              ...availableYears.map(
                (y) => DropdownMenuItem(value: y, child: Text(y.toString())),
              ),
            ],
            onChanged: (val) => setState(() => _selectedYear = val),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- KPIs Row ---
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    context,
                    'Alçada Mitjana (Filtrada)',
                    '${avgHeight.toStringAsFixed(2)} cm',
                    Icons.height,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiCard(
                    context,
                    'Diàmetre Mitjà (Filtrat)',
                    '${avgDiameter.toStringAsFixed(2)} cm',
                    Icons.circle_outlined,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildKpiCard(
              context,
              'Inversió Total (Filtrada)',
              '${totalInvestment.toStringAsFixed(2)} €',
              Icons.attach_money,
              Colors.green,
            ),

            const SizedBox(height: 24),
            const Divider(),

            // --- Species Distribution (Pie) ---
            const SizedBox(height: 16),
            Text(
              'Distribució d\'Espècies',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Clica al nom per veure la fitxa',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildSpeciesPieChart(context, speciesMap),

            const SizedBox(height: 24),
            const Divider(),

            // --- Status (Survival) ---
            const SizedBox(height: 16),
            Text(
              'Taxa de Supervivència (Estat)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            _buildStatusPieChart(statusMap),

            const SizedBox(height: 24),
            const Divider(),

            // --- Health Status (Bar) ---
            const SizedBox(height: 16),
            Text(
              'Estat de Salut (Vigor)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            _buildVigorBarChart(vigorMap),

            const SizedBox(height: 24),
            const Divider(),

            // --- Ecological Function ---
            const SizedBox(height: 16),
            Text(
              'Funció Ecològica',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            _buildEcoPieChart(ecoMap),

            const SizedBox(height: 24),
            const Divider(),

            // --- Planting Format ---
            const SizedBox(height: 16),
            Text(
              'Format de Plantació',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            _buildFormatBarChart(formatMap),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeciesPieChart(
    BuildContext context,
    Map<String, _SpeciesStat> data,
  ) {
    if (data.isEmpty) return const Center(child: Text('Sense dades'));

    final sortedEntries = data.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // Limit to top 6 + Others
    List<_SpeciesStat> displayList;
    if (sortedEntries.length > 6) {
      displayList = sortedEntries.take(5).toList();
      int othersCount = 0;
      for (var i = 5; i < sortedEntries.length; i++) {
        othersCount += sortedEntries[i].count;
      }
      displayList.add(
        _SpeciesStat(
          commonName: 'Altres',
          scientificName: '',
          count: othersCount,
        ),
      );
    } else {
      displayList = sortedEntries;
    }

    final List<Color> colors = [
      Colors.green.shade400,
      Colors.blue.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
      Colors.grey.shade400,
    ];

    return SizedBox(
      height: 300, // Increased height for clearer legend
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 250, // Fixed width for Pie Chart to avoid over-expanding
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: displayList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final total = data.values.fold(
                    0,
                    (sum, item) => sum + item.count,
                  );
                  return PieChartSectionData(
                    color: colors[index % colors.length],
                    value: item.count.toDouble(),
                    title:
                        '${item.count}\n${(item.count / total * 100).toStringAsFixed(1)}%',
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Scrollable Legend
          SizedBox(
            width: 300,
            child: ListView.builder(
              physics:
                  const NeverScrollableScrollPhysics(), // Or scrollable if needed
              shrinkWrap: true,
              itemCount: displayList.length,
              itemBuilder: (context, index) {
                final item = displayList[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: item.scientificName.isNotEmpty
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SpeciesLibraryPage(
                                  initialSearchQuery: item.scientificName
                                      .trim(),
                                ),
                              ),
                            );
                          }
                        : null,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors[index % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                              ),
                              children: [
                                TextSpan(
                                  text: item.commonName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (item.scientificName.isNotEmpty)
                                  TextSpan(
                                    text: '\n${item.scientificName}',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPieChart(Map<String, int> data) {
    if (data.isEmpty) return const Center(child: Text('Sense dades'));

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Custom colors for status
    Color getColor(String status) {
      final s = status.toLowerCase();
      if (s.contains('viable')) return Colors.green;
      if (s == 'mort') return Colors.red;
      if (s == 'malalt') return Colors.orange;
      return Colors.grey;
    }

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: sortedEntries.map((entry) {
                  final total = data.values.fold(0, (sum, val) => sum + val);
                  return PieChartSectionData(
                    color: getColor(entry.key),
                    value: entry.value.toDouble(),
                    title:
                        '${entry.value}\n${(entry.value / total * 100).toStringAsFixed(1)}%',
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sortedEntries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: getColor(entry.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${entry.key} (${entry.value})'),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVigorBarChart(Map<String, int> data) {
    if (data.isEmpty) return const Center(child: Text('Sense dades'));

    final order = ['Alt', 'Mitjà', 'Baix', 'Desconegut'];
    final sortedData = <String, int>{};
    for (var key in order) {
      if (data.containsKey(key)) {
        sortedData[key] = data[key]!;
      }
    }
    data.forEach((k, v) {
      if (!sortedData.containsKey(k)) sortedData[k] = v;
    });

    final maxVal = data.values.fold(0, (max, v) => v > max ? v : max);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxVal * 1.2).toDouble(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final key = sortedData.keys.elementAt(group.x.toInt());
                return BarTooltipItem(
                  '$key\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: (rod.toY).toStringAsFixed(0),
                      style: const TextStyle(color: Colors.yellow),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final keys = sortedData.keys.toList();
                  if (value.toInt() >= 0 && value.toInt() < keys.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        keys[value.toInt()],
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
              ), // Hide Y axis numbers to clean up
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: sortedData.entries.toList().asMap().entries.map((entry) {
            Color color = Colors.grey;
            if (entry.value.key == 'Alt') color = Colors.green;
            if (entry.value.key == 'Mitjà') color = Colors.orange;
            if (entry.value.key == 'Baix') color = Colors.red;

            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value.toDouble(),
                  color: color,
                  width: 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEcoPieChart(Map<String, int> data) {
    if (data.isEmpty) return const Center(child: Text('Sense dades'));

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<Color> colors = [
      Colors.teal,
      Colors.amber,
      Colors.brown,
      Colors.indigo,
      Colors.pink,
    ];

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: sortedEntries.asMap().entries.map((entry) {
                  final total = data.values.fold(0, (sum, val) => sum + val);
                  return PieChartSectionData(
                    color: colors[entry.key % colors.length],
                    value: entry.value.value.toDouble(),
                    title:
                        '${entry.value.value}\n${(entry.value.value / total * 100).toStringAsFixed(1)}%',
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 12, // Slightly smaller to fit 2 lines
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sortedEntries.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[entry.key % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(entry.value.key),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatBarChart(Map<String, int> data) {
    if (data.isEmpty) return const Center(child: Text('Sense dades'));

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxVal = data.values.fold(0, (max, v) => v > max ? v : max);

    return SizedBox(
      height: 250, // More height for labels
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxVal * 1.2).toDouble(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final key = sortedEntries[group.x.toInt()].key;
                return BarTooltipItem(
                  '$key\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: (rod.toY).toStringAsFixed(0),
                      style: const TextStyle(color: Colors.yellow),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 &&
                      value.toInt() < sortedEntries.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: SizedBox(
                        width: 60,
                        child: Text(
                          sortedEntries[value.toInt()].key,
                          style: const TextStyle(fontSize: 9),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 40,
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: sortedEntries.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value.toDouble(),
                  color: Colors.purple.shade300,
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SpeciesStat {
  final String commonName;
  final String scientificName;
  int count;

  _SpeciesStat({
    required this.commonName,
    required this.scientificName,
    required this.count,
  });
}
