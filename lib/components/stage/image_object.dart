import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'stage_object.dart';

/// 透過画像ベースのステージオブジェクト
/// 画像の輪郭が物理衝突形状になる
class ImageObject extends BodyComponent with StageObject {
  /// 画像パス
  final String imagePath;

  /// 初期位置（画像の中心）
  final Vector2 initialPosition;

  /// 初期角度
  final double initialAngle;

  /// 初期スケール（ピクセル→ワールド単位）
  final double initialScale;

  /// 物理パラメータ
  final double friction;
  final double restitution;

  /// 現在のスケール
  double _currentScale;

  /// 水平反転
  bool _flipX;

  /// 垂直反転
  bool _flipY;

  /// 読み込んだ画像
  ui.Image? _image;

  /// 抽出された輪郭（ワールド座標、中心原点）
  List<List<Vector2>> _contours = [];

  /// 画像サイズ（ワールド単位）
  Vector2 _worldSize = Vector2.zero();

  ImageObject({
    required this.imagePath,
    required Vector2 position,
    double angle = 0.0,
    double scale = 0.05, // デフォルト: 20px = 1ワールド単位
    this.friction = 0.5,
    this.restitution = 0.2,
    bool flipX = false,
    bool flipY = false,
  })  : initialPosition = position.clone(),
        initialAngle = angle,
        initialScale = scale,
        _currentScale = scale,
        _flipX = flipX,
        _flipY = flipY;

  /// JSONから生成
  factory ImageObject.fromJson(Map<String, dynamic> json) {
    return ImageObject(
      imagePath: json['imagePath'] as String? ?? '',
      position: Vector2(
        (json['x'] as num?)?.toDouble() ?? 0.0,
        (json['y'] as num?)?.toDouble() ?? 0.0,
      ),
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      scale: (json['scale'] as num?)?.toDouble() ?? 0.05,
      friction: (json['friction'] as num?)?.toDouble() ?? 0.5,
      restitution: (json['restitution'] as num?)?.toDouble() ?? 0.2,
      flipX: json['flipX'] as bool? ?? false,
      flipY: json['flipY'] as bool? ?? false,
    );
  }

  // --- StageObject 実装 ---

  @override
  String get type => 'image_object';

  @override
  Vector2 get position => body.position;

  @override
  double get angle => body.angle;

  @override
  double get scale => _currentScale;

  @override
  bool get flipX => _flipX;

  @override
  bool get flipY => _flipY;

  @override
  (Vector2 min, Vector2 max) get bounds {
    // _worldSizeがゼロの場合はデフォルトサイズを使用
    final halfW = _worldSize.x > 0 ? _worldSize.x / 2 : 1.0;
    final halfH = _worldSize.y > 0 ? _worldSize.y / 2 : 1.0;
    final pos = body.position;
    return (
      Vector2(pos.x - halfW, pos.y - halfH),
      Vector2(pos.x + halfW, pos.y + halfH),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'imagePath': imagePath,
      'x': position.x,
      'y': position.y,
      'angle': angle,
      'scale': scale,
      'friction': friction,
      'restitution': restitution,
      'flipX': flipX,
      'flipY': flipY,
    };
  }

  @override
  void applyProperties(Map<String, dynamic> props) {
    if (props.containsKey('x') || props.containsKey('y')) {
      final newX = (props['x'] as num?)?.toDouble() ?? position.x;
      final newY = (props['y'] as num?)?.toDouble() ?? position.y;
      body.setTransform(Vector2(newX, newY), body.angle);
    }
    if (props.containsKey('angle')) {
      final newAngle = (props['angle'] as num?)?.toDouble() ?? 0.0;
      body.setTransform(body.position, newAngle);
    }
    if (props.containsKey('scale')) {
      final newScale = (props['scale'] as num?)?.toDouble() ?? _currentScale;
      _setScale(newScale);
    }
    if (props.containsKey('flipX')) {
      _flipX = props['flipX'] as bool? ?? _flipX;
    }
    if (props.containsKey('flipY')) {
      _flipY = props['flipY'] as bool? ?? _flipY;
    }
  }

  /// スケールを変更（物理形状も再構築）
  void _setScale(double newScale) {
    if (newScale == _currentScale) return;
    if (newScale <= 0) return; // 無効なスケールを防ぐ

    final ratio = newScale / _currentScale;
    _currentScale = newScale;

    // ワールドサイズを更新
    _worldSize = Vector2(_worldSize.x * ratio, _worldSize.y * ratio);

    // 輪郭をスケーリング
    for (final contour in _contours) {
      for (int i = 0; i < contour.length; i++) {
        contour[i] = Vector2(contour[i].x * ratio, contour[i].y * ratio);
      }
    }

    // 物理形状を再構築
    _rebuildFixtures();
  }

