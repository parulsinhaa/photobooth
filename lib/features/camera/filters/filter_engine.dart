// lib/features/camera/filters/filter_engine.dart
import 'package:flutter/material.dart';
import 'filter_definitions.dart';

class FilterEngine {
  FilterEngine._();

  /// Apply real-time filter to any widget (camera preview or image)
  static Widget applyFilter({
    required Widget child,
    required FilterPreset filter,
    double intensity = 1.0,
  }) {
    if (filter == FilterPreset.none || filter.matrix == null) return child;

    final matrix = _interpolateMatrix(
      _identityMatrix,
      filter.matrix!,
      intensity.clamp(0.0, 1.0),
    );

    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: child,
    );
  }

  /// Apply filter to image bytes
  static ColorFilter getColorFilter(FilterPreset filter, {double intensity = 1.0}) {
    if (filter == FilterPreset.none || filter.matrix == null) {
      return const ColorFilter.matrix(_identityMatrix);
    }
    return ColorFilter.matrix(
      _interpolateMatrix(_identityMatrix, filter.matrix!, intensity),
    );
  }

  /// Blend two matrices based on intensity (0 = identity, 1 = full filter)
  static List<double> _interpolateMatrix(
    List<double> identity,
    List<double> target,
    double t,
  ) {
    return List.generate(
      20,
      (i) => identity[i] + (target[i] - identity[i]) * t,
    );
  }

  static const List<double> _identityMatrix = [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Represents a filter configuration
class FilterPreset {
  final String id;
  final String name;
  final String category;
  final List<double>? matrix;
  final bool isPremium;
  final Color previewColor;

  const FilterPreset({
    required this.id,
    required this.name,
    required this.category,
    this.matrix,
    this.isPremium = false,
    this.previewColor = Colors.transparent,
  });

  static const FilterPreset none = FilterPreset(
    id: 'none',
    name: 'Normal',
    category: 'basic',
    matrix: null,
    previewColor: Colors.grey,
  );
}
