// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';

extension ColorSchemeColorsExtension on ColorScheme {
  /// Replaces the color roles named in [colors]. A color is `#rrggbb`,
  /// `#aarrggbb` or an ARGB integer. Unknown roles and values are ignored.
  ColorScheme withColors(Map<String, Object?> colors) {
    var scheme = this;
    for (final MapEntry(:key, :value) in colors.entries) {
      final color = _parseColor(value);
      if (color == null) continue;
      scheme = switch (key) {
        'primary' => scheme.copyWith(primary: color),
        'onPrimary' => scheme.copyWith(onPrimary: color),
        'primaryContainer' => scheme.copyWith(primaryContainer: color),
        'onPrimaryContainer' => scheme.copyWith(onPrimaryContainer: color),
        'primaryFixed' => scheme.copyWith(primaryFixed: color),
        'primaryFixedDim' => scheme.copyWith(primaryFixedDim: color),
        'onPrimaryFixed' => scheme.copyWith(onPrimaryFixed: color),
        'onPrimaryFixedVariant' => scheme.copyWith(
          onPrimaryFixedVariant: color,
        ),
        'secondary' => scheme.copyWith(secondary: color),
        'onSecondary' => scheme.copyWith(onSecondary: color),
        'secondaryContainer' => scheme.copyWith(secondaryContainer: color),
        'onSecondaryContainer' => scheme.copyWith(onSecondaryContainer: color),
        'secondaryFixed' => scheme.copyWith(secondaryFixed: color),
        'secondaryFixedDim' => scheme.copyWith(secondaryFixedDim: color),
        'onSecondaryFixed' => scheme.copyWith(onSecondaryFixed: color),
        'onSecondaryFixedVariant' => scheme.copyWith(
          onSecondaryFixedVariant: color,
        ),
        'tertiary' => scheme.copyWith(tertiary: color),
        'onTertiary' => scheme.copyWith(onTertiary: color),
        'tertiaryContainer' => scheme.copyWith(tertiaryContainer: color),
        'onTertiaryContainer' => scheme.copyWith(onTertiaryContainer: color),
        'tertiaryFixed' => scheme.copyWith(tertiaryFixed: color),
        'tertiaryFixedDim' => scheme.copyWith(tertiaryFixedDim: color),
        'onTertiaryFixed' => scheme.copyWith(onTertiaryFixed: color),
        'onTertiaryFixedVariant' => scheme.copyWith(
          onTertiaryFixedVariant: color,
        ),
        'error' => scheme.copyWith(error: color),
        'onError' => scheme.copyWith(onError: color),
        'errorContainer' => scheme.copyWith(errorContainer: color),
        'onErrorContainer' => scheme.copyWith(onErrorContainer: color),
        'surface' => scheme.copyWith(surface: color),
        'onSurface' => scheme.copyWith(onSurface: color),
        'surfaceDim' => scheme.copyWith(surfaceDim: color),
        'surfaceBright' => scheme.copyWith(surfaceBright: color),
        'surfaceContainerLowest' => scheme.copyWith(
          surfaceContainerLowest: color,
        ),
        'surfaceContainerLow' => scheme.copyWith(surfaceContainerLow: color),
        'surfaceContainer' => scheme.copyWith(surfaceContainer: color),
        'surfaceContainerHigh' => scheme.copyWith(surfaceContainerHigh: color),
        'surfaceContainerHighest' => scheme.copyWith(
          surfaceContainerHighest: color,
        ),
        'onSurfaceVariant' => scheme.copyWith(onSurfaceVariant: color),
        'outline' => scheme.copyWith(outline: color),
        'outlineVariant' => scheme.copyWith(outlineVariant: color),
        'shadow' => scheme.copyWith(shadow: color),
        'scrim' => scheme.copyWith(scrim: color),
        'inverseSurface' => scheme.copyWith(inverseSurface: color),
        'onInverseSurface' => scheme.copyWith(onInverseSurface: color),
        'inversePrimary' => scheme.copyWith(inversePrimary: color),
        'surfaceTint' => scheme.copyWith(surfaceTint: color),
        _ => scheme,
      };
    }
    return scheme;
  }
}

Color? _parseColor(Object? value) {
  if (value is int) return Color(value);
  if (value is! String || !value.startsWith('#')) return null;
  final hex = value.substring(1);
  final argb = int.tryParse(hex, radix: 16);
  if (argb == null) return null;
  return switch (hex.length) {
    6 => Color(0xFF000000 | argb),
    8 => Color(argb),
    _ => null,
  };
}
