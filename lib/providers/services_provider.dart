// lib/providers/services_provider.dart

import 'package:disaster_reco/services/database_helper.dart';
import 'package:disaster_reco/services/tflite_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

final tfliteProvider = Provider<TfliteService>((ref) {
  return TfliteService();
});
