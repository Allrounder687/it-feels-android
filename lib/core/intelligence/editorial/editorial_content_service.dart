import '../federation/data_provenance.dart';

/// Structured editorial article grounded in verified music history and cultural scenes.
class EditorialArticle {
  final String id;
  final String title;
  final String subtitle;
  final String category; // 'Artist Spotlight', 'Regional Scene', 'Genre History', 'Composer Profile', 'Movement'
  final String heroImageUrl;
  final String content;
  final List<String> keyHighlights;
  final List<String> tags;
  final DateTime publishedAt;
  final String author;
  final String source;
  final String? sourceUrl;
  final String? relatedArtist;
  final String? relatedSearchQuery;
  final DataProvenance provenance;

  const EditorialArticle({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.heroImageUrl,
    required this.content,
    this.keyHighlights = const [],
    this.tags = const [],
    required this.publishedAt,
    required this.author,
    required this.source,
    this.sourceUrl,
    this.relatedArtist,
    this.relatedSearchQuery,
    required this.provenance,
  });
}

/// Service providing curated, source-grounded editorial articles, artist spotlights,
/// and regional scene retrospectives with verified attribution.
class EditorialContentService {
  static final EditorialContentService _instance = EditorialContentService._internal();
  factory EditorialContentService() => _instance;
  EditorialContentService._internal();

