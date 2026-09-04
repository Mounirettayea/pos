# MAISON AL TEEB POS — V0.1

Base project: Flutter Billing App, customized as the starting point for the Maison Al Teeb retail POS.

## What changed in V0.1

- Rebranded application to **MAISON AL TEEB POS**
- Changed the visual identity to a **luxury black / gold** theme
- Changed currency display from INR to **DH (Moroccan dirham)**
- Replaced generic shop placeholders with Maison Al Teeb placeholders
- Kept the existing offline-first Hive architecture
- Kept barcode scanning and Bluetooth thermal printing
- Kept Clean Architecture + BLoC + GoRouter structure
- Renamed the Dart package from `billing_app` to `maison_al_teeb_pos`

## Existing core modules

- POS / billing
- Barcode scanner
- Product CRUD
- Offline local database (Hive)
- Thermal Bluetooth printing
- Shop / receipt settings

## V0.2 additions

- Added MaisonProduct domain model with category, gender, size, SKU, barcode, buy/sell prices and stock calculations.
- Added a small Maison Al Teeb demo catalog for development.
- Added a Supabase-ready products migration with RLS policies.

## V0.3 additions

- Added dashboard summary entity for sales, profit, orders and low-stock KPIs.
- Added sale and sale-item domain models with automatic totals, profit and change calculations.
- Added Supabase sales, sale-items and stock-movement tables with RLS.
- Added a small Supabase service for product fetch/create and stock updates.

## V0.4 additions

- Added a responsive Maison Al Teeb dashboard page with sales, profit, orders and low-stock KPI cards.
- Added quick actions for new sale, products/stock, barcode scanner and reports.
- Added a POS cart domain controller with add/remove/quantity/subtotal/item-count logic.

## V0.5 additions

- Added a responsive Maison Al Teeb cash register screen.
- Product search by name/SKU.
- Add/remove/change quantities in the cart.
- Discount and payment method selection.
- Checkout confirmation and total calculation.
- Added a dedicated stock overview screen with low-stock indicators.

## V0.6 additions

- Added Supabase sales repository for authenticated checkout.
- Added Maison Al Teeb thermal-receipt text formatter.
- Added Supabase initialization helper using a publishable key.
- Added an atomic, authenticated stock-decrement database function with stock movement logging.

## Next Maison Al Teeb milestones

1. Product model: category, size, buy price, sell price, stock, SKU, image.
2. Maison catalog categories: perfumes, oils, soaps, natural products, accessories.
3. Dashboard: today's sales, profit, orders, low-stock alerts.
4. Supabase sync + authentication + cloud backup.
5. Customers and suppliers.
6. Expenses and detailed profit reports.
7. WhatsApp order workflow.
8. Maison Al Teeb receipt with logo, phone, website and social links.
9. Arabic/French UI and Morocco-specific payment options.
10. Android tablet optimized POS layout.

## Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```
