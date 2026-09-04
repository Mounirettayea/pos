import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

enum PrinterStatus { initial, scanning, scanSuccess, scanFailure, connecting, connected, connectionFailure, disconnected, testPrinting }

class PrinterState {
  final PrinterStatus status;
  final List<BluetoothInfo> devices;
  final String? connectedMac;
  final String? connectedName;
  final String? errorMessage;
  const PrinterState({this.status = PrinterStatus.initial, this.devices = const [], this.connectedMac, this.connectedName, this.errorMessage});
  PrinterState copyWith({PrinterStatus? status, List<BluetoothInfo>? devices, String? connectedMac, String? connectedName, String? errorMessage, bool clearError = false}) => PrinterState(status: status ?? this.status, devices: devices ?? this.devices, connectedMac: connectedMac ?? this.connectedMac, connectedName: connectedName ?? this.connectedName, errorMessage: clearError ? null : (errorMessage ?? this.errorMessage));
}
