# Sari-Sari Store POS System

A complete Point of Sale (POS) system built with Flutter for managing sari-sari stores. Features offline-first architecture with local database storage, inventory management, customer credit tracking (utang), and comprehensive reporting.

## Features

### 🛒 Point of Sale
- **Product Grid View** - Visual product selection with images
- **Category Filtering** - Quick filter by product categories
- **Search Functionality** - Find products instantly
- **Cart Management** - Add, remove, and adjust quantities
- **Discount Support** - Apply discounts to transactions
- **Payment Methods**:
  - **Cash Payment** - With automatic change calculation
  - **Utang (Credit)** - Track customer credit purchases
- **Transaction Photos** - Optional photo capture for each transaction (enable in settings)
- **Stock Validation** - Prevents overselling with real-time stock checks
- **Invoice Generation** - Automatic invoice creation with unique numbers

### 📦 Inventory Management
- **Product Management** - Add, edit, and track products
- **Product Images** - Upload from gallery or camera
- **Online Image Search** - Find images from Open Food Facts
- **Auto-Suggest Images** - Images appear as you type product names
- **Category Organization** - 8 default categories (Beverages, Snacks, Canned Goods, etc.)
- **Stock Tracking** - Real-time inventory levels
- **Low Stock Alerts** - Dedicated tab for low stock items
- **Stock Adjustments** - Manual stock corrections with reason tracking
- **Barcode/SKU Support** - Product identification
- **Barcode Scanner** - Scan barcodes to auto-fetch product data
- **Cost & Price Tracking** - For profit calculations

### 👥 Customer Management (Utang)
- **Customer Profiles** - Name, phone, address, notes
- **Credit Tracking** - Real-time balance monitoring
- **Payment Recording** - Track customer payments
- **Transaction History** - View all utang purchases and payments
- **Customer Statements** - Export to PDF
- **Delete Customers** - Remove customer records

### 📊 Reports & Analytics
- **Sales Reports** - Total sales, transactions, items sold
- **Profit Estimation** - Based on product costs
- **Best Sellers** - Top performing products
- **Outstanding Utang** - Total credit owed
- **Top Debtors** - Customers with highest balances
- **Time Periods** - Today, 7 Days, This Month, This Year
- **Manual Refresh** - Update reports on demand

### 🎨 User Interface
- **Splash Screen** - Professional loading screen
- **Bottom Navigation** - Easy access to all features
- **Search & Filter** - Throughout the app
- **Real-time Updates** - Instant data synchronization
- **Responsive Design** - Works on all screen sizes
- **Material Design** - Modern, clean interface
- **Transaction Photos** - Optional camera capture during checkout

## Technology Stack

- **Framework**: Flutter 3.0+
- **State Management**: Riverpod 2.4+
- **Database**: Drift (SQLite) - Offline-first
- **Image Handling**: image_picker
- **Barcode Scanning**: mobile_scanner
- **Online Features**: Open Food Facts API (no API keys required!)
- **PDF Generation**: pdf, printing
- **Architecture**: Clean Architecture with feature-based structure

## Project Structure

```
lib/
├── app/                    # App configuration
│   ├── app.dart           # Main app widget
│   ├── providers.dart     # Global providers
│   ├── router.dart        # Navigation
│   └── theme.dart         # App theme
├── core/                  # Core utilities
│   ├── constants/         # App constants
│   ├── formatting/        # Formatters
│   └── utils/            # Utility functions
├── data/                  # Data layer
│   ├── db/               # Database
│   │   ├── daos/         # Data Access Objects
│   │   └── tables/       # Table definitions
│   └── services/         # Services (PDF, Images, Backup)
└── features/             # Feature modules
    ├── invoices/         # Invoice management
    ├── pos/              # Point of Sale
    ├── products/         # Product management
    ├── reports/          # Reports & analytics
    ├── settings/         # App settings
    └── utang/           # Customer credit management
```

## Getting Started

