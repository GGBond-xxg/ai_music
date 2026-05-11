import 'package:get/get.dart';

enum PlayMode { sequence, shuffle, repeatAll, repeatOne }

extension PlayModeText on PlayMode {
  String get label {
    switch (this) {
      case PlayMode.sequence:
        return 'playMode.sequence'.tr;
      case PlayMode.shuffle:
        return 'playMode.shuffle'.tr;
      case PlayMode.repeatAll:
        return 'playMode.repeatAll'.tr;
      case PlayMode.repeatOne:
        return 'playMode.repeatOne'.tr;
    }
  }
}
