// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart' as _svg;
import 'package:vector_graphics/vector_graphics.dart' as _vg;

class $AssetsAnimationsGen {
  const $AssetsAnimationsGen();

  /// File path: assets/animations/.gitkeep
  String get aGitkeep => 'assets/animations/.gitkeep';

  /// List of all assets
  List<String> get values => [aGitkeep];
}

class $AssetsFontsGen {
  const $AssetsFontsGen();

  /// File path: assets/fonts/PlusJakartaSans-Bold.ttf
  String get plusJakartaSansBold => 'assets/fonts/PlusJakartaSans-Bold.ttf';

  /// File path: assets/fonts/PlusJakartaSans-Medium.ttf
  String get plusJakartaSansMedium => 'assets/fonts/PlusJakartaSans-Medium.ttf';

  /// File path: assets/fonts/PlusJakartaSans-Regular.ttf
  String get plusJakartaSansRegular =>
      'assets/fonts/PlusJakartaSans-Regular.ttf';

  /// File path: assets/fonts/PlusJakartaSans-SemiBold.ttf
  String get plusJakartaSansSemiBold =>
      'assets/fonts/PlusJakartaSans-SemiBold.ttf';

  /// List of all assets
  List<String> get values => [
        plusJakartaSansBold,
        plusJakartaSansMedium,
        plusJakartaSansRegular,
        plusJakartaSansSemiBold
      ];
}

class $AssetsIconGen {
  const $AssetsIconGen();

  /// File path: assets/icon/Bookings.svg
  SvgGenImage get bookings => const SvgGenImage('assets/icon/Bookings.svg');

  /// File path: assets/icon/Home.svg
  SvgGenImage get home => const SvgGenImage('assets/icon/Home.svg');

  /// File path: assets/icon/Notif.svg
  SvgGenImage get notif => const SvgGenImage('assets/icon/Notif.svg');

  /// File path: assets/icon/add_book.svg
  SvgGenImage get addBook => const SvgGenImage('assets/icon/add_book.svg');

  /// File path: assets/icon/cinema_room.svg
  SvgGenImage get cinemaRoom =>
      const SvgGenImage('assets/icon/cinema_room.svg');

  /// File path: assets/icon/conference.svg
  SvgGenImage get conference => const SvgGenImage('assets/icon/conference.svg');

  /// File path: assets/icon/guests.svg
  SvgGenImage get guests => const SvgGenImage('assets/icon/guests.svg');

  /// File path: assets/icon/icon.png
  AssetGenImage get icon => const AssetGenImage('assets/icon/icon.png');

  /// File path: assets/icon/icon_foreground.png
  AssetGenImage get iconForeground =>
      const AssetGenImage('assets/icon/icon_foreground.png');

  /// File path: assets/icon/location.svg
  SvgGenImage get location => const SvgGenImage('assets/icon/location.svg');

  /// File path: assets/icon/profile.svg
  SvgGenImage get profile => const SvgGenImage('assets/icon/profile.svg');

  /// List of all assets
  List<dynamic> get values => [
        bookings,
        home,
        notif,
        addBook,
        cinemaRoom,
        conference,
        guests,
        icon,
        iconForeground,
        location,
        profile
      ];
}

class $AssetsIconsGen {
  const $AssetsIconsGen();

  /// File path: assets/icons/.gitkeep
  String get aGitkeep => 'assets/icons/.gitkeep';

  /// List of all assets
  List<String> get values => [aGitkeep];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/.gitkeep
  String get aGitkeep => 'assets/images/.gitkeep';

  /// File path: assets/images/Booking Details.png
  AssetGenImage get bookingDetails =>
      const AssetGenImage('assets/images/Booking Details.png');

  /// File path: assets/images/Home_bg.png
  AssetGenImage get homeBg => const AssetGenImage('assets/images/Home_bg.png');

