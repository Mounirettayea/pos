abstract class PrinterEvent { const PrinterEvent(); }
class InitPrinterEvent extends PrinterEvent { const InitPrinterEvent(); }
class RefreshPrinterEvent extends PrinterEvent { const RefreshPrinterEvent(); }
class ScanPrintersEvent extends PrinterEvent { const ScanPrintersEvent(); }
class ConnectPrinterEvent extends PrinterEvent { final String mac; final String name; const ConnectPrinterEvent(this.mac, this.name); }
class DisconnectPrinterEvent extends PrinterEvent { const DisconnectPrinterEvent(); }
class TestPrintEvent extends PrinterEvent { final String shopName; const TestPrintEvent(this.shopName); }