  /// 水平反転を切り替え
  void toggleFlipX() {
    _flipX = !_flipX;
    // 輪郭を反転
    for (final contour in _contours) {
      // 新しいリストを作成して置き換え
      final flipped = contour.map((p) => Vector2(-p.x, p.y)).toList();
      // 頂点順序を逆にして法線を正しく保つ
      contour.clear();
      contour.addAll(flipped.reversed);
    }
    _rebuildFixtures();
  }

  /// 垂直反転を切り替え
  void toggleFlipY() {
    _flipY = !_flipY;
    // 輪郭を反転
    for (final contour in _contours) {
      // 新しいリストを作成して置き換え
      final flipped = contour.map((p) => Vector2(p.x, -p.y)).toList();
      // 頂点順序を逆にして法線を正しく保つ
      contour.clear();
      contour.addAll(flipped.reversed);
    }
    _rebuildFixtures();
  }

  /// 物理フィクスチャを再構築
  void _rebuildFixtures() {
    // bodyが初期化されていない場合はスキップ
    if (!isMounted) return;

    // 既存フィクスチャを削除
    while (body.fixtures.isNotEmpty) {
      body.destroyFixture(body.fixtures.first);
    }
    // 新しいフィクスチャを作成
    _createFixtures();
  }

  // --- BodyComponent 実装 ---

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 画像を読み込み
    _image = await Flame.images.load(imagePath);

    // ワールドサイズを計算
    _worldSize = Vector2(
      _image!.width * _currentScale,
      _image!.height * _currentScale,
    );

    // JSONから物理形状を読み込み
    await _loadPhysicsFromJson();

    // 初期反転を適用（輪郭に反映）
    if (_flipX) {
      for (final contour in _contours) {
        for (int i = 0; i < contour.length; i++) {
          contour[i] = Vector2(-contour[i].x, contour[i].y);
        }
        final reversed = contour.reversed.toList();
        contour.clear();
        contour.addAll(reversed);
      }
    }
    if (_flipY) {
      for (final contour in _contours) {
        for (int i = 0; i < contour.length; i++) {
          contour[i] = Vector2(contour[i].x, -contour[i].y);
        }
        final reversed = contour.reversed.toList();
        contour.clear();
        contour.addAll(reversed);
      }
    }

