class AddonManifest {
  final String id;
  final String name;
  final String? logo;
  final List<AddonCatalog> catalogs;
  final String addonUrl; // الرابط الأساسي للإضافة

  AddonManifest({
    required this.id,
    required this.name,
    this.logo,
    required this.catalogs,
    required this.addonUrl,
  });

  factory AddonManifest.fromJson(Map<String, dynamic> json, String url) {
    var catalogsList = json['catalogs'] as List? ?? [];
    List<AddonCatalog> parsedCatalogs = catalogsList
        .map((c) => AddonCatalog.fromJson(c))
        .toList();

    return AddonManifest(
      id: json['id'] ?? '',
      name: json['name'] ?? 'إضافة غير معروفة',
      logo: json['logo'],
      catalogs: parsedCatalogs,
      addonUrl: url,
    );
  }
}

class AddonCatalog {
  final String type; // movie, series
  final String id;
  final String name;

  AddonCatalog({required this.type, required this.id, required this.name});

  factory AddonCatalog.fromJson(Map<String, dynamic> json) {
    return AddonCatalog(
      type: json['type'] ?? 'movie',
      id: json['id'] ?? '',
      name: json['name'] ?? 'بدون اسم',
    );
  }
}

// عنصر داخل الكاتالوج (فيلم/مسلسل)
class AddonCatalogItem {
  final String id;
  final String name;
  final String? poster;
  final String? description;

  AddonCatalogItem({
    required this.id,
    required this.name,
    this.poster,
    this.description,
  });

  factory AddonCatalogItem.fromJson(Map<String, dynamic> json) {
    return AddonCatalogItem(
      id: json['id'] ?? '',
      name: json['name'] ?? 'بدون اسم',
      poster: json['poster'],
      description: json['description'],
    );
  }
}
