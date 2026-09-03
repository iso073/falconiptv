enum PlayerAspectRatio {
  widescreen,
  standard,
  fit,
}

extension PlayerAspectRatioLabel on PlayerAspectRatio {
  String get label {
    return switch (this) {
      PlayerAspectRatio.widescreen => '16:9',
      PlayerAspectRatio.standard => '4:3',
      PlayerAspectRatio.fit => 'Fit',
    };
  }

  PlayerAspectRatio get next {
    return switch (this) {
      PlayerAspectRatio.widescreen => PlayerAspectRatio.standard,
      PlayerAspectRatio.standard => PlayerAspectRatio.fit,
      PlayerAspectRatio.fit => PlayerAspectRatio.widescreen,
    };
  }

  PlayerAspectRatio get previous {
    return switch (this) {
      PlayerAspectRatio.widescreen => PlayerAspectRatio.fit,
      PlayerAspectRatio.standard => PlayerAspectRatio.widescreen,
      PlayerAspectRatio.fit => PlayerAspectRatio.standard,
    };
  }
}
