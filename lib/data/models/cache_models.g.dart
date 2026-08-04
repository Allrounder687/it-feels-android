// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_models.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCachedStreamCollection on Isar {
  IsarCollection<CachedStream> get cachedStreams => this.collection();
}

const CachedStreamSchema = CollectionSchema(
  name: r'CachedStream',
  id: -969743956911924172,
  properties: {
    r'expiryTime': PropertySchema(
      id: 0,
      name: r'expiryTime',
      type: IsarType.dateTime,
    ),
    r'failureCount': PropertySchema(
      id: 1,
      name: r'failureCount',
      type: IsarType.long,
    ),
    r'isExpired': PropertySchema(
      id: 2,
      name: r'isExpired',
      type: IsarType.bool,
    ),
    r'quality': PropertySchema(
      id: 3,
      name: r'quality',
      type: IsarType.string,
    ),
    r'resolvedAt': PropertySchema(
      id: 4,
      name: r'resolvedAt',
      type: IsarType.dateTime,
    ),
    r'resolvedAudioUrl': PropertySchema(
      id: 5,
      name: r'resolvedAudioUrl',
      type: IsarType.string,
    ),
    r'resolvedVideoUrl': PropertySchema(
      id: 6,
      name: r'resolvedVideoUrl',
      type: IsarType.string,
    ),
    r'resolverVersion': PropertySchema(
      id: 7,
      name: r'resolverVersion',
      type: IsarType.long,
    ),
    r'videoId': PropertySchema(
      id: 8,
      name: r'videoId',
      type: IsarType.string,
    )
  },
  estimateSize: _cachedStreamEstimateSize,
  serialize: _cachedStreamSerialize,
  deserialize: _cachedStreamDeserialize,
  deserializeProp: _cachedStreamDeserializeProp,
  idName: r'id',
  indexes: {
    r'videoId': IndexSchema(
      id: 6273887982249211799,
      name: r'videoId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'videoId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _cachedStreamGetId,
  getLinks: _cachedStreamGetLinks,
  attach: _cachedStreamAttach,
  version: '3.1.0+1',
);

int _cachedStreamEstimateSize(
  CachedStream object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.quality.length * 3;
  bytesCount += 3 + object.resolvedAudioUrl.length * 3;
  bytesCount += 3 + object.resolvedVideoUrl.length * 3;
  bytesCount += 3 + object.videoId.length * 3;
  return bytesCount;
}

void _cachedStreamSerialize(
  CachedStream object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.expiryTime);
  writer.writeLong(offsets[1], object.failureCount);
  writer.writeBool(offsets[2], object.isExpired);
  writer.writeString(offsets[3], object.quality);
  writer.writeDateTime(offsets[4], object.resolvedAt);
  writer.writeString(offsets[5], object.resolvedAudioUrl);
  writer.writeString(offsets[6], object.resolvedVideoUrl);
  writer.writeLong(offsets[7], object.resolverVersion);
  writer.writeString(offsets[8], object.videoId);
}

CachedStream _cachedStreamDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CachedStream();
  object.expiryTime = reader.readDateTime(offsets[0]);
  object.failureCount = reader.readLong(offsets[1]);
  object.id = id;
  object.quality = reader.readString(offsets[3]);
  object.resolvedAt = reader.readDateTime(offsets[4]);
  object.resolvedAudioUrl = reader.readString(offsets[5]);
  object.resolvedVideoUrl = reader.readString(offsets[6]);
  object.resolverVersion = reader.readLong(offsets[7]);
  object.videoId = reader.readString(offsets[8]);
  return object;
}

