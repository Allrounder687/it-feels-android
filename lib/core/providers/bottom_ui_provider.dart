import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomUiNotifier extends Notifier<double> {
  @override
  double build() => 0.0;

  void updateHeight(double height) {
    // Only update if there is a meaningful difference to prevent infinite rebuilds
    if ((state - height).abs() > 1.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        state = height;
      });
    }
  }
}

final bottomUiProvider = NotifierProvider<BottomUiNotifier, double>(() {
  return BottomUiNotifier();
});

typedef OnWidgetSizeChange = void Function(Size size);

class MeasureSizeRenderObject extends RenderProxyBox {
  Size? oldSize;
  OnWidgetSizeChange onChange;

  MeasureSizeRenderObject(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    Size newSize = child!.size;
    if (oldSize == newSize) return;
    oldSize = newSize;
    onChange(newSize);
  }
}

class MeasureSize extends SingleChildRenderObjectWidget {
  final OnWidgetSizeChange onChange;

  const MeasureSize({
    super.key,
    required this.onChange,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(BuildContext context, covariant MeasureSizeRenderObject renderObject) {
    renderObject.onChange = onChange;
  }
}

final sidebarPinnedProvider = StateProvider<bool>((ref) => false);
