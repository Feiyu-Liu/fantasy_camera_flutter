import 'package:flutter/widgets.dart';
import 'package:my_ui/my_ui.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

PhotoViewGalleryPageOptions generationHeroImagePageOptions({
  required ImageProvider imageProvider,
  required Size childSize,
  required PhotoViewController controller,
  required Alignment basePosition,
  required String semanticLabel,
  required Key markerKey,
  required ImageErrorWidgetBuilder errorBuilder,
}) {
  return _generationHeroPageOptions(
    controller: controller,
    childSize: childSize,
    basePosition: basePosition,
    semanticLabel: semanticLabel,
    child: _GenerationHeroImageCanvas(
      size: childSize,
      imageProvider: imageProvider,
      markerKey: markerKey,
      errorBuilder: errorBuilder,
    ),
  );
}

PhotoViewGalleryPageOptions generationHeroBokehSwapPageOptions({
  required ImageProvider originalImageProvider,
  required ImageProvider replacementImageProvider,
  required Size childSize,
  required PhotoViewController controller,
  required Alignment basePosition,
  required String semanticLabel,
  required Key replacementMarkerKey,
  required ImageErrorWidgetBuilder originalErrorBuilder,
  required ImageErrorWidgetBuilder replacementErrorBuilder,
}) {
  return _generationHeroPageOptions(
    controller: controller,
    childSize: childSize,
    basePosition: basePosition,
    semanticLabel: semanticLabel,
    child: _GenerationHeroImageCanvas(
      size: childSize,
      markerKey: replacementMarkerKey,
      child: BokehImageSwapTransition(
        original: _GenerationHeroImage(
          imageProvider: originalImageProvider,
          errorBuilder: originalErrorBuilder,
        ),
        replacement: _GenerationHeroImage(
          imageProvider: replacementImageProvider,
          errorBuilder: replacementErrorBuilder,
        ),
        showReplacement: true,
        animateInitialReplacement: true,
      ),
    ),
  );
}

PhotoViewGalleryPageOptions _generationHeroPageOptions({
  required Widget child,
  required Size childSize,
  required PhotoViewController controller,
  required Alignment basePosition,
  required String semanticLabel,
}) {
  return PhotoViewGalleryPageOptions.customChild(
    child: child,
    childSize: childSize,
    semanticLabel: semanticLabel,
    controller: controller,
    initialScale: PhotoViewComputedScale.contained,
    minScale: PhotoViewComputedScale.contained,
    maxScale: PhotoViewComputedScale.covered * 3,
    basePosition: basePosition,
    filterQuality: FilterQuality.none,
  );
}

class _GenerationHeroImageCanvas extends StatelessWidget {
  const _GenerationHeroImageCanvas({
    required this.size,
    required this.markerKey,
    this.imageProvider,
    this.errorBuilder,
    this.child,
  }) : assert(child != null || (imageProvider != null && errorBuilder != null));

  final Size size;
  final Key markerKey;
  final ImageProvider? imageProvider;
  final ImageErrorWidgetBuilder? errorBuilder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          child ??
              _GenerationHeroImage(
                imageProvider: imageProvider!,
                errorBuilder: errorBuilder!,
              ),
          IgnorePointer(child: SizedBox.shrink(key: markerKey)),
        ],
      ),
    );
  }
}

class _GenerationHeroImage extends StatelessWidget {
  const _GenerationHeroImage({
    required this.imageProvider,
    required this.errorBuilder,
  });

  final ImageProvider imageProvider;
  final ImageErrorWidgetBuilder errorBuilder;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: imageProvider,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: errorBuilder,
    );
  }
}
