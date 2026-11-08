# Rockie Store API (Laravel 13)

REST backend for the `rockie_store` Flutter app. All endpoints live under `/api/v1`, return JSON only, and use Sanctum bearer tokens.

## Setup

Requirements: PHP 8.3+ with `pdo_pgsql` and `sodium` enabled (the Firebase SDK needs `sodium`: uncomment `extension=sodium` in `php.ini`), Composer, PostgreSQL.

```bash
cd backend
composer install
cp .env.example .env            # then set DB_* for PostgreSQL
php artisan key:generate

# Product images: copy the Flutter folder frontend/assets/images/* into
# storage/app/public/seed-images/ (keep subfolders), then:
php artisan storage:link

php artisan migrate:fresh --seed
php artisan test
```

The seed creates 10 categories, 26 products (177 variants), the reviews from the Flutter data, the coupons `WELCOME10`, `SAVE5` and `FREESHIP`, and the user **test@example.com / password**. That user starts with no address and no payment method.

Product data lives in `database/seeders/data/products.json`. Edit it and re-run `php artisan migrate:fresh --seed`. A missing image is logged as a warning and seeding continues.

### Run for a phone or emulator

```bash
php artisan serve --host=0.0.0.0 --port=8000
```

| Client | Base URL |
|---|---|
| Android emulator / USB phone | `http://127.0.0.1:8000/api/v1` after `adb reverse tcp:8000 tcp:8000` (the app's default; `10.0.2.2` loses bytes on large images on this machine) |
| iOS simulator | `http://127.0.0.1:8000/api/v1` |
| Physical phone (same Wi-Fi) | `http://<your-PC-LAN-IP>:8000/api/v1` |

Image URLs are built from the host the app calls, so they work from the emulator and from a phone. Allow port 8000 through the Windows firewall for physical devices.

### Mail (password reset codes)

For local development, `MAIL_MAILER=log` writes each email to `storage/logs/laravel.log`. Search it for `reset code is:`.

For real SMTP (Gmail example; use an App Password):

```dotenv
MAIL_MAILER=smtp
MAIL_SCHEME=null
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=you@gmail.com
MAIL_PASSWORD=your-16-char-app-password
MAIL_FROM_ADDRESS="you@gmail.com"
MAIL_FROM_NAME="Rockie Store"
```

### Firebase (Google and Facebook sign-in only)

1. Firebase console → Project settings → Service accounts → **Generate new private key**.
2. Save the file as `storage/app/private/firebase-service-account.json` (git-ignored). Never put it in the Flutter app.
3. In `.env`, set `FIREBASE_CREDENTIALS=storage/app/private/firebase-service-account.json` and optionally `FIREBASE_PROJECT_ID=your-project-id`.

Email/password accounts do **not** use Firebase. They use `/auth/register` and `/auth/login`.

## Conventions for the Flutter app

- Send `Accept: application/json` on every request. Authenticated calls also send `Authorization: Bearer <token>`. Store the token in `flutter_secure_storage`.
- Money is a decimal **string** (`"25.00"`). Parse it with `Decimal`/`num.parse` for display only, and never send prices or totals to the server.
- Dates are ISO 8601 UTC (`"2026-10-21T14:03:00Z"`).
- Lists that paginate return `data`, `links` and `meta` (`meta.current_page`, `meta.last_page`, `meta.total`).
- Errors:

| Status | Meaning | Body |
|---|---|---|
| 401 | Missing, expired or revoked token | `{"message": "Unauthenticated."}` |
| 403 | Record belongs to another user | `{"message": "This action is unauthorized."}` |
| 404 | Not found | `{"message": "Resource not found."}` |
| 409 | Stock or coupon changed; reload the cart | `{"message": "...", "errors": {...}}` |
| 422 | Validation failed | `{"message": "...", "errors": {"field": ["..."]}}` |
| 429 | Rate limited | `{"message": "..."}` |

## Endpoints

🔒 = requires `Authorization: Bearer <token>`.

### Auth

| Method | Path | Notes |
|---|---|---|
| POST | `/auth/register` | 201 |
| POST | `/auth/login` | 5 attempts per minute per email + IP |
| POST | `/auth/firebase` | Google/Facebook only |
| POST | `/auth/logout` 🔒 | Revokes this device's token only |
| POST | `/auth/forgot-password` | 1 per minute, 5 per hour per email |
| POST | `/auth/verify-otp` | Max 5 wrong attempts per code |
| POST | `/auth/reset-password` | Logs out every device |

**POST /auth/register**

```json
{ "name": "Sam", "email": "sam@example.com", "password": "secret123", "password_confirmation": "secret123", "gender": "female" }
```

`gender` is optional: `male`, `female`, `other`, `prefer_not_to_say` or `null`. `device_name` is optional on register/login/firebase.

Response `201` (login and firebase return the same shape, with status `200`):

```json
{
  "data": {
    "token": "1|Xyz...",
    "token_type": "Bearer",
    "user": {
      "id": 7, "name": "Sam", "email": "sam@example.com", "gender": "female",
      "phone": null, "avatar_url": null, "has_password": true, "is_social_account": false,
      "email_verified_at": null, "created_at": "2026-10-21T14:03:00Z"
    }
  }
}
```

**POST /auth/login** `{ "email": "sam@example.com", "password": "secret123" }`. A wrong email or password always returns:

```json
{ "message": "These credentials do not match our records.", "errors": { "email": ["These credentials do not match our records."] } }
```

**POST /auth/firebase** `{ "id_token": "<FirebaseAuth.instance.currentUser!.getIdToken()>" }`. Returns `201` when a new account is created and `200` otherwise. An invalid or expired token returns `401`. The `password` provider returns `422`. If the email belongs to an existing account but Firebase hasn't verified it, the response is `409`.

**POST /auth/logout** 🔒 → `{ "message": "Logged out." }`

**Forgot password (3 steps)**

```http
POST /auth/forgot-password   { "email": "sam@example.com" }
→ 200 { "message": "If an account exists for this email, we have sent a 6-digit code to it." }

POST /auth/verify-otp        { "email": "sam@example.com", "otp": "123456" }
→ 200 { "message": "Code verified.", "data": { "reset_token": "64-char-string", "expires_in": 900 } }
→ 422 { "errors": { "otp": ["The code you entered is incorrect."] } }

POST /auth/reset-password    { "email": "sam@example.com", "reset_token": "...", "password": "newpass123", "password_confirmation": "newpass123" }
→ 200 { "message": "Your password has been reset. Please log in with your new password." }
```

Codes expire after 10 minutes. The reset token expires after 15 minutes and works once.

### Profile 🔒

| Method | Path |
|---|---|
| GET | `/me` |
| PATCH | `/me` |
| POST | `/me/change-password` |

```http
PATCH /me  { "name": "Sam R.", "gender": "prefer_not_to_say", "phone": "+855 12 345 678", "avatar_url": "https://..." }
→ 200 { "data": { ...user } }          // sending "email" → 422 "The email address cannot be changed."

POST /me/change-password  { "current_password": "old", "password": "newpass123", "password_confirmation": "newpass123" }
→ 200 { "message": "Your password has been changed." }   // other devices are signed out
```

Social accounts without a password (`has_password: false`) can omit `current_password`.

### Catalog (public)

| Method | Path |
|---|---|
| GET | `/categories` |
| GET | `/products?category_id=&q=&sort=&min_price=&max_price=&page=&per_page=` |
| GET | `/products/{id}` |
| GET | `/products/{id}/reviews?page=` |
| POST | `/products/{id}/reviews` 🔒 |

`sort` is one of `newest` (default), `price_asc`, `price_desc`, `popular` or `rating`. `per_page` can be at most 50 (default 20).

```json
// GET /categories
{ "data": [ { "id": 5, "name": "Jeans", "slug": "jeans", "image_url": "http://10.0.2.2:8000/storage/seed-images/jeans.png", "sort_order": 5, "products_count": 4 } ] }

// GET /products
{
  "data": [
    { "id": 1, "category_id": 4, "title": "Slip-On Loafers for Men, ...", "price": "25.00", "original_price": "33.33",
      "discount_percent": 25, "sold_count": 70, "sold_label": "70+", "rating": 4.5, "review_count": 214,
      "image_url": "http://10.0.2.2:8000/storage/seed-images/product/loafers1.jpg", "in_stock": true }
  ],
  "links": { "first": "...", "last": "...", "prev": null, "next": "..." },
  "meta": { "current_page": 1, "last_page": 2, "per_page": 20, "total": 26 }
}

// GET /products/1
{
  "data": {
    "id": 1, "title": "Slip-On Loafers for Men, ...", "description": "...",
    "category": { "id": 4, "name": "Men's Shoes", "slug": "mens-shoes", "image_url": "...", "sort_order": 4 },
    "price": "25.00", "original_price": "33.33", "discount_percent": 25, "currency": "USD",
    "sold_count": 70, "sold_label": "70+", "rating": 4.5, "review_count": 214,
    "images": ["http://10.0.2.2:8000/storage/seed-images/product/loafers1.jpg"],
    "colors": ["Black", "Brown"], "sizes": ["39", "40", "41", "42", "43", "44"],
    "variants": [ { "id": 1, "sku": "RS-0001-BLACK-39", "color": "Black", "size": "39", "stock": 20, "purchase_limit": 10, "in_stock": true } ],
    "purchase_limit": 10, "in_stock": true,
    "review_summary": { "rating": 4.5, "review_count": 214, "latest": [ { "id": 1, "name": "Banana", "avatar": "🍌", "rating": 5, "body": "...", "images": ["..."], "is_verified_purchase": false, "created_at": "..." } ] }
  }
}
```

To add an item to the cart, find the variant whose `color` and `size` match the user's selection and send its `id`.

**POST /products/{id}/reviews** 🔒 `{ "rating": 5, "body": "Great!", "images": ["https://..."] }` returns `201`. The user must have ordered the product first (otherwise `403`) and can review each product once (otherwise `422`).

### Cart 🔒

| Method | Path | Body |
|---|---|---|
| GET | `/cart?delivery_method=standard\|express` | |
| POST | `/cart/items` | `{ "product_variant_id": 1, "quantity": 1 }` |
| PATCH | `/cart/items/{item}` | `{ "quantity": 2 }` |
| DELETE | `/cart/items/{item}` | |
| POST | `/cart/coupon` | `{ "code": "WELCOME10" }` |
| DELETE | `/cart/coupon` | |
| GET | `/coupons` | |

Every cart call returns the full cart:

```json
{
  "data": {
    "id": 3,
    "items": [
      { "id": 91, "product_id": 1, "product_variant_id": 1, "title": "Slip-On Loafers ...", "variant": "Black / 39",
        "color": "Black", "size": "39", "sku": "RS-0001-BLACK-39", "unit_price": "25.00", "original_price": "33.33",
        "quantity": 2, "line_total": "50.00", "image_url": "http://...", "stock": 20, "purchase_limit": 10, "issue": null }
    ],
    "item_count": 2,
    "coupon": { "code": "WELCOME10", "title": "10% OFF", "is_applicable": true, "message": null },
    "delivery_method": "standard",
    "subtotal": "50.00", "discount_total": "5.00", "shipping_total": "1.49", "grand_total": "46.49",
    "currency": "USD"
  }
}
```

- `issue` is `null`, `"unavailable"`, `"insufficient_stock"` or `"over_purchase_limit"`. Show a warning on that line.
- Going over `purchase_limit` → `422`. Asking for more than the stock → `409`, e.g. `{"message":"Only 3 left in stock.","errors":{"product_variant_id":1,"requested":4,"available":3}}`.
- Shipping is `1.49` (standard) or `2.49` (express). `FREESHIP` makes the discount equal to the shipping fee.

### Addresses and payment methods 🔒

| Method | Path |
|---|---|
| GET / POST | `/addresses` |
| GET / PATCH / DELETE | `/addresses/{id}` |
| GET / POST | `/payment-methods` |
| GET / PATCH / DELETE | `/payment-methods/{id}` |

New users have none, and nothing becomes default automatically. `is_default` changes only when the app sends `"is_default": true` (which clears the flag on the user's other records) or `false`.

```http
POST /addresses
{ "label": "Home", "recipient_name": "Sam", "phone": "+855 12 345 678", "line1": "123 St 271", "line2": null,
  "city": "Phnom Penh", "state": null, "postal_code": "12000", "country_code": "KH", "is_default": true }
→ 201 { "data": { "id": 12, ...same fields..., "is_default": true, "created_at": "...", "updated_at": "..." } }

POST /payment-methods  { "type": "cash_on_delivery", "label": "Cash on delivery" }
POST /payment-methods  { "type": "card", "label": "Visa •••• 4242", "brand": "visa", "last4": "4242",
                         "provider": "stripe", "provider_reference": "pm_123" }
→ 201 { "data": { "id": 3, "type": "card", "label": "...", "brand": "visa", "last4": "4242", "provider": "stripe",
                  "provider_reference": "pm_123", "is_default": false, "created_at": "...", "updated_at": "..." } }
```

Never send a full card number or CVV. `card_number`, `number`, `pan`, `cvv` and `cvc` are rejected with `422`. Card details must be tokenised by the payment provider's SDK.

`DELETE` returns `204` with no body.

### Orders 🔒

| Method | Path |
|---|---|
| POST | `/orders` |
| GET | `/orders?page=` |
| GET | `/orders/{id}` |

```http
POST /orders
Idempotency-Key: 3f0c9a2e-...   (generate one UUID per "Place order" tap; reuse it when retrying)
{ "address_id": 12, "payment_method_id": 3, "delivery_method": "standard", "note": "Call before delivery" }
```

Response `201` (or `200` with the same order when the key is retried):

```json
{
  "data": {
    "id": 1, "number": "RS261021-ANZ0SC", "status": "pending", "payment_status": "unpaid",
    "payment_method": { "id": 3, "type": "cash_on_delivery", "label": "Cash on delivery" },
    "delivery_method": "standard", "currency": "USD",
    "subtotal": "105.00", "discount_total": "10.50", "shipping_total": "1.49", "grand_total": "95.99",
    "coupon_code": "WELCOME10",
    "shipping_address": { "label": "Home", "recipient_name": "Sam", "phone": "+855...", "line1": "...", "line2": null,
                          "city": "Phnom Penh", "state": null, "postal_code": "12000", "country_code": "KH" },
    "note": null, "item_count": 3,
    "items": [ { "id": 1, "product_id": 5, "product_variant_id": 37, "title": "...", "sku": "RS-0005-BLACK-39",
                 "color": "Black", "size": "39", "variant": "Black / 39", "image_url": "http://...",
                 "unit_price": "35.00", "quantity": 3, "line_total": "105.00" } ],
    "placed_at": "2026-10-21T14:20:00Z", "updated_at": "2026-10-21T14:20:00Z"
  }
}
```

- Missing address or payment method → `422` with `"Please add or select a shipping address."` / `"Please add or select a payment method."`.
- Empty cart → `422` `{"errors":{"cart":["Your cart is empty."]}}`.
- Stock changed → `409` and the cart is kept:
  `{"message":"Some items in your cart are no longer available ...","errors":{"items":[{"product_variant_id":37,"title":"...","requested":3,"available":1,"reason":"insufficient_stock"}]}}`
- Coupon expired or used up → `409`.
- `status`: `pending`, `processing`, `shipped`, `delivered`, `cancelled`. `payment_status`: `unpaid` (cash on delivery), `pending` (card, waiting for the provider webhook), `paid`, `failed`, `refunded`.

### Notifications 🔒 and support

| Method | Path | Notes |
|---|---|---|
| GET | `/notifications` | Paginated, plus `unread_count` |
| POST | `/notifications/{id}/read` | |
| POST | `/notifications/read-all` | |
| POST | `/support/messages` | Token optional |

```json
// GET /notifications
{ "data": [ { "id": 1, "type": "order_placed", "title": "Order placed", "body": "Your order RS261021-ANZ0SC has been placed. ...",
              "data": { "order_id": 1 }, "is_read": false, "read_at": null, "created_at": "..." } ],
  "links": {}, "meta": {}, "unread_count": 1 }

// POST /support/messages  (guests must send name and email)
{ "name": "Sam", "email": "sam@example.com", "subject": "Order help", "message": "Where is my order?" }
→ 201 { "message": "Thanks! Our support team will get back to you soon.", "data": { "id": 4 } }
```
