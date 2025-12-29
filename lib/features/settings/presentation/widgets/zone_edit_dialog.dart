import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../domain/entities/farm_config.dart';

class ZoneEditDialog extends StatefulWidget {
  final FarmZone? zone;

  const ZoneEditDialog({super.key, this.zone});

  @override
  State<ZoneEditDialog> createState() => _ZoneEditDialogState();
}

class _ZoneEditDialogState extends State<ZoneEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _cropTypeController;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.zone?.name ?? '');
    _cropTypeController = TextEditingController(
      text: widget.zone?.cropType ?? '',
    );
    _color = widget.zone != null
        ? Color(int.parse(widget.zone!.colorHex, radix: 16))
        : Colors.blue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cropTypeController.dispose();
    super.dispose();
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tria un color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _color,
            onColorChanged: (c) {
              setState(() => _color = c);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.zone == null ? 'Nova Zona' : 'Editar Zona'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom (ex: Zona A)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Cal un nom' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cropTypeController,
                decoration: const InputDecoration(
                  labelText: 'Cultiu (ex: Olius)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: _color),
                title: const Text('Color de la Zona'),
                trailing: const Icon(Icons.edit),
                onTap: _pickColor,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL·LAR'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final newZone = FarmZone(
                id:
                    widget.zone?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                name: _nameController.text,
                cropType: _cropTypeController.text,
                colorHex: _color.value.toRadixString(16).padLeft(8, '0'),
              );
              Navigator.pop(context, newZone);
            }
          },
          child: const Text('GUARDAR'),
        ),
      ],
    );
  }
}
