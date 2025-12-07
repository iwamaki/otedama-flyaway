# ポートフォリオにデプロイ

otedama-flyawayをポートフォリオリポジトリにコピーしてデプロイする。

## 手順

1. Flutter webをビルド（base-href付き）:
```bash
cd "/home/iwash/02_Repository/Otedama flyaway/app"
flutter build web --base-href /games/otedama-flyaway/
```

2. ポートフォリオにコピー:
```bash
cp -r "/home/iwash/02_Repository/Otedama flyaway/app/build/web/"* ~/02_Repository/PR/iwamaki-app-portfolio/public/games/otedama-flyaway/
```

3. ポートフォリオリポジトリでコミット＆プッシュ:
```bash
cd ~/02_Repository/PR/iwamaki-app-portfolio
git add -A
git commit -m "Update otedama-flyaway"
git push
```

上記の手順を順番に実行してください。
