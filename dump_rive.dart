import 'dart:io';
import 'package:rive/rive.dart';
import 'dart:typed_data';

void main() async {
  final bytes = File('assets/rive/doggo.riv').readAsBytesSync();
  final file = RiveFile.import(ByteData.view(bytes.buffer));
  for (var artboard in file.artboards) {
    print('Artboard: ${artboard.name}');
    for (var sm in artboard.stateMachines) {
      print('  StateMachine: ${sm.name}');
      for (var input in sm.inputs) {
        print('    Input: ${input.name} (${input.runtimeType})');
      }
    }
  }
}
