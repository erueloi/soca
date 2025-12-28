import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';

class AIAnalysisResult {
  final String health;
  final String vigor;
  final String advice;

  AIAnalysisResult({
    required this.health,
    required this.vigor,
    required this.advice,
  });
}

class AIService {
  Future<AIAnalysisResult> analyzeTree({
    required String photoUrl,
    required String species,
    required String format,
    required String locationContext,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('analyzeTree');
      final result = await callable.call({
        'imagePath': photoUrl, // Function handles parsing the URL
        'species': species,
        'format': format,
        'location': locationContext,
      });

      final data = Map<String, dynamic>.from(result.data);

      return AIAnalysisResult(
        health: data['health'] ?? 'Desconegut',
        vigor: data['vigor'] ?? 'Desconegut',
        advice: data['advice'] ?? 'Sense consells.',
      );
    } catch (e) {
      print('Cloud Function Error: $e');
      throw Exception('Error connectant amb IA: $e');
    }
  }

  Future<Map<String, dynamic>> identifyTree(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final callable = FirebaseFunctions.instance.httpsCallable(
        'identifyTree',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
      );
      final result = await callable.call({
        'image': base64Image,
        'mimeType': 'image/jpeg',
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('Cloud Function (identify) Error: $e');
      throw Exception('Error identificant arbre: $e');
    }
  }
}

final aiServiceProvider = Provider((ref) => AIService());
