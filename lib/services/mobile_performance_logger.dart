import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// 运行时异常 / 卡死日志。
///
/// 旧版会实时打印滑动帧日志，容易干扰调试和性能观察；现在默认只在
/// debug/profile 的手机端写入极端卡死帧与 Flutter 异常，不再打印
/// SCROLL_START / SCROLL_END / COVER_DEFER 这类实时滑动日志。
class MobilePerformanceLogger {
  MobilePerformanceLogger._();

  static final MobilePerformanceLogger instance = MobilePerformanceLogger._();

  static const double _freezeFrameMs = 180.0;

  final List<String> _buffer = <String>[];
  final Stopwatch _clock = Stopwatch();

  File? _file;
  Timer? _flushTimer;
  bool _enabled = false;
  bool _timingsHooked = false;
  bool _errorHooked = false;
  FlutterExceptionHandler? _previousFlutterOnError;

  bool get enabled => _enabled;
  String? get logPath => _file?.path;

  Future<void> init() async {
    if (_enabled || kReleaseMode || kIsWeb) return;

    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile) return;

    _enabled = true;
    _clock.start();

    final dir = await getApplicationSupportDirectory();
    final logDir = Directory('${dir.path}${Platform.pathSeparator}logs');
    await logDir.create(recursive: true);
    _file = File('${logDir.path}${Platform.pathSeparator}mobile_runtime.log');

    await _file!.writeAsString(
      '===== Fresh Music Runtime Log ${DateTime.now().toIso8601String()} =====\n'
      'platform=$defaultTargetPlatform debug=${!kReleaseMode}\n',
      flush: true,
    );

    _hookErrors();
    _hookTimings();
  }

  void _hookErrors() {
    if (_errorHooked) return;
    _errorHooked = true;

    _previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      _previousFlutterOnError?.call(details);
      _log(
        'FLUTTER_ERROR',
        '${details.exceptionAsString()}\n${details.stack ?? ''}',
      );
    };
  }

  void _hookTimings() {
    if (_timingsHooked) return;
    _timingsHooked = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_enabled) return;

    for (final timing in timings) {
      final buildMs = _ms(timing.buildDuration);
      final rasterMs = _ms(timing.rasterDuration);
      final totalMs = _ms(timing.totalSpan);
      final worstMs = [buildMs, rasterMs, totalMs].reduce((a, b) => a > b ? a : b);

      // 只记录真正卡死级别的帧，不再记录普通滑动掉帧。
      if (worstMs < _freezeFrameMs) continue;

      _log(
        'FREEZE_FRAME',
        'frame=${worstMs.toStringAsFixed(1)}ms '
            'build=${buildMs.toStringAsFixed(1)}ms '
            'raster=${rasterMs.toStringAsFixed(1)}ms '
            'total=${totalMs.toStringAsFixed(1)}ms',
      );
    }
  }

  void handleScrollNotification(
    ScrollNotification notification, {
    required String area,
    int? itemCount,
  }) {
    // 保留空方法兼容旧调用，不再实时采集滑动日志。
  }

  void mark(String tag, String message, {bool printNow = false}) {
    // 保留空方法兼容旧调用，不再实时打印 COVER_DEFER 等日志。
  }

  void _log(String tag, String message) {
    if (!_enabled) return;
    final line = '[RUNTIME][${_clock.elapsedMilliseconds.toString().padLeft(7)} ms][$tag] $message';
    _buffer.add(line);
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_flushTimer?.isActive ?? false) return;
    _flushTimer = Timer(const Duration(milliseconds: 900), flush);
  }

  Future<void> flush() async {
    if (!_enabled || _buffer.isEmpty) return;
    final lines = List<String>.of(_buffer);
    _buffer.clear();
    try {
      await _file?.writeAsString('${lines.join('\n')}\n', mode: FileMode.append);
    } catch (_) {}
  }

  double _ms(Duration duration) => duration.inMicroseconds / 1000.0;
}
