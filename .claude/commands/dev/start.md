---
description: Start Flutter development environment with logging
---

Start the Flutter development environment and output logs to flutter.log.

**Device:** Android device at 100.86.38.23:5555

**Command:**
```bash
flutter run -d 100.86.38.23:5555 2>&1 | tee flutter.log
```

Run this command in the background so logs can be monitored with `/logs`.
