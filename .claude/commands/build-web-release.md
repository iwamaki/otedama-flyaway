Build Flutter web in release mode for testing via Cloudflare tunnel.

Steps:
1. Run `flutter build web --release` in the app directory
2. Verify the build completes successfully
3. Confirm the test server is accessible at https://dev.iwamaki.app

Note: The Python HTTP server serving build/web should already be running on port 8000. If not, start it with: `cd build/web && python3 -m http.server 8000`
