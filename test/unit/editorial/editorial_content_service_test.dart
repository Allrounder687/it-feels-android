import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/core/intelligence/editorial/editorial_content_service.dart';

void main() {
  group('Editorial Content & Cultural Discovery Tests', () {
    final service = EditorialContentService();

    test('Provides verified editorial articles across distinct cultural categories', () {
      final articles = service.getCuratedArticles();
      expect(articles.length, greaterThanOrEqualTo(4));

      final categories = articles.map((a) => a.category).toSet();
      expect(categories, contains('Artist Spotlight'));
      expect(categories, contains('Regional Scene'));
      expect(categories, contains('Composer Profile'));
      expect(categories, contains('Movement'));
    });

    test('Every editorial article retains strict provenance and licensing attribution', () {
      final articles = service.getCuratedArticles();

      for (final article in articles) {
        expect(article.title.isNotEmpty, isTrue);
        expect(article.subtitle.isNotEmpty, isTrue);
        expect(article.heroImageUrl.isNotEmpty, isTrue);
        expect(article.content.isNotEmpty, isTrue);
        expect(article.author.isNotEmpty, isTrue);
        expect(article.source.isNotEmpty, isTrue);
        expect(article.provenance.attribution.isNotEmpty, isTrue);
        expect(article.provenance.license.isNotEmpty, isTrue);
      }
    });

    test('Articles contain key insights and related playable queries', () {
      final articles = service.getCuratedArticles();
      final spotlight = articles.firstWhere((a) => a.category == 'Artist Spotlight');

      expect(spotlight.keyHighlights.isNotEmpty, isTrue);
      expect(spotlight.relatedArtist, equals('Arijit Singh'));
      expect(spotlight.relatedSearchQuery, isNotNull);
    });
  });
}
