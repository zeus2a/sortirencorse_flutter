class NetworkItem {
  final int id;
  final String title;
  final String description;
  final String? imageUrl;
  final String link;
  final String type; // 'prestataire' or 'event_venue'
  final String? categorie;
  final String? ville;
  
  // Social links
  final String? facebook;
  final String? instagram;
  final String? twitter;
  final String? youtube;
  final String? website;

  NetworkItem({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.link,
    required this.type,
    this.categorie,
    this.ville,
    this.facebook,
    this.instagram,
    this.twitter,
    this.youtube,
    this.website,
  });

  /// Factory pour les prestataires (profils UserPro via mu-plugin cme/v1/prestataires)
  factory NetworkItem.fromPrestataire(Map<String, dynamic> json) {
    return NetworkItem(
      id: json['id'] ?? 0,
      title: json['name'] ?? 'Sans nom',
      description: _parseHtmlString(json['description'] ?? ''),
      imageUrl: (json['photo'] != null && json['photo'].toString().isNotEmpty) 
          ? json['photo'] 
          : null,
      link: json['profile_url'] ?? '',
      type: 'prestataire',
      categorie: json['categorie'] ?? 'Non catégorisé',
      ville: json['ville'] ?? '',
      facebook: json['social']?['facebook'],
      instagram: json['social']?['instagram'],
      twitter: json['social']?['twitter'],
      youtube: json['social']?['youtube'],
      website: json['social']?['website'],
    );
  }

  /// Factory pour les lieux (event_venue via WP REST API)
  factory NetworkItem.fromVenue(Map<String, dynamic> json) {
    // Nettoyage du HTML pour la description
    String rawHtml = json['content']?['rendered'] ?? '';
    String parsedString = _parseHtmlString(rawHtml);
    
    // Récupération de l'image via featured media
    String? imgUrl;
    if (json['_embedded'] != null && json['_embedded']['wp:featuredmedia'] != null) {
      var media = json['_embedded']['wp:featuredmedia'][0];
      imgUrl = media['source_url'] ?? media['media_details']?['sizes']?['medium']?['source_url'];
    }
    // Fallback : featured_media ID (pas d'URL directe, on ignore)
    
    return NetworkItem(
      id: json['id'] ?? 0,
      title: _parseHtmlString(json['title']?['rendered'] ?? 'Sans nom'),
      description: parsedString.trim(),
      imageUrl: imgUrl,
      link: json['link'] ?? '',
      type: 'event_venue',
      facebook: json['social']?['facebook'],
      instagram: json['social']?['instagram'],
      twitter: json['social']?['twitter'],
      youtube: json['social']?['youtube'],
      website: json['social']?['website'],
    );
  }

  /// Ancien factory conservé pour compatibilité
  factory NetworkItem.fromJson(Map<String, dynamic> json, String type) {
    if (type == 'prestataire') {
      return NetworkItem.fromPrestataire(json);
    }
    return NetworkItem.fromVenue(json);
  }

  static String _parseHtmlString(String htmlString) {
    // Remplacement basique des balises HTML et des entités courantes
    String text = htmlString.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&rsquo;', "'")
               .replaceAll('&lsquo;', "'")
               .replaceAll('&amp;', '&')
               .replaceAll('&quot;', '"')
               .replaceAll('&nbsp;', ' ')
               .replaceAll('&#8211;', '–')
               .replaceAll('&#8217;', "'")
               .replaceAll('&hellip;', '…')
               .replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
