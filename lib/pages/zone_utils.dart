import 'package:flutter/material.dart';

/// Color degradado según la puntuación de una zona.
/// Se usa tanto en el mapa como en el ranking para que ambos
/// se vean siempre consistentes entre sí.
/// 0 = muy sucia (rojo) ... 500+ = muy limpia (verde)
Color getZoneColor(int score) {
  final stops = <double, Color>{
    0.0: const Color(0xFFD32F2F), // rojo
    0.25: const Color(0xFFF57C00), // naranja
    0.5: const Color(0xFFFBC02D), // amarillo
    0.75: const Color(0xFF8BC34A), // verde claro
    1.0: const Color(0xFF2E7D32), // verde
  };

  final ratio = (score / 500).clamp(0.0, 1.0);
  final keys = stops.keys.toList()..sort();

  for (var i = 0; i < keys.length - 1; i++) {
    final a = keys[i];
    final b = keys[i + 1];
    if (ratio >= a && ratio <= b) {
      final t = (ratio - a) / (b - a);
      return Color.lerp(stops[a], stops[b], t)!;
    }
  }
  return stops[1.0]!;
}

/// Etiqueta legible del estado de una zona, según su puntuación.
String getZoneLabel(int score) {
  final ratio = (score / 500).clamp(0.0, 1.0);
  if (ratio < 0.2) return "Muy sucia";
  if (ratio < 0.45) return "Sucia";
  if (ratio < 0.6) return "Regular";
  if (ratio < 0.85) return "Limpia";
  return "Muy limpia";
}
