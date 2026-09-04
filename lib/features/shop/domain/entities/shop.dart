import 'package:equatable/equatable.dart';

class Shop extends Equatable {
  final String name;
  final String upiId;
  final String phone;
  final String address;
  final String addressLine1;
  final String addressLine2;
  final String phoneNumber;
  final String footerText;

  const Shop({
    required this.name,
    this.upiId = '',
    this.phone = '',
    this.address = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.phoneNumber = '',
    this.footerText = '',
  });

  @override
  List<Object?> get props => [name, upiId, phone, address, addressLine1, addressLine2, phoneNumber, footerText];
}
