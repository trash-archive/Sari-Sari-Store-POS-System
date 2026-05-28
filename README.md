# TindaKo — Sari-Sari Store POS

A complete Point of Sale (POS) system built with Flutter for managing sari-sari stores. Features an offline-first architecture with local SQLite storage, optional cloud sync, inventory management, customer credit tracking (utang), and comprehensive reporting.

---

## Features

### 🛒 Point of Sale
- Product grid with images, category filtering, and search
- Cart management — add, remove, adjust quantities
- Discount support
- **Cash payment** — automatic change calculation
- **Utang (credit)** — link purchases to a customer's running balance
- **Partial payment** — split between cash and utang
- Optional transaction photo capture
- Real-time stock validation (prevents overselling)
- Auto-generated invoice numbers

### 📦 Inventory Management
- Add, edit, and delete products
- Product images — upload from gallery/camera, auto-suggest from Open Food Facts, or scan barcode
- Category organisation (8 default categories, fully customisable)
- Low-stock alerts with a dedicated tab
- Manual stock adjustments with reason tracking
- Barcode / SKU support
- Cost & price tracking for profit calculations

### 👥 Customer Credit (Utang)
- Customer profiles — name, phone, address, notes
- Real-time balance monitoring
- Payment recording
- Full transaction history per customer
- Customer statement export to PDF

### 📊 Reports & Analytics
- Sales totals, transaction count, items sold
- Profit estimation based on product costs
- Best-selling products
- Outstanding utang summary and top debtors
- Time periods: Today, 7 Days, This Month, This Year

### ☁️ Cloud Sync (Premium)
- Supabase-powered cloud backup
- Multi-device access with the same account
- Auto-sync after every sale
- Data recovery on a new device

### ⚙️ Settings & Data
- Store name and address (shown on receipts and PDFs)
- Transaction photo toggle
- Local database backup to Downloads
- Export products as CSV
- Send feedback / report bugs

---

## Tech Stack

| Layer | Library |
|---|---|
| Framework | Flutter 3.x |
| State management | Riverpod 2.x |
| Local database | Drift (SQLite) |
| Cloud sync | Supabase |
| Image handling | image_picker |
| Barcode scanning | mobile_scanner |
| Product data | Open Food Facts API (no key needed) |
| PDF generation | pdf + printing |

---

## Project Structure

```
lib/
├── app/                    # App-level config (theme, router, providers)
├── core/                   # Shared utilities and widgets
│   ├── constants/
│   ├── utils/
│   └── widgets/
├── data/                   # Data layer
│   ├── db/                 # Drift database, tables, DAOs
│   └── services/           # Backup, PDF, image storage, sync
└── features/               # Feature modules
    ├── auth/               # Login / account / upgrade
    ├── invoices/           # Invoice history and detail
    ├── pos/                # Point of Sale screen + cart
    ├── products/           # Product and category management
    ├── reports/            # Sales reports
    ├── settings/           # App settings
    └── utang/              # Customer credit management
```

---

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Dart 3.0+
- Android Studio or VS Code
- Android device or emulator (primary target)

### Installation

```bash
# 1. Clone the repo
git clone https://github.com/trash-archive/Sari-Sari-Store-POS-System.git
cd Sari-Sari-Store-POS-System

# 2. Install dependencies
flutter pub get

# 3. Generate Drift database code
dart run build_runner build --delete-conflicting-outputs

# 4. Run
flutter run
```

### Cloud Sync (optional)
Cloud sync requires a Supabase project. The credentials in `lib/core/constants/supabase_config.dart` point to the developer's project. To use your own:
1. Create a project at [supabase.com](https://supabase.com)
2. Run the schema in `supabase_schema.sql`
3. Replace `supabaseUrl` and `supabaseAnonKey` in `supabase_config.dart`

---

## Usage

### Making a Sale
1. **POS** tab → tap products to add to cart
2. Adjust quantities, apply discount if needed
3. Choose **Cash** or **Utang**
4. For cash: enter amount received → see change
5. For utang: select or create a customer
6. Optionally take a transaction photo
7. Tap **Checkout** → invoice is generated instantly

### Managing Utang
1. **Utang** tab → view all customers and balances
2. Tap a customer → see transaction history
3. Record a payment or export a PDF statement

### Adding Products
1. **Products** tab → tap **+**
2. Fill in name, price, stock, unit, category
3. Add an image: type the name for auto-suggest, scan a barcode, or pick from gallery
4. Save

### Viewing Reports
1. **Reports** tab → select a time period
2. View sales, profit, best sellers, and top debtors

---

## Database

### Tables
`categories` · `products` · `customers` · `invoices` · `invoice_items` · `customer_payments` · `stock_movements`

### Schema version: 6
Automatic migrations handle upgrades from any previous version. On first install, 8 default categories are created — no sample products are seeded, so the store starts clean.

---

## Roadmap

- [ ] Multiple payment methods (GCash, card)
- [ ] Expense tracking
- [ ] Supplier management
- [ ] Receipt printer support
- [ ] Multi-user / tindera sharing (cloud only)

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## About

Built for real sari-sari store owners in the Philippines.  
Developer: Hasim Tordios · htordios@gmail.com

**Version 1.0.0** · Initial public release
