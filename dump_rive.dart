import 'dart:io';
import 'package:rive/rive.dart';

void main() async {
  await RiveFile.initialize();
  final file = RiveFile.import(File('assets/rive/doggo.riv').readAsBytesSync());
  for (var artboard in file.artboards) {
    print('Artboard: \');
    for (var sm in artboard.stateMachines) {
      print('  StateMachine: \');
      for (var input in sm.inputs) {
        print('    Input: \ (\)');
      }
    }
  }
}
