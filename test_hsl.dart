import 'package:flutter/material.dart';

void main() {
  final hsl = HSLColor.fromColor(Colors.white);
  final adj = hsl.withLightness(0.12).toColor();
  print(adj);
}