P _cachedStreamDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _cachedStreamGetId(CachedStream object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _cachedStreamGetLinks(CachedStream object) {
  return [];
}

void _cachedStreamAttach(
    IsarCollection<dynamic> col, Id id, CachedStream object) {
  object.id = id;
}

extension CachedStreamByIndex on IsarCollection<CachedStream> {
  Future<CachedStream?> getByVideoId(String videoId) {
    return getByIndex(r'videoId', [videoId]);
  }

  CachedStream? getByVideoIdSync(String videoId) {
    return getByIndexSync(r'videoId', [videoId]);
  }

  Future<bool> deleteByVideoId(String videoId) {
    return deleteByIndex(r'videoId', [videoId]);
  }

  bool deleteByVideoIdSync(String videoId) {
    return deleteByIndexSync(r'videoId', [videoId]);
  }

  Future<List<CachedStream?>> getAllByVideoId(List<String> videoIdValues) {
    final values = videoIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'videoId', values);
  }

  List<CachedStream?> getAllByVideoIdSync(List<String> videoIdValues) {
    final values = videoIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'videoId', values);
  }

  Future<int> deleteAllByVideoId(List<String> videoIdValues) {
    final values = videoIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'videoId', values);
  }

  int deleteAllByVideoIdSync(List<String> videoIdValues) {
    final values = videoIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'videoId', values);
  }

  Future<Id> putByVideoId(CachedStream object) {
    return putByIndex(r'videoId', object);
  }

  Id putByVideoIdSync(CachedStream object, {bool saveLinks = true}) {
    return putByIndexSync(r'videoId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByVideoId(List<CachedStream> objects) {
    return putAllByIndex(r'videoId', objects);
  }

  List<Id> putAllByVideoIdSync(List<CachedStream> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'videoId', objects, saveLinks: saveLinks);
  }
}

extension CachedStreamQueryWhereSort
    on QueryBuilder<CachedStream, CachedStream, QWhere> {
  QueryBuilder<CachedStream, CachedStream, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension CachedStreamQueryWhere
    on QueryBuilder<CachedStream, CachedStream, QWhereClause> {
  QueryBuilder<CachedStream, CachedStream, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterWhereClause> videoIdEqualTo(
      String videoId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'videoId',
        value: [videoId],
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterWhereClause> videoIdNotEqualTo(
      String videoId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'videoId',
              lower: [],
              upper: [videoId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'videoId',
              lower: [videoId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'videoId',
              lower: [videoId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'videoId',
              lower: [],
              upper: [videoId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension CachedStreamQueryFilter
    on QueryBuilder<CachedStream, CachedStream, QFilterCondition> {
  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      expiryTimeEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expiryTime',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      expiryTimeGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'expiryTime',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      expiryTimeLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'expiryTime',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      expiryTimeBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'expiryTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      failureCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'failureCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      failureCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'failureCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      failureCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'failureCount',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      failureCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'failureCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      isExpiredEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isExpired',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      qualityEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'quality',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      qualityGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'quality',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      qualityLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'quality',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      qualityBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'quality',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      qualityStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'quality',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      qualityEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'quality',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      qualityContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'quality',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      qualityMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'quality',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      qualityIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'quality',
        value: '',
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      qualityIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'quality',
        value: '',
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolvedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolvedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolvedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAudioUrlEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedAudioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAudioUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolvedAudioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAudioUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolvedAudioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAudioUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolvedAudioUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAudioUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resolvedAudioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAudioUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resolvedAudioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAudioUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolvedAudioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAudioUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolvedAudioUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAudioUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedAudioUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedAudioUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolvedAudioUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedVideoUrlEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedVideoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedVideoUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolvedVideoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedVideoUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolvedVideoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedVideoUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolvedVideoUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedVideoUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resolvedVideoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedVideoUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resolvedVideoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedVideoUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolvedVideoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedVideoUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolvedVideoUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedVideoUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolvedVideoUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolvedVideoUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolvedVideoUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolverVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolverVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolverVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolverVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolverVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolverVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      resolverVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolverVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      videoIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'videoId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      videoIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'videoId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      videoIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'videoId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      videoIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'videoId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      videoIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'videoId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      videoIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'videoId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      videoIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'videoId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      videoIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'videoId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      videoIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'videoId',
        value: '',
      ));
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterFilterCondition>
      videoIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'videoId',
        value: '',
      ));
    });
  }
}

extension CachedStreamQueryObject
    on QueryBuilder<CachedStream, CachedStream, QFilterCondition> {}

extension CachedStreamQueryLinks
    on QueryBuilder<CachedStream, CachedStream, QFilterCondition> {}

extension CachedStreamQuerySortBy
    on QueryBuilder<CachedStream, CachedStream, QSortBy> {
  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> sortByExpiryTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiryTime', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      sortByExpiryTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiryTime', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> sortByFailureCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureCount', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      sortByFailureCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureCount', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> sortByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> sortByIsExpiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> sortByQuality() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quality', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> sortByQualityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quality', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> sortByResolvedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      sortByResolvedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      sortByResolvedAudioUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAudioUrl', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      sortByResolvedAudioUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAudioUrl', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      sortByResolvedVideoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedVideoUrl', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      sortByResolvedVideoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedVideoUrl', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      sortByResolverVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolverVersion', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      sortByResolverVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolverVersion', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> sortByVideoId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'videoId', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> sortByVideoIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'videoId', Sort.desc);
    });
  }
}

