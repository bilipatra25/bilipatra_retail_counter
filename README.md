# Bilipatra Retail Counter POS

This is the Retail Counter POS (Point of Sale) Flutter application designed for in-store retail sales. It acts as the primary interface for processing offline cash payments, online UPI/QR payments, and managing customer credit accounts ("Pay Later").

## 🚀 Getting Started

To run the application locally:
1. Ensure you have the Flutter SDK installed.
2. Run `flutter pub get` to install dependencies.
3. Use `flutter run` to launch the app on your connected device or emulator.
4. To build the release APK: `flutter build apk --release`

## 🏗️ Architecture & State Management

The application is built using the **Provider** pattern for state management. Key components include:

- **`lib/providers/app_provider.dart`**: The core state manager. It handles the shopping cart (`_cart`), the active customer (`_selectedCustomer`), and the complex global discount logic (`_globalDiscountValue`). 
  - *Key Logic*: Auto-quantity discounts are applied based on the number of eligible items in the cart. The cart state is strictly cleared via `clearCartAndCustomer()` after a successful checkout or when the cart becomes empty.
- **`lib/screens/pos/right_pane_widget.dart`**: The primary POS checkout UI. It contains the logic for routing checkout requests (Cash, UPI, Credit) to the backend API.
- **`lib/services/api_service.dart`**: Handles all direct HTTP communication with the Node.js backend.
- **`lib/services/checkout_service.dart`**: A helper class that structures the payloads for Cash, Online, and Credit orders before passing them to the `ApiService`.

## 🖨️ Hardware Integrations

- **Thermal Printing**: The app utilizes `blue_thermal_printer` and standard `printing` packages to generate and print receipts over Bluetooth thermal printers.
- **Barcode Scanning**: It supports keyboard wedge barcode scanners. Scanning a barcode automatically injects the item into the `app_provider` cart.

## 📲 App Distribution Standard Practice

When a new version of the frontend client (e.g., this POS App) is released, you must update the backend database configuration so the application can enforce version checks and provide download links for the update.

Execute the following SQL queries in the backend database to update the required configuration values (example for version `1.0.7`):

```sql
UPDATE b12greenStoreLocator.tbl_configuration
	SET configuration_value='1.0.7'
	WHERE configuration_id=8;
    
UPDATE b12greenStoreLocator.tbl_configuration
	SET configuration_value='1.0.7'
	WHERE configuration_id=7;
    
UPDATE b12greenStoreLocator.tbl_configuration
	SET configuration_value='https://drive.google.com/file/d/1ymsFKw3Z2VKsL_cwT8yqN2Lv4F0KSCUN/view?usp=sharing'
	WHERE configuration_id=6;
```

## 🤖 Handoff Notes for AI Agents / New Developers
- **Discounts**: Be extremely careful when modifying discount logic. Item-level discounts and Global discounts interact. The Auto-Qty discount is triggered dynamically whenever the cart changes unless a manual global discount was applied.
- **Order Modification**: Editing an existing "Recent Bill" puts the `AppProvider` into `isEditingOrder` mode. The checkout payload requires the `order_id` to perform an `UPDATE` rather than an `INSERT` on the backend.
- **QR Payments**: When the "PAY UPI" button is pressed, the order is actually placed *first* via `CheckoutService.placeOnlineOrder`, and then the `QRPaymentDialog` is shown. If the payment is cancelled, the cart must still be cleared or the order cancelled on the backend to avoid phantom duplicate orders.
