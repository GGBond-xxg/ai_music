import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Drawer-like controller for the full player sheet.
///
/// No Get route is opened while dragging. The player page is mounted once as an
/// overlay in HomePage, then translated by [sheetOffset]. This avoids repeated
/// GOING/CLOSE route logs and keeps the drag as smooth as a Drawer.
class PlayerSheetController extends GetxController {
  /// 播放页展开/收起动画时长。
  /// 想更快：260；想更慢更柔：360。
  static const Duration sheetAnimationDuration = Duration(milliseconds: 320);

  /// 播放页打开时，首页背景最大变暗程度。
  /// 推荐范围：0.08 ~ 0.18。
  static const double backdropMaxOpacity = 0.16;

  /// 播放页拖动过程中最低透明度。
  /// 越大越不透明，推荐范围：0.45 ~ 0.70。
  static const double sheetMinOpacity = 0.82;

  final isSheetMounted = false.obs;
  final isDragging = false.obs;
  final sheetOffset = 0.0.obs;

  double _screenHeight = 800;
  double _maxOffset = 800;
  Timer? _hideTimer;

  double get maxOffset => _maxOffset;

  double get openProgress {
    if (_maxOffset <= 0) return 1.0;
    final value = 1 - (sheetOffset.value / _maxOffset);
    return value.clamp(0.0, 1.0).toDouble();
  }

  void setScreenHeight(double height) {
    if (height <= 0) return;
    _screenHeight = height;
    _maxOffset = height;

    if (!isSheetMounted.value) {
      sheetOffset.value = _maxOffset;
    } else {
      sheetOffset.value = sheetOffset.value.clamp(0.0, _maxOffset).toDouble();
    }
  }

  void openByTap(BuildContext context) {
    _prepare(context);
    isDragging.value = false;

    if (!isSheetMounted.value) {
      sheetOffset.value = _maxOffset;
      isSheetMounted.value = true;

      // 不能用 scheduleMicrotask，否则 Flutter 可能还没来得及绘制底部初始位置，
      // 点击 MiniPlayer 会看起来像瞬间打开。下一帧再 expand，才能产生上滑动画。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isClosed && isSheetMounted.value) {
          expand();
        }
      });
      return;
    }

    expand();
  }

  void beginInteractiveOpen(BuildContext context) {
    _prepare(context);

    if (!isSheetMounted.value) {
      sheetOffset.value = _maxOffset;
      isSheetMounted.value = true;
    }

    isDragging.value = true;
  }

  void beginInteractiveClose(BuildContext context) {
    _prepare(context);
    if (!isSheetMounted.value) return;
    isDragging.value = true;
  }

  void updateDrag(double delta) {
    if (!isSheetMounted.value) return;
    sheetOffset.value = (sheetOffset.value + delta).clamp(0.0, _maxOffset).toDouble();
  }

  void endDrag({double velocity = 0, double? releaseY}) {
    if (!isSheetMounted.value) return;

    if (velocity < -900) {
      expand();
      return;
    }

    if (velocity > 900) {
      close();
      return;
    }

    final y = releaseY ?? sheetOffset.value;
    final threshold = _screenHeight * 0.52;
    if (y <= threshold) {
      expand();
    } else {
      close();
    }
  }

  void expand() {
    _hideTimer?.cancel();
    if (!isSheetMounted.value) isSheetMounted.value = true;
    isDragging.value = false;
    sheetOffset.value = 0;
  }

  void close() {
    if (!isSheetMounted.value) return;

    _hideTimer?.cancel();
    isDragging.value = false;
    sheetOffset.value = _maxOffset;

    _hideTimer = Timer(sheetAnimationDuration + const Duration(milliseconds: 60), () {
      if (!isDragging.value && sheetOffset.value >= _maxOffset - 1) {
        isSheetMounted.value = false;
      }
    });
  }

  void forceHide() {
    _hideTimer?.cancel();
    isDragging.value = false;
    sheetOffset.value = _maxOffset;
    isSheetMounted.value = false;
  }

  void _prepare(BuildContext context) {
    _hideTimer?.cancel();
    setScreenHeight(MediaQuery.sizeOf(context).height);
  }

  @override
  void onClose() {
    _hideTimer?.cancel();
    super.onClose();
  }
}