    // 物理ボディにフィクスチャを追加
    _createFixtures();
  }

  /// JSONから物理形状を読み込み
  Future<void> _loadPhysicsFromJson() async {
    // 画像名からJSONパスを生成
    final baseName = imagePath.replaceAll(RegExp(r'\.[^.]+$'), '');
    final jsonPath = 'assets/physics/$baseName.json';

    try {
      final jsonString = await rootBundle.loadString(jsonPath);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final imageWidth = (data['width'] as num).toDouble();
      final imageHeight = (data['height'] as num).toDouble();
      final centerX = imageWidth / 2;
      final centerY = imageHeight / 2;

      final rawContours = data['contours'] as List<dynamic>;

      _contours = rawContours.map((contour) {
        final points = contour as List<dynamic>;
        return points.map((p) {
          final px = (p['x'] as num).toDouble();
          final py = (p['y'] as num).toDouble();
          return Vector2(
            (px - centerX) * _currentScale,
            (py - centerY) * _currentScale,
          );
        }).toList();
      }).toList();

      debugPrint('ImageObject: Loaded ${_contours.length} contours from $jsonPath');
    } catch (e) {
      debugPrint('ImageObject: Failed to load physics JSON: $e');
      debugPrint('ImageObject: Falling back to simple box collision');
      // フォールバック：単純な矩形
      final hw = _worldSize.x / 2;
      final hh = _worldSize.y / 2;
      _contours = [
        [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]
      ];
    }
  }

  @override
  Body createBody() {
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = initialPosition
      ..angle = initialAngle;

    return world.createBody(bodyDef);
  }

  /// 使用する輪郭の最大数
  static const int maxContours = 3;

  /// 輪郭からフィクスチャを作成（ChainShape版：凹型対応）
  void _createFixtures() {
    if (_contours.isEmpty) {
      debugPrint('ImageObject: No contours found');
      return;
    }

    // 輪郭を大きい順にソート
    final sortedContours = List<List<Vector2>>.from(_contours)
      ..sort((a, b) => b.length.compareTo(a.length));

    // 上位N個の輪郭のみ使用
    final contoursToUse = sortedContours.take(maxContours).toList();

    debugPrint('ImageObject: Using ${contoursToUse.length} contours (largest: ${contoursToUse.first.length} points)');

    int createdCount = 0;
    for (final contour in contoursToUse) {
      if (contour.length < 3) continue;

      // 各点が有効かチェック
      bool isValid = true;
      for (final p in contour) {
        if (p.x.isNaN || p.y.isNaN || p.x.isInfinite || p.y.isInfinite) {
          isValid = false;
          break;
        }
      }
      if (!isValid) {
        debugPrint('ImageObject: Skipping contour with invalid points');
        continue;
      }

      try {
        // ChainShapeで輪郭を表現（凹型OK）
        final shape = ChainShape()..createLoop(contour);
        body.createFixture(FixtureDef(shape)
          ..friction = friction
          ..restitution = restitution);
        createdCount++;
      } catch (e) {
        debugPrint('ImageObject: Failed to create ChainShape: $e');
      }
    }

    debugPrint('ImageObject: Created $createdCount ChainShape fixtures');
  }

  /// 輪郭を複数のチャンクに分割（凸包で近似）
  List<List<Vector2>> _splitContourIntoChunks(List<Vector2> contour, int maxPoints) {
    if (contour.length <= maxPoints) {
      // 凸包に変換
      final hull = _convexHull(contour);
      if (hull.length >= 3) {
        return [hull];
      }
      return [];
    }

    // 輪郭を複数のセグメントに分割してそれぞれ凸包化
    final chunks = <List<Vector2>>[];
    final chunkSize = maxPoints - 1;

    for (int i = 0; i < contour.length; i += chunkSize ~/ 2) {
      final end = (i + chunkSize).clamp(0, contour.length);
      final segment = contour.sublist(i, end);

      // 中心点を追加して凸包を作る
      final center = _calculateCenter(contour);
      final withCenter = [...segment, center];
      final hull = _convexHull(withCenter);

      if (hull.length >= 3 && hull.length <= maxPoints) {
        chunks.add(hull);
      }
    }

    return chunks;
  }

  /// 凸包を計算（Graham scan）
  List<Vector2> _convexHull(List<Vector2> points) {
    if (points.length < 3) return points;

    // 最も下（Y最大）で左の点を見つける
    var start = points[0];
    for (final p in points) {
      if (p.y > start.y || (p.y == start.y && p.x < start.x)) {
        start = p;
      }
    }

    // 角度でソート
    final sorted = List<Vector2>.from(points);
    sorted.sort((a, b) {
      final diffA = a - start;
      final diffB = b - start;
      final angleA = math.atan2(diffA.y, diffA.x);
      final angleB = math.atan2(diffB.y, diffB.x);
      if (angleA != angleB) return angleA.compareTo(angleB);
      return diffA.length.compareTo(diffB.length);
    });

    // スタックベースの凸包構築
    final hull = <Vector2>[];
    for (final p in sorted) {
      while (hull.length >= 2 && _cross(hull[hull.length - 2], hull[hull.length - 1], p) <= 0) {
        hull.removeLast();
      }
      hull.add(p);
    }

    return hull;
  }

  double _cross(Vector2 o, Vector2 a, Vector2 b) {
    return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
  }

  Vector2 _calculateCenter(List<Vector2> points) {
    var sum = Vector2.zero();
    for (final p in points) {
      sum += p;
    }
    return sum / points.length.toDouble();
  }

  @override
  void render(Canvas canvas) {
    if (_image == null) return;

    // 反転のためのスケール
    canvas.save();
    canvas.scale(_flipX ? -1 : 1, _flipY ? -1 : 1);

    // 画像を描画（中心原点）
    final srcRect = Rect.fromLTWH(
      0,
      0,
      _image!.width.toDouble(),
      _image!.height.toDouble(),
    );
    final dstRect = Rect.fromCenter(
      center: Offset.zero,
      width: _worldSize.x,
      height: _worldSize.y,
    );

    canvas.drawImageRect(_image!, srcRect, dstRect, Paint());
    canvas.restore();

    // 選択中ならハイライト表示
    if (isSelected) {
      _drawSelectionHighlight(canvas);
    }

    // デバッグ: 輪郭を描画
    // _debugDrawContours(canvas);
  }

  void _drawSelectionHighlight(Canvas canvas) {
    final halfW = _worldSize.x / 2;
    final halfH = _worldSize.y / 2;
    final rect = Rect.fromLTRB(-halfW, -halfH, halfW, halfH);

    // 選択枠
    final borderPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.15;
    canvas.drawRect(rect, borderPaint);

    // コーナーハンドル
    final handleSize = 0.3;
    final handlePaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill;

    // 四隅
    canvas.drawCircle(Offset(-halfW, -halfH), handleSize, handlePaint);
    canvas.drawCircle(Offset(halfW, -halfH), handleSize, handlePaint);
    canvas.drawCircle(Offset(-halfW, halfH), handleSize, handlePaint);
    canvas.drawCircle(Offset(halfW, halfH), handleSize, handlePaint);
  }

  void _debugDrawContours(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;

    for (final contour in _contours) {
      if (contour.isEmpty) continue;
      final path = Path()..moveTo(contour.first.x, contour.first.y);
      for (int i = 1; i < contour.length; i++) {
        path.lineTo(contour[i].x, contour[i].y);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }
}

/// ImageObjectをファクトリに登録
void registerImageObjectFactory() {
  StageObjectFactory.register('image_object', (json) => ImageObject.fromJson(json));
}
