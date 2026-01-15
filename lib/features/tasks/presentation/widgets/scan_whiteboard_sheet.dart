import 'dart:typed_data'; // for Uint8List
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/ocr_service.dart';
import '../../domain/entities/task.dart';
import '../providers/tasks_provider.dart';

class ScanWhiteboardSheet extends ConsumerStatefulWidget {
  const ScanWhiteboardSheet({super.key});

  @override
  ConsumerState<ScanWhiteboardSheet> createState() =>
      _ScanWhiteboardSheetState();
}

class _ScanWhiteboardSheetState extends ConsumerState<ScanWhiteboardSheet> {
  final OcrService _ocrService = OcrService();
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;
  List<Task> _detectedTasks = [];
  XFile? _imageFile;
  Uint8List? _webImageBytes; // For preview on Web

  // Buckets definition
  final List<String> _knownBuckets = [
    'Valla exterior',
    'Sala d\'estar',
    'Aigua',
    'Arquitectura/Planols',
    'Documentació',
    'Reforestació',
  ];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920, // Limit resolution to FHD to avoid OOM
        maxHeight: 1920,
        imageQuality: 85, // Compress slightly
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (!mounted) return;
        setState(() {
          _imageFile = pickedFile;
          _webImageBytes = bytes;
          _isProcessing = true;
        });
        _analyzeImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seleccionant imatge: $e')),
        );
      }
    }
  }

  Future<void> _analyzeImage() async {
    try {
      if (_imageFile == null) return;

      // Ensure user is authenticated for Cloud Functions
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      final List<Task> tasks = await _ocrService.parseWhiteboardImage(
        _imageFile!,
      );

      if (mounted) {
        setState(() {
          _detectedTasks = tasks;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analitzant la imatge: $e')),
        );
      }
    }
  }

  Future<void> _saveAll() async {
    final repo = ref.read(tasksRepositoryProvider);
    int count = 0;

    // Show saving indicator?
    setState(() => _isProcessing = true);

    try {
      for (var task in _detectedTasks) {
        // Regenerate ID to ensure uniqueness in DB if needed,
        // though Repo.addTask usually uses the ID passed or generates one.
        // Our OcrService generated temp IDs.
        // Let's rely on manual iteration.
        // Actually repo.addTask uses task.id to set doc.
        // If we want new IDs we should let generic logic handle or just use these uniques.

        await repo.addTask(task);
        count++;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count tasques importades correctament! 🎉')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error guardant: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sincronització Analògica',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_imageFile == null) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.photo_camera_back,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Fer Foto a la Pissarra'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Triar de la Galeria'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Optionally show tiny preview?
            if (_webImageBytes != null)
              SizedBox(height: 100, child: Image.memory(_webImageBytes!)),

            // Results View
            if (_isProcessing)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_detectedTasks.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No s\'han detectat tasques.'),
                      TextButton(
                        onPressed: () => setState(() => _imageFile = null),
                        child: const Text('Tornar-ho a provar'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'S\'han detectat ${_detectedTasks.length} tasques:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _detectedTasks.length,
                        itemBuilder: (context, index) {
                          final task = _detectedTasks[index];
                          return Card(
                            key: ValueKey(task.id),
                            child: ListTile(
                              leading: Icon(
                                Icons.label,
                                color: _getBucketColor(task.bucket),
                              ),
                              title: TextFormField(
                                initialValue: task.title,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                                onChanged: (val) {
                                  _detectedTasks[index] = task.copyWith(
                                    title: val,
                                  );
                                },
                              ),
                              subtitle: DropdownButton<String>(
                                value: _knownBuckets.contains(task.bucket)
                                    ? task.bucket
                                    : null,
                                isDense: true,
                                underline: const SizedBox(),
                                items: _knownBuckets
                                    .map(
                                      (b) => DropdownMenuItem(
                                        value: b,
                                        child: Text(
                                          b,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _detectedTasks[index] = task.copyWith(
                                        bucket: val,
                                      );
                                    });
                                  }
                                },
                                hint: Text(
                                  task.bucket.isEmpty
                                      ? 'Sense categoria'
                                      : task.bucket,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _detectedTasks.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _saveAll,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Confirmar i Importar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _imageFile = null),
                      child: const Text('Descartar i tornar a començar'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Color _getBucketColor(String bucket) {
    // Just simple hash color for visual distinction
    return Colors.primaries[bucket.hashCode % Colors.primaries.length];
  }
}
