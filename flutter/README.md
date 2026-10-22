# BirrSync Agent (Flutter)

The Android companion gateway app for **BirrSync**. It intercepts incoming payment SMS receipts (Telebirr, CBE Mobile Banking, etc.), parses financial attributes on-device, stores them in an offline-resilient SQLite buffer, and synchronizes them with the BirrSync backend using cryptographic HMAC-SHA256 authentication.

## Features

- **Autonomous SMS Interception**: Background SMS listener with fallback periodic Catch-Up audits.
- **On-Device Parsing**: Zero-latency extraction of provider, transaction ID, amounts, sender phone, and digital receipt URLs.
- **Offline Durability**: Local SQLite transaction queue ensures zero data loss during network outages.
- **Secure Synchronization**: HMAC-SHA256 signature payload authentication against the BirrSync server.
- **Foreground Service**: Built-in keep-alive foreground notification and battery optimization guidance.
