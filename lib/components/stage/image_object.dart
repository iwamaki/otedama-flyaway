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

  /// スケール（ピクセル→ワールド単位）
  final double scale;

  /// 物理パラメータ
  final double friction;
  final double restitution;

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
    this.scale = 0.05, // デフォルト: 20px = 1ワールド単位
    this.friction = 0.5,
    this.restitution = 0.2,
  })  : initialPosition = position.clone(),
        initialAngle = angle;

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
  }

  // --- BodyComponent 実装 ---

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 画像を読み込み
    _image = await Flame.images.load(imagePath);

    // ワールドサイズを計算
    _worldSize = Vector2(
      _image!.width * scale,
      _image!.height * scale,
    );

    // JSONから物理形状を読み込み
    await _loadPhysicsFromJson();

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
            (px - centerX) * scale,
            (py - centerY) * scale,
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

    // デバッグ: 輪郭を描画
    // _debugDrawContours(canvas);
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
