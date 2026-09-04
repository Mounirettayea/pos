import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/shop.dart';
import '../repositories/shop_repository.dart';

class GetShopUseCase implements UseCase<Shop, NoParams> {
  final ShopRepository repository;
  GetShopUseCase(this.repository);
  @override
  Future<Either<Failure, Shop>> call(NoParams params) => repository.getShop();
}

class UpdateShopUseCase implements UseCase<void, Shop> {
  final ShopRepository repository;
  UpdateShopUseCase(this.repository);
  @override
  Future<Either<Failure, void>> call(Shop params) => repository.updateShop(params);
}
