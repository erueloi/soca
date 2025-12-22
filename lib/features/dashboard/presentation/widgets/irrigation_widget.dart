import 'package:flutter/material.dart';

class IrrigationWidget extends StatelessWidget {
  const IrrigationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Gestió de Reg',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(width: 8),
                    _BlinkingLed(),
                  ],
                ),
                Icon(Icons.water_drop, color: Colors.blue[600], size: 28),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildZoneRow(context, 'Zona A - Oliveres', true),
                  _buildZoneRow(context, 'Zona B - Horta', false),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('PARADA EMERGÈNCIA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red[800],
                  elevation: 0,
                  side: BorderSide(color: Colors.red[200]!),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneRow(BuildContext context, String name, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.circle_outlined,
            color: isActive ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Switch(
            value: isActive,
            activeTrackColor: Colors.blue[600],
            activeThumbColor: Colors.white,
            onChanged: (val) {},
          ),
        ],
      ),
    );
  }
}

class _BlinkingLed extends StatefulWidget {
  @override
  State<_BlinkingLed> createState() => _BlinkingLedState();
}

class _BlinkingLedState extends State<_BlinkingLed>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.6),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