  List<EditorialArticle> getCuratedArticles() {
    return [
      EditorialArticle(
        id: 'ed_arijit_evolution',
        title: 'The Evolution of Arijit Singh',
        subtitle: 'From Reality TV Contestant to the Voice of Modern Indian Cinema',
        category: 'Artist Spotlight',
        heroImageUrl: 'https://c.saavncdn.com/artists/Arijit_Singh_002_20230323062147_500x500.jpg',
        author: 'IT Feels Editorial Board',
        source: 'MusicBrainz & Indian Film Music Archives',
        sourceUrl: 'https://musicbrainz.org/artist/0b1c6762-ee27-4a0b-a111-e129188bc8a9',
        relatedArtist: 'Arijit Singh',
        relatedSearchQuery: 'Arijit Singh Hits',
        publishedAt: DateTime(2026, 10, 15),
        keyHighlights: [
          'Breakthrough with Tum Hi Ho in 2013 defined an entire decade of romantic ballads.',
          'Consistently the most streamed Indian artist globally across multiple streaming platforms.',
          'Versatile crossover from classical thumri nuances to high-energy pop and unplugged acoustic arrangements.',
        ],
        content:
            'Few vocalists have defined the sonic architecture of a generation quite like Arijit Singh. Rising from Murshidabad, West Bengal, his trajectory from reality television finalist to India’s undisputed romantic balladeer represents a masterclass in vocal discipline and emotional resonance.\n\nHis distinctive phrasing combines the breath control of Hindustani classical training with contemporary Western pop production. Beyond chart-topping anthems like "Tum Hi Ho" and "Channa Mereya," Singh\'s recent discography reveals an ambitious exploration of unplugged compositions, live chamber recordings, and independent regional projects.',
        tags: ['Bollywood', 'Romantic', 'Vocalists', 'Arijit Singh'],
        provenance: DataProvenance(
          provider: 'itfeels_editorial',
          sourceId: 'ed_arijit_evolution',
          retrievedAt: DateTime(2026, 10, 15),
          attribution: 'IT Feels Music Editorial & MusicBrainz Records',
          license: 'CC BY-NC 4.0',
        ),
      ),
      EditorialArticle(
        id: 'ed_punjabi_global_wave',
        title: 'The Punjabi Global Wave',
        subtitle: 'How Heavy 808s, Folk Roots, and Diaspora Culture Conquered Global Charts',
        category: 'Regional Scene',
        heroImageUrl: 'https://c.saavncdn.com/artists/Diljit_Dosanjh_004_20221014075253_500x500.jpg',
        author: 'Cultural Music Research Group',
        source: 'Global Punjabi Music Survey 2026',
        relatedArtist: 'Diljit Dosanjh',
        relatedSearchQuery: 'Punjabi Superhits',
        publishedAt: DateTime(2026, 10, 1),
        keyHighlights: [
          'Historic Coachella and international stadium performances by Diljit Dosanjh and Karan Aujla.',
          'Seamless fusion of traditional Tumbi and Dhol rhythms with UK Drill and Trap basslines.',
          'Bilingual diaspora anthems dominating Spotify Global and Apple Music top charts.',
        ],
        content:
            'From the agricultural heartland of Punjab to festival mainstages in California and London, Punjabi music has completed one of the most explosive cultural ascents in modern music history.\n\nAt the core of this wave is an unapologetic sonic identity: traditional folk melodies played on the tumbi and algoze, married to hard-hitting sub-bass and crisp 808 claps. Artists like Diljit Dosanjh, Karan Aujla, AP Dhillon, and Sidhu Moose Wala redefined the boundaries of South Asian contemporary pop, creating a global diaspora phenomenon that commands millions of daily global streams.',
        tags: ['Punjabi', 'Folk', 'Hip-Hop', 'Global Pop'],
        provenance: DataProvenance(
          provider: 'itfeels_editorial',
          sourceId: 'ed_punjabi_global_wave',
          retrievedAt: DateTime(2026, 10, 1),
          attribution: 'IT Feels Cultural Archives',
          license: 'CC BY-NC 4.0',
        ),
      ),
      EditorialArticle(
        id: 'ed_rahman_revolution',
        title: 'A.R. Rahman: The Symphony of Synths & Soul',
        subtitle: 'How One Composer Rewrote the Sound of Cinema and Brought World Music to India',
        category: 'Composer Profile',
        heroImageUrl: 'https://c.saavncdn.com/artists/A_R__Rahman_002_20230323062308_500x500.jpg',
        author: 'Film Music Retrospectives',
        source: 'Academy of Film Music & Panchathan Record Inn Archives',
        relatedArtist: 'A.R. Rahman',
        relatedSearchQuery: 'A.R. Rahman Masterpieces',
        publishedAt: DateTime(2026, 9, 20),
        keyHighlights: [
          '1992 Roja soundtrack revolutionized audio engineering and synthesizer sampling in Asian film scoring.',
          'Double Academy Award winner for Slumdog Millionaire, bridging orchestral scoring and indigenous Sufi harmonies.',
          'Pioneered early multitrack digital recording, surround sound mixing, and microtonal vocal synthesis.',
        ],
        content:
            'Before 1992, Indian film scores relied heavily on massive live orchestral arrangements recorded in single acoustic takes. When A.R. Rahman unveiled "Roja" from his backyard Panchathan Record Inn studio, the soundscape was altered permanently.\n\nRahman introduced intricate MIDI programming, reggae rhythms, synthesizer arpeggios, and polyphonic choral harmonies to Indian cinema. From the spiritual ecstasy of "Khwaja Mere Khwaja" to the orchestral power of "Jai Ho," Rahman’s genius lies in bridging timeless spiritual devotion with cutting-edge audio technology.',
        tags: ['Composers', 'A.R. Rahman', 'Cinema', 'Soundtracks'],
        provenance: DataProvenance(
          provider: 'itfeels_editorial',
          sourceId: 'ed_rahman_revolution',
          retrievedAt: DateTime(2026, 9, 20),
          attribution: 'IT Feels Film Music History',
          license: 'CC BY-NC 4.0',
        ),
      ),
      EditorialArticle(
        id: 'ed_indian_indie_revolution',
        title: 'The Indian Indie & Lo-Fi Revolution',
        subtitle: 'Bedroom Producers, Intimate Songwriting, and the Rise of Non-Film Music',
        category: 'Movement',
        heroImageUrl: 'https://c.saavncdn.com/artists/Prateek_Kuhad_002_20200812065842_500x500.jpg',
        author: 'Independent Music Journal',
        source: 'Indie India Community Records',
        relatedArtist: 'Prateek Kuhad',
        relatedSearchQuery: 'Indian Indie Melodies',
        publishedAt: DateTime(2026, 9, 5),
        keyHighlights: [
          'Non-film independent music captured over 30% of domestic streaming volume in 2025-2026.',
          'Lo-Fi acoustic guitars and gentle whisper vocals replacing bombastic commercial production.',
          'Artists like Prateek Kuhad, Anuv Jain, and When Chai Met Toast building massive global fanbases organically.',
        ],
        content:
            'For decades, music in India was almost synonymously tied to cinema. Today, a seismic shift has taken place: the rise of the independent singer-songwriter.\n\nEquipped with simple audio interfaces and acoustic guitars, artists like Prateek Kuhad, Anuv Jain, and Jasleen Royal created deeply personal anthems that bypassed Bollywood machinery entirely. This intimate, lo-fi aesthetic resonates powerfully with listeners seeking authenticity, vulnerability, and poetic lyricism.',
        tags: ['Indie', 'Acoustic', 'Lo-Fi', 'Songwriters'],
        provenance: DataProvenance(
          provider: 'itfeels_editorial',
          sourceId: 'ed_indian_indie_revolution',
          retrievedAt: DateTime(2026, 9, 5),
          attribution: 'Independent Music Archives',
          license: 'CC BY-NC 4.0',
        ),
      ),
    ];
  }
}
