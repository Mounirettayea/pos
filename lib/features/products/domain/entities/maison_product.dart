enum ProductCategory {
  perfumes,
  oils,
  soaps,
  naturalProducts,
  accessories,
  other,
}

enum ProductGender { men, women, unisex }

class MaisonProduct {
  final String id;
  final String name;
  final String? nameFr;
  final String? nameEn;
  final ProductCategory category;
  final ProductGender gender;
  final String size;
  final String? sku;
  final String? barcode;
  final double buyPrice;
  final double sellPrice;
  final int stock;
  final int minStock;
  final String? imageUrl;
  final String? description;
  final DateTime createdAt;

  const MaisonProduct({
    required this.id,
    required this.name,
    this.nameFr,
    this.nameEn,
    required this.category,
    required this.gender,
    required this.size,
    this.sku,
    this.barcode,
    required this.buyPrice,
    required this.sellPrice,
    required this.stock,
    this.minStock = 2,
    this.imageUrl,
    this.description,
    required this.createdAt,
  });

  bool get isLowStock => stock <= minStock;

  double get profitPerUnit => sellPrice - buyPrice;

  double get marginPercent =>
      sellPrice == 0 ? 0 : ((sellPrice - buyPrice) / sellPrice) * 100;

  MaisonProduct copyWith({
    String? name,
    String? nameFr,
    String? nameEn,
    ProductCategory? category,
    ProductGender? gender,
    String? size,
    String? sku,
    String? barcode,
    double? buyPrice,
    double? sellPrice,
    int? stock,
    int? minStock,
    String? imageUrl,
    String? description,
  }) {
    return MaisonProduct(
      id: id,
      name: name ?? this.name,
      nameFr: nameFr ?? this.nameFr,
      nameEn: nameEn ?? this.nameEn,
      category: category ?? this.category,
      gender: gender ?? this.gender,
      size: size ?? this.size,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}