extension CachedStreamQuerySortThenBy
    on QueryBuilder<CachedStream, CachedStream, QSortThenBy> {
  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> thenByExpiryTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiryTime', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      thenByExpiryTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiryTime', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> thenByFailureCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureCount', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      thenByFailureCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureCount', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> thenByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> thenByIsExpiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> thenByQuality() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quality', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> thenByQualityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quality', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> thenByResolvedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      thenByResolvedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      thenByResolvedAudioUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAudioUrl', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      thenByResolvedAudioUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAudioUrl', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      thenByResolvedVideoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedVideoUrl', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      thenByResolvedVideoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedVideoUrl', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      thenByResolverVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolverVersion', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy>
      thenByResolverVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolverVersion', Sort.desc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> thenByVideoId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'videoId', Sort.asc);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QAfterSortBy> thenByVideoIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'videoId', Sort.desc);
    });
  }
}

extension CachedStreamQueryWhereDistinct
    on QueryBuilder<CachedStream, CachedStream, QDistinct> {
  QueryBuilder<CachedStream, CachedStream, QDistinct> distinctByExpiryTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expiryTime');
    });
  }

  QueryBuilder<CachedStream, CachedStream, QDistinct> distinctByFailureCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'failureCount');
    });
  }

  QueryBuilder<CachedStream, CachedStream, QDistinct> distinctByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isExpired');
    });
  }

  QueryBuilder<CachedStream, CachedStream, QDistinct> distinctByQuality(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'quality', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QDistinct> distinctByResolvedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedAt');
    });
  }

  QueryBuilder<CachedStream, CachedStream, QDistinct>
      distinctByResolvedAudioUrl({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedAudioUrl',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QDistinct>
      distinctByResolvedVideoUrl({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedVideoUrl',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CachedStream, CachedStream, QDistinct>
      distinctByResolverVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolverVersion');
    });
  }

  QueryBuilder<CachedStream, CachedStream, QDistinct> distinctByVideoId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'videoId', caseSensitive: caseSensitive);
    });
  }
}

extension CachedStreamQueryProperty
    on QueryBuilder<CachedStream, CachedStream, QQueryProperty> {
  QueryBuilder<CachedStream, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CachedStream, DateTime, QQueryOperations> expiryTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expiryTime');
    });
  }

  QueryBuilder<CachedStream, int, QQueryOperations> failureCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'failureCount');
    });
  }

  QueryBuilder<CachedStream, bool, QQueryOperations> isExpiredProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isExpired');
    });
  }

  QueryBuilder<CachedStream, String, QQueryOperations> qualityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'quality');
    });
  }

  QueryBuilder<CachedStream, DateTime, QQueryOperations> resolvedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedAt');
    });
  }

  QueryBuilder<CachedStream, String, QQueryOperations>
      resolvedAudioUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedAudioUrl');
    });
  }

  QueryBuilder<CachedStream, String, QQueryOperations>
      resolvedVideoUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedVideoUrl');
    });
  }

  QueryBuilder<CachedStream, int, QQueryOperations> resolverVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolverVersion');
    });
  }

  QueryBuilder<CachedStream, String, QQueryOperations> videoIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'videoId');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCachedPaletteCollection on Isar {
  IsarCollection<CachedPalette> get cachedPalettes => this.collection();
}

