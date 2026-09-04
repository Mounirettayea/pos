import 'package:hive/hive.dart';
import '../../domain/entities/shop.dart';

part 'shop_model.g.dart';

@HiveType(typeId: 1)
class ShopModel extends Shop {
  @HiveField(0)
  @override
  final String name;
  @HiveField(1)
  @override
  final String upiId;
  @HiveField(2)
  @override
  final String phone;
  @HiveField(3)
  @override
  final String address;

  const ShopModel({required this.name, this.upiId = '', this.phone = '', this.address = ''})
      : super(name: name, upiId: upiId, phone: phone, address: address);

  Shop toEntity() => Shop(name: name, upiId: upiId, phone: phone, address: address);
}
