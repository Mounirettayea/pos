import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/shop.dart';
import '../../domain/usecases/shop_usecases.dart';

abstract class ShopEvent { const ShopEvent(); }
class LoadShopEvent extends ShopEvent { const LoadShopEvent(); }
class UpdateShopEvent extends ShopEvent { final Shop shop; const UpdateShopEvent(this.shop); }

abstract class ShopState { const ShopState(); }
class ShopInitial extends ShopState { const ShopInitial(); }
class ShopLoading extends ShopState { const ShopLoading(); }
class ShopLoaded extends ShopState { final Shop shop; const ShopLoaded(this.shop); }
class ShopError extends ShopState { final String message; const ShopError(this.message); }

class ShopBloc extends Bloc<ShopEvent, ShopState> {
  final GetShopUseCase getShopUseCase;
  final UpdateShopUseCase updateShopUseCase;
  ShopBloc({required this.getShopUseCase, required this.updateShopUseCase}) : super(const ShopInitial()) {
    on<LoadShopEvent>(_load);
    on<UpdateShopEvent>(_update);
  }

  Future<void> _load(LoadShopEvent event, Emitter<ShopState> emit) async {
    emit(const ShopLoading());
    final result = await getShopUseCase(const NoParams());
    result.match((f) => emit(ShopError(f.message)), (shop) => emit(ShopLoaded(shop)));
  }

  Future<void> _update(UpdateShopEvent event, Emitter<ShopState> emit) async {
    final result = await updateShopUseCase(event.shop);
    result.match((f) => emit(ShopError(f.message)), (_) => emit(ShopLoaded(event.shop)));
  }
}
