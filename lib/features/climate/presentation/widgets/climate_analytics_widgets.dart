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
                const Row(
                  children: [
                    Icon(Icons.insights, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Anàlisi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 16,
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
        maximum: 31,
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
      1: FlexColumnWidth(1), // ET0
      2: FixedColumnWidth(40), // Kc
      3: FlexColumnWidth(1), // ETc
      4: FlexColumnWidth(1), // Pluja
      5: FlexColumnWidth(1), // P.Ef
      6: FlexColumnWidth(1.2), // Balanç
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
                width: 800, // Fixed width for the table content
                height: 400, // Fixed height for scrolling
                child: Column(
                  children: [
                    // Sticky Header
                    Container(
                      color: Colors.grey.shade100,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Table(
                        columnWidths: columnWidths,
                        children: const [
                          TableRow(
                            children: [
                              Text(
                                'Data',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'ET0',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'Kc',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'ETc',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'Pluja',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'P.Ef',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'Balanç',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
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
                            final pef = (d.rain >= 4.0 ? d.rain * 0.75 : 0.0);
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
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    d.et0.toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    '0.6',
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
                                    d.rain.toStringAsFixed(1),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    pef.toStringAsFixed(1),
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
}
