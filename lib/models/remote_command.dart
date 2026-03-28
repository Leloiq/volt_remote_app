enum RemoteCommand {
  power,
  volumeUp,
  volumeDown,
  mute,
  channelUp,
  channelDown,
  up,
  down,
  left,
  right,
  enter,
  back,
  home,
  play,
  pause,
  fastForward,
  rewind
}

extension RemoteCommandExtension on RemoteCommand {
  String get samsungKey {
    switch (this) {
      case RemoteCommand.power: return 'KEY_POWER';
      case RemoteCommand.volumeUp: return 'KEY_VOLUP';
      case RemoteCommand.volumeDown: return 'KEY_VOLDOWN';
      case RemoteCommand.mute: return 'KEY_MUTE';
      case RemoteCommand.channelUp: return 'KEY_CHUP';
      case RemoteCommand.channelDown: return 'KEY_CHDOWN';
      case RemoteCommand.up: return 'KEY_UP';
      case RemoteCommand.down: return 'KEY_DOWN';
      case RemoteCommand.left: return 'KEY_LEFT';
      case RemoteCommand.right: return 'KEY_RIGHT';
      case RemoteCommand.enter: return 'KEY_ENTER';
      case RemoteCommand.back: return 'KEY_RETURN';
      case RemoteCommand.home: return 'KEY_HOME';
      case RemoteCommand.play: return 'KEY_PLAY';
      case RemoteCommand.pause: return 'KEY_PAUSE';
      case RemoteCommand.fastForward: return 'KEY_FF';
      case RemoteCommand.rewind: return 'KEY_REWIND';
    }
  }
}