const CachedPaletteSchema = CollectionSchema(
  name: r'CachedPalette',
  id: 1882290522081020808,
  properties: {
    r'accentColorValue': PropertySchema(
      id: 0,
      name: r'accentColorValue',
      type: IsarType.long,
    ),
    r'artworkUrl': PropertySchema(
      id: 1,
      name: r'artworkUrl',
      type: IsarType.string,
    ),
    r'backgroundColorValue': PropertySchema(
      id: 2,
      name: r'backgroundColorValue',
      type: IsarType.long,
    ),
    r'cachedAt': PropertySchema(
      id: 3,
      name: r'cachedAt',
      type: IsarType.dateTime,
    ),
    r'surfaceColorValue': PropertySchema(
      id: 4,
      name: r'surfaceColorValue',
      type: IsarType.long,
    )
  },
  estimateSize: _cachedPaletteEstimateSize,
  serialize: _cachedPaletteSerialize,
  deserialize: _cachedPaletteDeserialize,
  deserializeProp: _cachedPaletteDeserializeProp,
  idName: r'id',
  indexes: {
    r'artworkUrl': IndexSchema(
      id: -4569562292177228156,
      name: r'artworkUrl',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'artworkUrl',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _cachedPaletteGetId,
  getLinks: _cachedPaletteGetLinks,
  attach: _cachedPaletteAttach,
  version: '3.1.0+1',
);

int _cachedPaletteEstimateSize(
  CachedPalette object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.artworkUrl.length * 3;
  return bytesCount;
}

void _cachedPaletteSerialize(
  CachedPalette object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.accentColorValue);
  writer.writeString(offsets[1], object.artworkUrl);
  writer.writeLong(offsets[2], object.backgroundColorValue);
  writer.writeDateTime(offsets[3], object.cachedAt);
  writer.writeLong(offsets[4], object.surfaceColorValue);
}

CachedPalette _cachedPaletteDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CachedPalette();
  object.accentColorValue = reader.readLong(offsets[0]);
  object.artworkUrl = reader.readString(offsets[1]);
  object.backgroundColorValue = reader.readLong(offsets[2]);
  object.cachedAt = reader.readDateTime(offsets[3]);
  object.id = id;
  object.surfaceColorValue = reader.readLong(offsets[4]);
  return object;
}

P _cachedPaletteDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _cachedPaletteGetId(CachedPalette object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _cachedPaletteGetLinks(CachedPalette object) {
  return [];
}

void _cachedPaletteAttach(
    IsarCollection<dynamic> col, Id id, CachedPalette object) {
  object.id = id;
}

extension CachedPaletteByIndex on IsarCollection<CachedPalette> {
  Future<CachedPalette?> getByArtworkUrl(String artworkUrl) {
    return getByIndex(r'artworkUrl', [artworkUrl]);
  }

  CachedPalette? getByArtworkUrlSync(String artworkUrl) {
    return getByIndexSync(r'artworkUrl', [artworkUrl]);
  }

  Future<bool> deleteByArtworkUrl(String artworkUrl) {
    return deleteByIndex(r'artworkUrl', [artworkUrl]);
  }

  bool deleteByArtworkUrlSync(String artworkUrl) {
    return deleteByIndexSync(r'artworkUrl', [artworkUrl]);
  }

  Future<List<CachedPalette?>> getAllByArtworkUrl(
      List<String> artworkUrlValues) {
    final values = artworkUrlValues.map((e) => [e]).toList();
    return getAllByIndex(r'artworkUrl', values);
  }

  List<CachedPalette?> getAllByArtworkUrlSync(List<String> artworkUrlValues) {
    final values = artworkUrlValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'artworkUrl', values);
  }

  Future<int> deleteAllByArtworkUrl(List<String> artworkUrlValues) {
    final values = artworkUrlValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'artworkUrl', values);
  }

  int deleteAllByArtworkUrlSync(List<String> artworkUrlValues) {
    final values = artworkUrlValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'artworkUrl', values);
  }

  Future<Id> putByArtworkUrl(CachedPalette object) {
    return putByIndex(r'artworkUrl', object);
  }

  Id putByArtworkUrlSync(CachedPalette object, {bool saveLinks = true}) {
    return putByIndexSync(r'artworkUrl', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByArtworkUrl(List<CachedPalette> objects) {
    return putAllByIndex(r'artworkUrl', objects);
  }

  List<Id> putAllByArtworkUrlSync(List<CachedPalette> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'artworkUrl', objects, saveLinks: saveLinks);
  }
}

extension CachedPaletteQueryWhereSort
    on QueryBuilder<CachedPalette, CachedPalette, QWhere> {
  QueryBuilder<CachedPalette, CachedPalette, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension CachedPaletteQueryWhere
    on QueryBuilder<CachedPalette, CachedPalette, QWhereClause> {
  QueryBuilder<CachedPalette, CachedPalette, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterWhereClause>
      artworkUrlEqualTo(String artworkUrl) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'artworkUrl',
        value: [artworkUrl],
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterWhereClause>
      artworkUrlNotEqualTo(String artworkUrl) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'artworkUrl',
              lower: [],
              upper: [artworkUrl],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'artworkUrl',
              lower: [artworkUrl],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'artworkUrl',
              lower: [artworkUrl],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'artworkUrl',
              lower: [],
              upper: [artworkUrl],
              includeUpper: false,
            ));
      }
    });
  }
}

