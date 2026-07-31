class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String imagePath;
  final String colorHex;

  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imagePath,
    required this.colorHex,
  });

  static const List<BadgeModel> allBadges = [
    BadgeModel(
      id: 'pioneer',
      name: 'The Pioneer',
      description: 'Awarded for being an early beta tester and shaping the future of IT-Feels.',
      imagePath: 'assets/badges/pioneer.jpg',
      colorHex: '#00FFCC',
    ),
    BadgeModel(
      id: 'platinum_ear',
      name: 'Platinum Ear',
      description: 'Awarded for listening to over 100 hours of high-fidelity music.',
      imagePath: 'assets/badges/platinum_ear.jpg',
      colorHex: '#E5E4E2',
    ),
    BadgeModel(
      id: 'dj',
      name: 'The DJ',
      description: 'Awarded to top users who host incredibly active Listening Parties.',
      imagePath: 'assets/badges/dj.jpg',
      colorHex: '#9D00FF',
    ),
    BadgeModel(
      id: 'supporter',
      name: 'Premium Supporter',
      description: 'A glowing badge of honor for our Premium users.',
      imagePath: 'assets/badges/supporter.jpg',
      colorHex: '#FFD700',
    ),
  ];

  static BadgeModel? getById(String id) {
    try {
      return allBadges.firstWhere((badge) => badge.id == id);
    } catch (e) {
      return null;
    }
  }
}
