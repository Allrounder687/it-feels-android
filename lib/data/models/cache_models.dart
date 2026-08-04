import 'package:isar/isar.dart';

part 'cache_models.g.dart';

@collection
class CachedStream {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String videoId;

  late String resolvedVideoUrl;
  
  late String resolvedAudioUrl;
  
  late String quality;
  
  late DateTime expiryTime;
  
  late DateTime resolvedAt;
  
  late int resolverVersion; // e.g. 1
  
  late int failureCount; // Track retry counts

  bool get isExpired => DateTime.now().isAfter(expiryTime);
}

@collection
class CachedPalette {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String artworkUrl;

  late int backgroundColorValue;
  late int surfaceColorValue;
  late int accentColorValue;

  late DateTime cachedAt;
}
