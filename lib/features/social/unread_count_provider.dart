import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/features/social/social_service.dart';

final unreadCountProvider = StreamProvider<int>((ref) {
  final socialService = locator<SocialService>();
  return socialService.getUnreadCountStream();
});
