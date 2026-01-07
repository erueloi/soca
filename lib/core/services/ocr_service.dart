import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart'; // for debugPrint
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import '../../features/tasks/domain/entities/task.dart';

class OcrService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads image to temp storage and calls Cloud Function to parse it.
  Future<List<Task>> parseWhiteboardImage(dynamic imageFile) async {
    // imageFile can be XFile (from picker) or File (legacy/testing).
    // We prefer XFile or just logic to get bytes.

    try {
      Uint8List imageBytes;
      String fileName;

      if (imageFile is File) {
        imageBytes = await imageFile.readAsBytes();
        fileName = imageFile.path.split('/').last;
      } else {
        // Assume XFile or compatible with readAsBytes
        imageBytes = await imageFile.readAsBytes();
        fileName = imageFile.name;
      }

      // 1. Upload Image to Temp Storage using putData (works on Web)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'temp_ocr/${timestamp}_$fileName';
      final ref = _storage.ref().child(storagePath);

      debugPrint('OCR start: Uploading to $storagePath...');
      await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      debugPrint('OCR: Upload complete.');

      // 2. Call Cloud Function
      debugPrint('OCR: Calling cloud function processWhiteboardImage...');
      final callable = _functions.httpsCallable('processWhiteboardImage');
      final result = await callable.call(<String, dynamic>{
        'imagePath': storagePath,
      });
      debugPrint('OCR: Function returned.');

      // 3. Parse Result
      final data = result.data as Map<dynamic, dynamic>;
      debugPrint('OCR: Data received: $data');
      final tasksList = data['tasks'] as List<dynamic>;

      return tasksList.map((item) {
        return Task(
          id:
              DateTime.now().millisecondsSinceEpoch.toString() +
              (item['title'].hashCode).toString(),
          title: item['title'] ?? 'Sense títol',
          bucket: item['bucket'] ?? 'General',
          description: 'Importada via Cloud Vision OCR',
          phase: '',
          isDone: item['isDone'] ?? false,
          items: [],
          contactIds: [],
          photoUrls: [],
        );
      }).toList();
    } catch (e) {
      debugPrint('Error in OCR Service: $e');
      rethrow;
    }
  }
}
