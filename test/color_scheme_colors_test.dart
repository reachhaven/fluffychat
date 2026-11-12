// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
// SPDX-FileCopyrightText: 2026 vDL Digital Ventures
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/utils/color_scheme_colors_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final seeded = ColorScheme.fromSeed(seedColor: const Color(0xFF5625BA));

  test('Named roles take the configured colors', () {
    final scheme = seeded.withColors({
      'primary': '#336699',
      'surface': '#FFFFFF',
      'outline': 0xFFD9D9D9,
      'shadow': '#00000000',
    });
    expect(scheme.primary, const Color(0xFF336699));
    expect(scheme.surface, const Color(0xFFFFFFFF));
    expect(scheme.outline, const Color(0xFFD9D9D9));
    expect(scheme.shadow, const Color(0x00000000));
    expect(scheme.secondary, seeded.secondary);
  });

  test('Unknown roles and malformed colors are ignored', () {
    final scheme = seeded.withColors({
      'accent': '#ff0000',
      'primary': 'green',
      'secondary': '#12345',
      'tertiary': null,
    });
    expect(scheme, seeded);
  });

  test('Without configured colors the seeded scheme stays', () {
    expect(seeded.withColors(const {}), seeded);
  });
}
