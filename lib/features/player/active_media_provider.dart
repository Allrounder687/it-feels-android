import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ActiveMediaType { none, audio, video }

class ActiveMediaNotifier extends Notifier<ActiveMediaType> {
  @override
  ActiveMediaType build() {
    return ActiveMediaType.none;
  }

  void setActiveMedia(ActiveMediaType type) {
    if (state != type) {
      state = type;
    }
  }
}

final activeMediaProvider = NotifierProvider<ActiveMediaNotifier, ActiveMediaType>(() {
  return ActiveMediaNotifier();
});
