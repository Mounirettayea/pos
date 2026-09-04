import 'package:equatable/equatable.dart';

class Shop extends Equatable {
  final String name;
  final String upiId;
  final String phone;
  final String address;

  const Shop({
    required this.name,
    this.upiId = '',
    this.phone = '',
    this.address = '',
  });

  @override
  List<Object?> get props => [name, upiId, phone, address];
}
