# MAISON AL TEEB POS — Production V1

A Morocco-ready Flutter retail POS foundation for Maison Al Teeb.

## Stack
- Flutter / Material 3
- Supabase Auth + PostgreSQL + RLS
- Hive offline storage foundation
- Barcode scanning
- Bluetooth thermal printing
- BLoC / Clean Architecture direction

## Production V1 foundation
- Authenticated checkout with server-side price/stock validation
- Cash register shifts
- Purchases and purchase items
- Returns / refunds data model
- Audit log
- Offline sync queue
- Admin / manager / cashier roles
- MAD receipt/payment metadata
- Arabic/French product-name fields
- SKU and product image fields
- Basic production validation tests

## Recommended next UI modules
1. Cash register open/close screen
2. Product & inventory management
3. Purchase receiving screen
4. Returns/refunds screen
5. Customers & suppliers
6. Expenses & reports
7. Arabic/French localization
8. Offline sync worker
9. Thermal receipt template
10. Tablet POS layout

## Run
```bash
flutter pub get
flutter test
flutter run
```

For Android release builds, use the included GitHub Actions workflow.
