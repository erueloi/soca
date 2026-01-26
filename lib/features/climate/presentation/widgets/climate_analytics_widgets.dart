import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../domain/climate_model.dart';
// Removed unused weather_provider import

class ClimateAnalyticsSection extends StatelessWidget {
  final List<ClimateDailyData> days;
  final List<ClimateDailyData>? previousDays;

  const ClimateAnalyticsSection({
    super.key,
    required this.days,
    this.previousDays,
  });

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    // Sort days ensuring chronological order
    final sortedDays = List<ClimateDailyData>.from(days)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Calculate Trend/Prediction for Narrative
    final narrative = _generateNarrative(sortedDays);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Narrative Card
        Card(
          color: Colors.blue.shade50,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.blue.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insights, color: Colors.blue),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Anàlisi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 20,
                          ),
                          tooltip: "Com es calcula?",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showExplanationDialog(context),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (sortedDays.isNotEmpty)
                      Text(
                        _getLastUpdatedString(sortedDays.last),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  narrative,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 2. Unified Interactive Chart
        Text(
          'Monitorització Unificada',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 350,
          child: _UnifiedClimateChart(
            days: sortedDays,
            previousDays: previousDays,
          ),
        ),
        const SizedBox(height: 24),

        // 3. Collapsible Detailed Table (Centered & Collapsed)
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: ExpansionTile(
                initiallyExpanded: false,
                title: Text(
                  'Desglossament Diari',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [_ClimateBalanceTable(days: sortedDays)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _generateNarrative(List<ClimateDailyData> days) {
    // Find last day with soilBalance
    final validDays = days.where((d) => d.soilBalance != null).toList();
    if (validDays.isEmpty) {
      return "No hi ha dades de balanç hídric calculades per aquest mes.";
    }

    final lastDay = validDays.last;
    final currentBalance = lastDay.soilBalance!;

    // Analyze trend
    String source = "l'històric";
    // Find last significant rain (>4mm)
    final recentRain = validDays.lastWhere(
      (d) => d.rain >= 4.0,
      orElse: () => lastDay, // fallback
    );
    if (recentRain.rain >= 4.0) {
      source = "la pluja del dia ${recentRain.date.day}";
    }

    // Prediction
    // Avg ETc of last 7 days (or available)
    double sumEtc = 0;
    int count = 0;
    for (var d in validDays.reversed.take(7)) {
      sumEtc += (d.et0 * 0.6);
      count++;
    }
    double avgEtc = count > 0 ? sumEtc / count : 2.5; // Default 2.5 if no data
    if (avgEtc < 0.1) avgEtc = 0.5; // Avoid div by zero

    int daysToIrrigation = 0;
    // Threshold is -15
    if (currentBalance <= -15) {
      return "Actualment la reserva és crítica (${currentBalance.toStringAsFixed(1)} mm). Es recomana regar immediatament.";
    } else {
      double simulated = currentBalance;
      while (simulated > -15 && daysToIrrigation < 30) {
        simulated -= avgEtc;
        daysToIrrigation++;
      }
    }

    return "Actualment la terra conserva ${currentBalance.toStringAsFixed(1)} mm de reserva, principalment de $source. \n\nNo es preveu necessitat de reg fins d'aquí a $daysToIrrigation dies (basat en ETc mitjana de ${avgEtc.toStringAsFixed(1)} mm/dia).";
  }

  String _getLastUpdatedString(ClimateDailyData lastDay) {
    final String dateStr = DateFormat('dd/MM', 'ca').format(lastDay.date);
    String txt = "Dades: $dateStr";

    if (lastDay.lastUpdated != null) {
      final String timeStr = DateFormat(
        'HH:mm',
        'ca',
      ).format(lastDay.lastUpdated!);
      txt += " ($timeStr)";
    }

    if (lastDay.calculatedAt != null) {
      final String calcStr = DateFormat(
        'dd/MM HH:mm',
        'ca',
      ).format(lastDay.calculatedAt!);
      txt += " | Recàlcul: $calcStr";
    }

    return txt;
  }

  void _showExplanationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Com es calculen les dades? 🧮'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoItem(
                  context,
                  'ET0 (Evapotranspiració Referència)',
                  'És la quantitat d\'aigua que perdria una superfície verda estàndard. Es calcula científicament (Penman-Monteith) combinant:\n• Temperatura\n• Humitat\n• Vent\n• Radiació Solar',
                  Icons.water_drop_outlined,
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  context,
                  'ETc (Evapotranspiració Cultiu)',
                  'És l\'aigua que realment consumeix el teu cultiu. S\'aplica un coeficient (Kc) a la ET0.\n\nFórmula: ETc = ET0 x Kc\n(Fem servir Kc=0.6 per defecte)',
                  Icons.local_florist_outlined,
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  context,
                  'Balanç Hídric (Reserva)',
                  'Simula l\'aigua útil que queda disponible al sòl per a les arrels. Si plou, suma. Si fa calor, resta (ETc).\n\nFórmula:\nReserva Ahir + Pluja - ETc',
                  Icons.layers_outlined,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(),
                ),
                Text(
                  'Si el balanç és molt negatiu (< -15 mm), significa que l\'arbre ha esgotat la reserva fàcil i comença a patir estrès.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entesos'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    String title,
    String desc,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blueGrey, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontSize: 13, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _UnifiedClimateChart extends StatefulWidget {
  final List<ClimateDailyData> days;
  final List<ClimateDailyData>? previousDays;
  const _UnifiedClimateChart({required this.days, this.previousDays});

  @override
  State<_UnifiedClimateChart> createState() => _UnifiedClimateChartState();
}

class _UnifiedClimateChartState extends State<_UnifiedClimateChart> {
  late ZoomPanBehavior _zoomPanBehavior;

  @override
  void initState() {
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      zoomMode: ZoomMode.x,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      zoomPanBehavior: _zoomPanBehavior,
      legend: const Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        overflowMode: LegendItemOverflowMode.wrap,
      ),
      tooltipBehavior: TooltipBehavior(enable: true, shared: true),
      // Define Axes
      primaryXAxis: const NumericAxis(
        interval: 1,
        minimum: 1,
        // Show only 10 days at a time to avoid compression on mobile
        autoScrollingDelta: 10,
        autoScrollingMode: AutoScrollingMode.end,
        decimalPlaces: 0,
        title: AxisTitle(text: 'Dia'),
        majorGridLines: MajorGridLines(width: 0),
      ),
      primaryYAxis: const NumericAxis(
        title: AxisTitle(text: 'Aigua (mm)'),
        minimum: -25,
        maximum: 60,
        plotBands: <PlotBand>[
          PlotBand(
            start: 35,
            end: 35,
            borderColor: Colors.blue,
            borderWidth: 2,
            dashArray: <double>[5, 5],
            text: 'Max',
            horizontalTextAlignment: TextAnchor.end,
            textStyle: TextStyle(color: Colors.blue, fontSize: 10),
          ),
          PlotBand(
            start: -5,
            end: -5,
            borderColor: Colors.orange,
            borderWidth: 2,
            dashArray: <double>[5, 5],
            text: 'Estrès',
            horizontalTextAlignment: TextAnchor.end,
            textStyle: TextStyle(color: Colors.orange, fontSize: 10),
          ),
          PlotBand(
            start: -15,
            end: -15,
            borderColor: Colors.red,
            borderWidth: 2,
            dashArray: <double>[5, 5],
            text: 'Reg',
            horizontalTextAlignment: TextAnchor.end,
            textStyle: TextStyle(color: Colors.red, fontSize: 10),
          ),
        ],
      ),
      axes: <ChartAxis>[
        const NumericAxis(
          name: 'yAxisWind',
          title: AxisTitle(text: 'Vent / Rad'),
          opposedPosition: true,
          minimum: 0,
          maximum: 100,
          interval: 25,
          majorGridLines: MajorGridLines(width: 0),
        ),
      ],
      series: <CartesianSeries>[
        // 0. Previous Year Rain (Grey Background Bars)
        if (widget.previousDays != null)
          ColumnSeries<ClimateDailyData, int>(
            name: 'Pluja Any Anterior',
            dataSource: widget.previousDays!,
            xValueMapper: (ClimateDailyData d, _) => d.date.day,
            yValueMapper: (ClimateDailyData d, _) => d.rain,
            color: Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
            spacing: 0.1, // Slight gap
            isVisibleInLegend: true,
          ),

        // 1. Rain (Column)
        ColumnSeries<ClimateDailyData, int>(
          name: 'Pluja',
          dataSource: widget.days,
          xValueMapper: (ClimateDailyData d, _) => d.date.day,
          yValueMapper: (ClimateDailyData d, _) => d.rain,
          color: Colors.blue.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(2),
        ),
        // 2. Soil Balance (Spline Area)
        SplineAreaSeries<ClimateDailyData, int>(
          name: 'Reserva Hídrica',
          dataSource: widget.days.where((d) => d.soilBalance != null).toList(),
          xValueMapper: (ClimateDailyData d, _) => d.date.day,
          yValueMapper: (ClimateDailyData d, _) => d.soilBalance,
          borderColor: Colors.teal,
          color: Colors.teal.withValues(alpha: 0.1),
          borderWidth: 3,
          markerSettings: const MarkerSettings(isVisible: false),
        ),
        // 3. Max Temp (Red Line)
        LineSeries<ClimateDailyData, int>(
          name: 'T. Màx (°C)',
          dataSource: widget.days,
          xValueMapper: (ClimateDailyData d, _) => d.date.day,
          yValueMapper: (ClimateDailyData d, _) => d.maxTemp,
          color: Colors.redAccent,
          width: 2,
          isVisibleInLegend: true,
        ),
        // 4. Min Temp (Blue Line)
        LineSeries<ClimateDailyData, int>(
          name: 'T. Mín (°C)',
          dataSource: widget.days,
          xValueMapper: (ClimateDailyData d, _) => d.date.day,
          yValueMapper: (ClimateDailyData d, _) => d.minTemp,
          color: Colors.lightBlue,
          width: 2,
          isVisibleInLegend: true,
        ),
        // 5. Humidity (Purple, Right Axis)
        LineSeries<ClimateDailyData, int>(
          name: 'Humitat (%)',
          dataSource: widget.days,
          xValueMapper: (ClimateDailyData d, _) => d.date.day,
          yValueMapper: (ClimateDailyData d, _) => d.humidity,
          yAxisName: 'yAxisWind',
          color: Colors.purpleAccent,
          width: 1.5,
          dashArray: <double>[2, 2],
          isVisibleInLegend: true,
        ),
        // 3. Wind (Line, Right Axis)
        LineSeries<ClimateDailyData, int>(
          name: 'Vent (km/h)',
          dataSource: widget.days,
          xValueMapper: (ClimateDailyData d, _) => d.date.day,
          yValueMapper: (ClimateDailyData d, _) => d.windSpeed * 3.6,
          yAxisName: 'yAxisWind',
          color: Colors.grey,
          width: 1.5,
          isVisibleInLegend: true,
        ),
        // 4. Radiation (Line, Right Axis)
        LineSeries<ClimateDailyData, int>(
          name: 'Radiació (MJ/m²)',
          dataSource: widget.days,
          xValueMapper: (ClimateDailyData d, _) => d.date.day,
          yValueMapper: (ClimateDailyData d, _) => d.radiation,
          yAxisName: 'yAxisWind',
          color: Colors.orange,
          width: 1.5,
          dashArray: <double>[5, 5],
          isVisibleInLegend: true,
        ),
      ],
    );
  }
}

class _ClimateBalanceTable extends StatelessWidget {
  final List<ClimateDailyData> days;
  const _ClimateBalanceTable({required this.days});

  @override
  Widget build(BuildContext context) {
    // Define shared column widths for alignment
    const Map<int, TableColumnWidth> columnWidths = {
      0: FixedColumnWidth(60), // Data
      1: FixedColumnWidth(40), // TMax
      2: FixedColumnWidth(40), // TMin
      3: FixedColumnWidth(40), // Hum
      4: FixedColumnWidth(45), // Vent
      5: FixedColumnWidth(45), // Rad
      6: FlexColumnWidth(1), // Pluja
      7: FlexColumnWidth(1), // ET0
      8: FlexColumnWidth(1), // ETc
      9: FlexColumnWidth(1.2), // Balanç
    };

    final rows = days.where((d) => d.soilBalance != null).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Center(
              child: SizedBox(
                width: 1000, // Increased width further
                height: 400, // Fixed height for scrolling
                child: Column(
                  children: [
                    // Sticky Header
                    Container(
                      color: Colors.grey.shade100,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Table(
                        columnWidths: columnWidths,
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.bottom,
                        children: [
                          TableRow(
                            children: [
                              _buildHeader('Data', ''),
                              _buildHeader('Max', '°C', color: Colors.red),
                              _buildHeader('Min', '°C', color: Colors.blue),
                              _buildHeader('Hum', '%', color: Colors.purple),
                              _buildHeader('Vent', 'km/h', color: Colors.grey),
                              _buildHeader(
                                'Rad',
                                'MJ/m²',
                                color: Colors.orange.shade800,
                              ),
                              _buildHeader('Pluja', 'mm'),
                              _buildHeader('ET0', 'mm'),
                              _buildHeader('ETc', 'mm'),
                              _buildHeader('Balanç', 'mm'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Scrollable Body
                    Expanded(
                      child: SingleChildScrollView(
                        child: Table(
                          columnWidths: columnWidths,
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: rows.map((d) {
                            final etc = d.et0 * 0.6;
                            final sb = d.soilBalance!;

                            Color? balanceColor;
                            if (sb > -5) {
                              balanceColor = Colors.green.shade50; // Wet
                            } else if (sb < -15) {
                              balanceColor = Colors.red.shade50; // Critical
                            } else {
                              balanceColor = Colors.orange.shade50; // Stress
                            }

                            return TableRow(
                              decoration: BoxDecoration(
                                color: balanceColor,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    DateFormat('dd/MM').format(d.date),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                _buildCell(
                                  d.maxTemp.toStringAsFixed(0),
                                  Colors.red,
                                ),
                                _buildCell(
                                  d.minTemp.toStringAsFixed(0),
                                  Colors.blue,
                                ),
                                _buildCell(
                                  d.humidity.toStringAsFixed(0),
                                  Colors.purple,
                                ),
                                _buildCell(
                                  (d.windSpeed * 3.6).toStringAsFixed(0),
                                  Colors.grey.shade700,
                                ),
                                _buildCell(
                                  d.radiation.toStringAsFixed(1),
                                  Colors.orange.shade800,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    d.rain.toStringAsFixed(1),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: d.rain > 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: d.rain > 0 ? Colors.blue : null,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    d.et0.toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    etc.toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    sb.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(String title, String unit, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        if (unit.isNotEmpty)
          Text(
            unit,
            style: TextStyle(
              fontSize: 9,
              color: color?.withValues(alpha: 0.7) ?? Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildCell(String value, Color color) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
      ),
    );
  }
}
