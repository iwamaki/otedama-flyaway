---
description: Flutter log viewer with category filtering (usage: /logs [category] [errors])
---

Please analyze the user's request context and show relevant logs with intelligent filtering.

**Arguments parsing:**
- If `{{args}}` contains a category name: Filter by that category
- If `{{args}}` contains "errors" or "error": Filter to ERROR/WARN level only
- If no args or unclear: Show recent logs (all categories)

**Categories (from game_logger.dart):**
Physics, Audio, GameState, Input, Performance

**Log format:**
`[LEVEL] HH:mm:ss.mmm [CATEGORY] message`

**Command examples:**

1. All logs (recent):
```bash
if [ -f flutter.log ]; then
  tail -100 flutter.log | grep -E '^\[(INFO|WARN|ERROR|DEBUG|TRACE)\]'
else
  echo "No flutter.log file found. Run: flutter run 2>&1 | tee flutter.log"
fi
```

2. Filter by category:
```bash
if [ -f flutter.log ]; then
  grep '\[CATEGORY\]' flutter.log | tail -50
else
  echo "No flutter.log file found."
fi
```

3. Errors only:
```bash
if [ -f flutter.log ]; then
  grep -E '^\[(ERROR|WARN)\]' flutter.log | tail -50
else
  echo "No flutter.log file found."
fi
```

4. Errors for a specific category:
```bash
if [ -f flutter.log ]; then
  grep -E '^\[(ERROR|WARN)\]' flutter.log | grep '\[CATEGORY\]' | tail -50
else
  echo "No flutter.log file found."
fi
```

5. Live tail (follow mode):
```bash
if [ -f flutter.log ]; then
  tail -f flutter.log | grep --line-buffered -E '^\[(INFO|WARN|ERROR|DEBUG|TRACE)\]'
else
  echo "No flutter.log file found."
fi
```

**Instructions:**
1. Parse the arguments to understand what the user wants
2. If the request mentions a specific category (Physics, Audio, GameState, Input, Performance), use that filter
3. If the request is about errors, add error level filtering
4. If unclear, show recent logs from all categories
5. Always provide a summary of what you found
6. If flutter.log doesn't exist, remind user to start Flutter with: `flutter run 2>&1 | tee flutter.log`