extension CachedPaletteQueryFilter
    on QueryBuilder<CachedPalette, CachedPalette, QFilterCondition> {
  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      accentColorValueEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accentColorValue',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      accentColorValueGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'accentColorValue',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      accentColorValueLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'accentColorValue',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      accentColorValueBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'accentColorValue',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      artworkUrlEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'artworkUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      artworkUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'artworkUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      artworkUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'artworkUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      artworkUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'artworkUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      artworkUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'artworkUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      artworkUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'artworkUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      artworkUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'artworkUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      artworkUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'artworkUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      artworkUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'artworkUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      artworkUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'artworkUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      backgroundColorValueEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'backgroundColorValue',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      backgroundColorValueGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'backgroundColorValue',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      backgroundColorValueLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'backgroundColorValue',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      backgroundColorValueBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'backgroundColorValue',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      cachedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      cachedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      cachedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      cachedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cachedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      surfaceColorValueEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'surfaceColorValue',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      surfaceColorValueGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'surfaceColorValue',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      surfaceColorValueLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'surfaceColorValue',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterFilterCondition>
      surfaceColorValueBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'surfaceColorValue',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension CachedPaletteQueryObject
    on QueryBuilder<CachedPalette, CachedPalette, QFilterCondition> {}

extension CachedPaletteQueryLinks
    on QueryBuilder<CachedPalette, CachedPalette, QFilterCondition> {}

extension CachedPaletteQuerySortBy
    on QueryBuilder<CachedPalette, CachedPalette, QSortBy> {
  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      sortByAccentColorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accentColorValue', Sort.asc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      sortByAccentColorValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accentColorValue', Sort.desc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy> sortByArtworkUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artworkUrl', Sort.asc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      sortByArtworkUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artworkUrl', Sort.desc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      sortByBackgroundColorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backgroundColorValue', Sort.asc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      sortByBackgroundColorValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backgroundColorValue', Sort.desc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy> sortByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      sortByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      sortBySurfaceColorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'surfaceColorValue', Sort.asc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      sortBySurfaceColorValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'surfaceColorValue', Sort.desc);
    });
  }
}

extension CachedPaletteQuerySortThenBy
    on QueryBuilder<CachedPalette, CachedPalette, QSortThenBy> {
  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      thenByAccentColorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accentColorValue', Sort.asc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      thenByAccentColorValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accentColorValue', Sort.desc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy> thenByArtworkUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artworkUrl', Sort.asc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      thenByArtworkUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artworkUrl', Sort.desc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      thenByBackgroundColorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backgroundColorValue', Sort.asc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      thenByBackgroundColorValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backgroundColorValue', Sort.desc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy> thenByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      thenByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      thenBySurfaceColorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'surfaceColorValue', Sort.asc);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QAfterSortBy>
      thenBySurfaceColorValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'surfaceColorValue', Sort.desc);
    });
  }
}

extension CachedPaletteQueryWhereDistinct
    on QueryBuilder<CachedPalette, CachedPalette, QDistinct> {
  QueryBuilder<CachedPalette, CachedPalette, QDistinct>
      distinctByAccentColorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accentColorValue');
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QDistinct> distinctByArtworkUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'artworkUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QDistinct>
      distinctByBackgroundColorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'backgroundColorValue');
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QDistinct> distinctByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cachedAt');
    });
  }

  QueryBuilder<CachedPalette, CachedPalette, QDistinct>
      distinctBySurfaceColorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'surfaceColorValue');
    });
  }
}

extension CachedPaletteQueryProperty
    on QueryBuilder<CachedPalette, CachedPalette, QQueryProperty> {
  QueryBuilder<CachedPalette, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CachedPalette, int, QQueryOperations>
      accentColorValueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accentColorValue');
    });
  }

  QueryBuilder<CachedPalette, String, QQueryOperations> artworkUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'artworkUrl');
    });
  }

  QueryBuilder<CachedPalette, int, QQueryOperations>
      backgroundColorValueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'backgroundColorValue');
    });
  }

  QueryBuilder<CachedPalette, DateTime, QQueryOperations> cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }

  QueryBuilder<CachedPalette, int, QQueryOperations>
      surfaceColorValueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'surfaceColorValue');
    });
  }
}
