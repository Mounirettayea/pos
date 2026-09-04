import '../../products/domain/entities/maison_product.dart';

/// Starter catalog for Maison Al Teeb development/demo.
final maisonDemoProducts = <MaisonProduct>[
  MaisonProduct(id: 'mat-001', name: 'زيت الخزامى', nameFr: 'Huile de Lavande', nameEn: 'Lavender Oil', category: ProductCategory.oils, gender: ProductGender.unisex, size: '30 ml', sku: 'OIL-LAV-30', barcode: '000000000001', buyPrice: 30, sellPrice: 59, stock: 20, minStock: 3, description: 'زيت الخزامى 30ml', createdAt: DateTime(2026, 1, 1)),
  MaisonProduct(id: 'mat-002', name: 'زيت الليمون', nameFr: 'Huile de Citron', nameEn: 'Lemon Oil', category: ProductCategory.oils, gender: ProductGender.unisex, size: '30 ml', sku: 'OIL-LEM-30', barcode: '000000000002', buyPrice: 30, sellPrice: 59, stock: 20, minStock: 3, createdAt: DateTime(2026, 1, 1)),
  MaisonProduct(id: 'mat-003', name: 'المسك الأسود', nameFr: 'Musc Noir', nameEn: 'Black Musk', category: ProductCategory.perfumes, gender: ProductGender.unisex, size: '50 ml', sku: 'PER-BMS-50', barcode: '000000000003', buyPrice: 80, sellPrice: 149, stock: 12, minStock: 2, createdAt: DateTime(2026, 1, 1)),
  MaisonProduct(id: 'mat-004', name: 'خمرة دخان', nameFr: 'Khamrah Dokhan', nameEn: 'Khamrah Dokhan', category: ProductCategory.perfumes, gender: ProductGender.unisex, size: '100 ml', sku: 'PER-KHD-100', barcode: '000000000004', buyPrice: 140, sellPrice: 250, stock: 8, minStock: 2, createdAt: DateTime(2026, 1, 1)),
  MaisonProduct(id: 'mat-005', name: 'صابون اللبان', nameFr: 'Savon à l’encens', nameEn: 'Frankincense Soap', category: ProductCategory.soaps, gender: ProductGender.unisex, size: '100 g', sku: 'SOAP-FRA-100', barcode: '000000000005', buyPrice: 10, sellPrice: 19, stock: 30, minStock: 5, createdAt: DateTime(2026, 1, 1)),
];