### Prerequisites
- Flutter SDK 3.0 or higher
- Dart 3.0 or higher
- Android Studio / VS Code
- Android device or emulator

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd sarisari_store
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Generate database code**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

4. **Run the app**
```bash
flutter run
```

## Database Schema

### Tables
- **products** - Product inventory
- **categories** - Product categories
- **customers** - Customer information
- **invoices** - Sales transactions
- **invoice_items** - Transaction line items
- **customer_payments** - Payment records
- **stock_movements** - Inventory adjustments

### Key Features
- Automatic schema migrations
- Seed data on first launch (60+ sample products)
- Foreign key constraints
- Indexed queries for performance

## Usage Guide

### Adding Products
1. Navigate to **Products** tab
2. Tap **Add Product** button
3. Fill in product details (name, price, stock, etc.)
4. **Add Image** (3 options):
   - **Type product name** - Images auto-suggest from online databases
   - **Scan Barcode** - Auto-fetch product data and image
   - **Gallery/Camera** - Upload manually
5. Save product

### Making a Sale
1. Navigate to **POS** tab
2. Search or browse products
3. Tap products to add to cart
4. Review cart and apply discount if needed
5. Choose payment method:
   - **Cash**: Enter amount received, see change
   - **Utang**: Select or create customer
6. **Optional**: Take a photo (if enabled in settings)
7. Complete transaction
8. View invoice immediately

### Managing Utang
1. Navigate to **Utang** tab
2. View all customers and balances
3. Tap customer to see details
4. Record payments or view transaction history
5. Export customer statement to PDF

### Viewing Reports
1. Navigate to **Reports** tab
2. Select time period (Today, Week, Month, Year)
3. View sales metrics, best sellers, and top debtors
4. Tap refresh icon to update data

## Validations & Business Rules

### Stock Management
- Cannot add out-of-stock items to cart
- Cannot exceed available stock quantity
- Real-time stock updates after sales
- Low stock threshold alerts

### Payment Validations
- Cash payment must be >= total amount
- Discount cannot exceed subtotal
- Customer name required for utang
- Payment amount must be > 0

### Data Integrity
- Unique invoice numbers
- Foreign key constraints
- Transaction-based operations
- Automatic timestamp tracking

## Seed Data

The app includes 60+ sample products across 8 categories:
- Beverages (Coca-Cola, Sprite, C2, etc.)
- Snacks (Chippy, Piattos, Nova, etc.)
- Canned Goods (Century Tuna, Ligo Sardines, etc.)
- Personal Care (Safeguard, Colgate, etc.)
- Condiments (Silver Swan, Datu Puti, etc.)
- Dairy (Alaska Milk, Bear Brand, etc.)
- Bread & Bakery (Gardenia, Pandesal, etc.)
- Others (Lucky Me, Rice, Eggs, etc.)

## Future Enhancements

- [x] Barcode scanning
- [x] Online product image search (Open Food Facts)
- [ ] Multiple payment methods (GCash, Card)
- [ ] Sales analytics dashboard
- [ ] Backup & restore to cloud
- [ ] Multi-user support
- [ ] Receipt printing
- [ ] Expense tracking
- [ ] Supplier management

## Contributing

Contributions are welcome! Please follow these steps:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Documentation

- **[Main README](README.md)** - This file
- **[Image Search Guide](IMAGE_DOCS_INDEX.md)** - Complete guide for image search feature
- **[Setup Instructions](OPENFOODFACTS_SETUP.md)** - Online features setup
- **[Visual User Guide](VISUAL_USER_GUIDE.md)** - Screenshots and examples
- **[Developer Quick Start](DEVELOPER_QUICKSTART.md)** - For developers
- **[Debug Guide](IMAGE_DEBUG_GUIDE.md)** - Troubleshooting help

## Support

For issues, questions, or suggestions, please open an issue on GitHub.

## Acknowledgments

- Built with Flutter and Dart
- Uses Drift for local database
- Inspired by real sari-sari store operations in the Philippines

---

**Version**: 1.0.0  
**Last Updated**: 2024  
**Status**: Production Ready ✅
