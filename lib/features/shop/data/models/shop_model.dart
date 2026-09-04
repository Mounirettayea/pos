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
  @HiveField(4)
  @override
  final String addressLine1;
  @HiveField(5)
  @override
  final String addressLine2;
  @HiveField(6)
  @override
  final String phoneNumber;
  @HiveField(7)
  @override
  final String footerText;

  const ShopModel({
    required this.name,
    this.upiId = '',
    this.phone = '',
    this.address = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.phoneNumber = '',
    this.footerText = '',
  }) : super(name: name, upiId: upiId, phone: phone, address: address,
        addressLine1: addressLine1, addressLine2: addressLine2,
        phoneNumber: phoneNumber, footerText: footerText);

  factory ShopModel.fromEntity(Shop shop) => ShopModel(
    name: shop.name, upiId: shop.upiId, phone: shop.phone, address: shop.address,
    addressLine1: shop.addressLine1, addressLine2: shop.addressLine2,
    phoneNumber: shop.phoneNumber, footerText: shop.footerText,
  );

  Shop toEntity() => Shop(
    name: name, upiId: upiId, phone: phone, address: address,
    addressLine1: addressLine1, addressLine2: addressLine2,
    phoneNumber: phoneNumber, footerText: footerText,
  );
}