  /// File path: assets/images/My Bookings.png
  AssetGenImage get myBookings =>
      const AssetGenImage('assets/images/My Bookings.png');

  /// File path: assets/images/Splash Screen.png
  AssetGenImage get splashScreen =>
      const AssetGenImage('assets/images/Splash Screen.png');

  /// File path: assets/images/Tab Screen.png
  AssetGenImage get tabScreen =>
      const AssetGenImage('assets/images/Tab Screen.png');

  /// File path: assets/images/adduser.png
  AssetGenImage get adduser => const AssetGenImage('assets/images/adduser.png');

  /// File path: assets/images/filter.svg
  SvgGenImage get filter => const SvgGenImage('assets/images/filter.svg');

  /// File path: assets/images/roombooking.png
  AssetGenImage get roombooking =>
      const AssetGenImage('assets/images/roombooking.png');

  /// List of all assets
  List<dynamic> get values => [
        aGitkeep,
        bookingDetails,
        homeBg,
        myBookings,
        splashScreen,
        tabScreen,
        adduser,
        filter,
        roombooking
      ];
}

class $AssetsLogoGen {
  const $AssetsLogoGen();

  /// File path: assets/logo/mekansm.png
  AssetGenImage get mekansm => const AssetGenImage('assets/logo/mekansm.png');

  /// File path: assets/logo/splash.png
  AssetGenImage get splash => const AssetGenImage('assets/logo/splash.png');

  /// List of all assets
  List<AssetGenImage> get values => [mekansm, splash];
}

class Assets {
  const Assets._();

  static const $AssetsAnimationsGen animations = $AssetsAnimationsGen();
  static const $AssetsFontsGen fonts = $AssetsFontsGen();
  static const $AssetsIconGen icon = $AssetsIconGen();
  static const $AssetsIconsGen icons = $AssetsIconsGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
  static const $AssetsLogoGen logo = $AssetsLogoGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({
    AssetBundle? bundle,
    String? package,
  }) {
    return AssetImage(
      _assetName,
      bundle: bundle,
      package: package,
    );
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}

class SvgGenImage {
  const SvgGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
  }) : _isVecFormat = false;

  const SvgGenImage.vec(
    this._assetName, {
    this.size,
    this.flavors = const {},
  }) : _isVecFormat = true;

  final String _assetName;
  final Size? size;
  final Set<String> flavors;
  final bool _isVecFormat;

  _svg.SvgPicture svg({
    Key? key,
    bool matchTextDirection = false,
    AssetBundle? bundle,
    String? package,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry alignment = Alignment.center,
    bool allowDrawingOutsideViewBox = false,
    WidgetBuilder? placeholderBuilder,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    _svg.SvgTheme? theme,
    _svg.ColorMapper? colorMapper,
    ColorFilter? colorFilter,
    Clip clipBehavior = Clip.hardEdge,
    @deprecated Color? color,
    @deprecated BlendMode colorBlendMode = BlendMode.srcIn,
    @deprecated bool cacheColorFilter = false,
  }) {
    final _svg.BytesLoader loader;
    if (_isVecFormat) {
      loader = _vg.AssetBytesLoader(
        _assetName,
        assetBundle: bundle,
        packageName: package,
      );
    } else {
      loader = _svg.SvgAssetLoader(
        _assetName,
        assetBundle: bundle,
        packageName: package,
        theme: theme,
        colorMapper: colorMapper,
      );
    }
    return _svg.SvgPicture(
      loader,
      key: key,
      matchTextDirection: matchTextDirection,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      allowDrawingOutsideViewBox: allowDrawingOutsideViewBox,
      placeholderBuilder: placeholderBuilder,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: excludeFromSemantics,
      colorFilter: colorFilter ??
          (color == null ? null : ColorFilter.mode(color, colorBlendMode)),
      clipBehavior: clipBehavior,
      cacheColorFilter: cacheColorFilter,
    );
  }

  String get path => _assetName;

  String get keyName => _assetName;
}
