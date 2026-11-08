import 'data_provenance.dart';

/// Structured credit or contributor associated with a track, album, or work.
class CanonicalContributor {
  final String id;
  final String name;
  final String role; // e.g. 'Composer', 'Lyricist', 'Music Director', 'Producer', 'Arranger', 'Featured Artist', 'Mixing Engineer'
  final String? instrument;
  final DataProvenance? provenance;

  const CanonicalContributor({
    required this.id,
    required this.name,
    required this.role,
    this.instrument,
    this.provenance,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    if (instrument != null) 'instrument': instrument,
    if (provenance != null) 'provenance': provenance!.toJson(),
  };

  factory CanonicalContributor.fromJson(Map<String, dynamic> json) {
    return CanonicalContributor(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Contributor',
      instrument: json['instrument']?.toString(),
      provenance: json['provenance'] is Map<String, dynamic>
          ? DataProvenance.fromJson(json['provenance'] as Map<String, dynamic>)
          : null,
    );
  }
}
