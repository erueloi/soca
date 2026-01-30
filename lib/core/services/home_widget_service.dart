import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/tasks/domain/entities/task.dart';
import '../../features/dashboard/domain/weather_model.dart';
import '../../features/trees/domain/entities/tree.dart';
import '../../features/trees/domain/entities/tree_extensions.dart';

// Provider to easily access this service
final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) {
  return HomeWidgetService();
});

class HomeWidgetService {
  static const String _agendaWidgetProvider = 'SocaWidgetProvider';
  static const String _statusWidgetProvider = 'SocaStatusWidgetProvider';

  Future<void> updateAgenda(List<Task> allTasks) async {
    // 1. Filter and Sort
    final pendingTasks = allTasks.where((t) => !t.isDone).toList();

    // Sort by Due Date (Nulls last)
    pendingTasks.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) {
        return a.order.compareTo(b.order);
      }
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    // Take top 3
    final top3 = pendingTasks.take(3).toList();

    // 2. Save Data
    for (int i = 0; i < 3; i++) {
      if (i < top3.length) {
        final task = top3[i];
        await HomeWidget.saveWidgetData<String>('task_title_$i', task.title);
        await HomeWidget.saveWidgetData<String>(
          'task_desc_$i',
          task.description.isNotEmpty
              ? task.description
              : _formatDate(task.dueDate),
        );
        await HomeWidget.saveWidgetData<String>(
          'task_price_$i',
          task.totalBudget > 0 ? '${task.totalBudget.toStringAsFixed(0)}€' : '',
        );
        await HomeWidget.saveWidgetData<String>(
          'task_color_$i',
          _getBucketColor(task.bucket),
        );
      } else {
        // Clear slots
        await HomeWidget.saveWidgetData<String>('task_title_$i', null);
        await HomeWidget.saveWidgetData<String>('task_desc_$i', null);
        await HomeWidget.saveWidgetData<String>('task_price_$i', null);
        await HomeWidget.saveWidgetData<String>('task_color_$i', null);
      }
    }

    // 3. Update Widget
    await HomeWidget.updateWidget(androidName: _agendaWidgetProvider);
  }

  Future<void> updateStatus(WeatherModel weather) async {
    // 1. Save Weather Data
    await HomeWidget.saveWidgetData<String>(
      'weather_temp',
      weather.temperature.toStringAsFixed(1),
    );
    await HomeWidget.saveWidgetData<String>(
      'weather_humidity',
      '${weather.humidity}',
    );
    await HomeWidget.saveWidgetData<String>(
      'weather_wind',
      (weather.windSpeed * 3.6).toStringAsFixed(0), // m/s to km/h
    );
    await HomeWidget.saveWidgetData<String>(
      'weather_et0',
      weather.et0.toStringAsFixed(1),
    );
    await HomeWidget.saveWidgetData<String>(
      'weather_advice',
      weather.irrigationAdvice,
    );
    await HomeWidget.saveWidgetData<String>(
      'weather_advice_color',
      _getAdviceColor(weather.irrigationAdvice),
    );

    // Alert logic
    String? alertMsg;
    if (weather.alerts.isNotEmpty) {
      alertMsg = weather.alerts.first.title.toUpperCase();
    }
    await HomeWidget.saveWidgetData<String>('weather_alert', alertMsg);

    // 2. Update Widget
    await HomeWidget.updateWidget(androidName: _statusWidgetProvider);
  }

  /// Update tree irrigation status for the Status widget
  Future<void> updateTreeIrrigationStatus(List<Tree> trees) async {
    final criticalCount = trees
        .where((t) => t.waterStatusText == 'Estrès Hídric')
        .length;
    final optionalCount = trees
        .where((t) => t.waterStatusText == 'Reg Opcional')
        .length;

    String ledColor;
    String statusText;

    if (criticalCount > 0) {
      ledColor = 'red';
      statusText = '$criticalCount arbres amb Estrès';
    } else if (optionalCount > 0) {
      ledColor = 'amber';
      statusText = '$optionalCount arbres - Reg Opcional';
    } else {
      ledColor = 'green';
      statusText = 'Tots els arbres OK';
    }

    await HomeWidget.saveWidgetData<String>('tree_led_color', ledColor);
    await HomeWidget.saveWidgetData<String>('tree_status_text', statusText);

    await HomeWidget.updateWidget(androidName: _statusWidgetProvider);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sense data';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final comparison = DateTime(date.year, date.month, date.day);

    if (comparison == today) return 'Avui';
    if (comparison == today.add(const Duration(days: 1))) return 'Demà';

    return DateFormat('dd MMM').format(date);
  }

  String _getBucketColor(String bucket) {
    final lowerBucket = bucket.toLowerCase();
    if (lowerBucket.contains('compra')) {
      return '#26A69A'; // Teal for shopping
    } else if (lowerBucket.contains('planifica')) {
      return '#42A5F5'; // Blue for planning
    } else if (lowerBucket.contains('manten')) {
      return '#FFA726'; // Orange for maintenance
    } else if (lowerBucket.contains('urgent') ||
        lowerBucket.contains('pendent')) {
      return '#EF5350'; // Red for urgent
    }
    return '#4CAF50'; // Default green
  }

  String _getAdviceColor(String advice) {
    if (advice.contains('No regar') || advice.contains('Esperar')) {
      return '#4CAF50'; // Green
    }
    if (advice.contains('Reg recomanat')) {
      return '#EF5350'; // Red
    }
    return '#FFC107'; // Amber
  }

  Future<void> clearWidgetData() async {
    // Clear Agenda
    for (int i = 0; i < 3; i++) {
      await HomeWidget.saveWidgetData<String>('task_title_$i', null);
      await HomeWidget.saveWidgetData<String>('task_desc_$i', null);
      await HomeWidget.saveWidgetData<String>('task_price_$i', null);
      await HomeWidget.saveWidgetData<String>('task_color_$i', null);
    }
    await HomeWidget.updateWidget(androidName: _agendaWidgetProvider);

    // Clear Status
    await HomeWidget.saveWidgetData<String>('weather_temp', "--");
    await HomeWidget.saveWidgetData<String>('weather_humidity', "--");
    await HomeWidget.saveWidgetData<String>('weather_wind', "--");
    await HomeWidget.saveWidgetData<String>('weather_et0', "--");
    await HomeWidget.saveWidgetData<String>('weather_advice', "No connectat");
    await HomeWidget.saveWidgetData<String>('weather_advice_color', "#9E9E9E");
    await HomeWidget.saveWidgetData<String>('weather_alert', null);
    await HomeWidget.saveWidgetData<String>('tree_led_color', 'green');
    await HomeWidget.saveWidgetData<String>(
      'tree_status_text',
      'Tots els arbres OK',
    );
    await HomeWidget.updateWidget(androidName: _statusWidgetProvider);
  }
}
