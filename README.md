# Stock Inventory Manager

**Student:** Tanuj Sakthi Kumar | **University:** SIST | **Student ID:** `[ADD STUDENT ID]` | **Tutorial group:** `[ADD GROUP]`
**Course:** NET4207 Cross Platform Mobile App Development (Lab Test)

A Flutter app that saves stock items to Firebase Cloud Firestore, reads them back live, and supports combined search, low-stock filtering and quantity sorting.

## 🌐 Live Web Application

This Flutter application is configured to deploy automatically to GitHub Pages via GitHub Actions:
- **Live Website URL:** Visit the GitHub Pages link displayed in the **About** section or **Deployments** of this repository!
- Once pushed to GitHub, it is accessible at: `https://<github-username>.github.io/<repository-name>/`

## Setup and run

- **Firebase project ID:** `[ADD LECTURER-PROVIDED PROJECT ID]` (config is in the starter's `lib/firebase_options.dart`; no keys are stored in this repo)
- **Packages:** `firebase_core`, `cloud_firestore` (Flutter 3.22+)

```bash
flutter pub get
flutter run -d chrome      # or an Android emulator
flutter test               # 14 unit + widget tests
```

## Firestore schema (`stockItems`, auto ID)

| Field | Type | Rule |
|---|---|---|
| sku | String | `STK-` + 3 digits (e.g. STK-101) |
| itemName | String | trimmed, ≥ 3 characters |
| category | String | Electronics, Stationery, Hardware or Grocery |
| quantity | int | whole number ≥ 0 |
| unitPrice | number | RM > 0, up to 2 decimals |
| reorderLevel | int | whole number ≥ 0 |
| createdAt | Timestamp | `FieldValue.serverTimestamp()` on save |

## Validation

The form uses `GlobalKey<FormState>`. `validate()` must pass before any write, and each field shows its own inline message. Save shows a spinner, and the success message appears only after Firestore confirms the write. If the write fails or times out, the error is shown and the form keeps its values.

## Advanced search

The inventory screen streams `stockItems` from Firestore and filters the snapshot in Flutter. Keyword matching is partial and case-insensitive on `itemName` **or** `sku`. The **category**, **low stock** (`quantity <= reorderLevel`) and keyword controls are combined with **AND**. Results can be sorted by quantity ascending or descending. **Clear Filters** resets everything, and a message is shown when nothing matches.

## Test log

| # | Input | Expected | Actual | Screenshot |
|---|---|---|---|---|
| 1 | Blank form, then SKU `STK-1`, name `ab`, qty `-2`, price `0` | Inline errors, no new document | `[fill in]` | `screenshots/01_invalid.png` |
| 2 | Save STK-101, STK-102, STK-103, then reload | 3 records with correct values | `[fill in]` | `screenshots/02_saved.png` |
| 3 | `mouse` + Electronics + Low stock | Only STK-103 | `[fill in]` | `screenshots/03_combined.png` |
