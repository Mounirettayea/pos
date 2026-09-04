import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/shop.dart';
import '../../domain/repositories/shop_repository.dart';
import '../models/shop_model.dart';

class ShopRepositoryImpl implements ShopRepository {
  @override
  Future<Either<Failure, Shop>> getShop() async {
    try {
      final box = HiveDatabase.shopBox;
      final model = box.get('shop');
      if (model != null) {
        return Right((model as ShopModel).toEntity());
      }
      if (box.isNotEmpty) {
        return Right(box.getAt(0)!.toEntity());
      }
      return const Right(Shop(name: 'MAISON AL TEEB'));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateShop(Shop shop) async {
    try {
      await HiveDatabase.shopBox.put(
        'shop',
        ShopModel(
          name: shop.name,
          upiId: shop.upiId,
          phone: shop.phone,
          address: shop.address,
          addressLine1: shop.addressLine1,
          addressLine2: shop.addressLine2,
          phoneNumber: shop.phoneNumber,
          footerText: shop.footerText,
        ),
      );
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
