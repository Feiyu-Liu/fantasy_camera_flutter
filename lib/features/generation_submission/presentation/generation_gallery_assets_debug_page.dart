import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../theme/app_colors.dart';
import 'generation_hero_photo_view_page_options.dart';

class GenerationGalleryAssetsDebugPage extends StatefulWidget {
  const GenerationGalleryAssetsDebugPage({super.key});

  @override
  State<GenerationGalleryAssetsDebugPage> createState() =>
      _GenerationGalleryAssetsDebugPageState();
}

class _GenerationGalleryAssetsDebugPageState
    extends State<GenerationGalleryAssetsDebugPage> {
  static const List<_DebugGalleryPair> _pairs = <_DebugGalleryPair>[
    _DebugGalleryPair(
      id: 'pair-1',
      originalAsset: 'assets/origin1.jpeg',
      resultAsset: 'assets/result1.png',
    ),
    _DebugGalleryPair(
      id: 'pair-2',
      originalAsset: 'assets/origin2.png',
      resultAsset: 'assets/result2.png',
    ),
  ];

  final Map<String, PhotoViewController> _controllers =
      <String, PhotoViewController>{};
  final Map<String, Size> _imageSizes = <String, Size>{};
  final Set<String> _resolvingImageSizes = <String>{};
  late final PageController _pageController = PageController();
  int _selectedIndex = 0;
  bool _showOriginal = true;
  bool _animateSwap = false;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _resolveVisibleImageSizes();
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _pageController.dispose();
    for (final PhotoViewController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.white,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double topInset = MediaQuery.paddingOf(context).top;
          final double height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final double maxHeroHeight = (height - 196).clamp(0.0, height);
          final double heroWidth = constraints.maxWidth.clamp(
            0.0,
            maxHeroHeight * 3 / 4,
          );
          final double heroHeight = heroWidth * 4 / 3;
          final double heroViewportHeight = (heroHeight + topInset).clamp(
            0.0,
            height,
          );

          return Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    height: heroViewportHeight,
                    child: Center(
                      child: SizedBox(
                        width: heroWidth,
                        height: heroViewportHeight,
                        child: _buildHeroPager(
                          previewSize: Size(heroWidth, heroHeight),
                          viewportSize: Size(heroWidth, heroViewportHeight),
                          topPadding: topInset,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _buildBottomStrip()),
                ],
              ),
              Positioned(
                left: 14,
                top: (topInset - 4).clamp(8.0, 54.0),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(44),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.shadowBlack10,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SizedBox.square(
                      dimension: 36,
                      child: Icon(
                        CupertinoIcons.xmark,
                        color: AppColors.black,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroPager({
    required Size previewSize,
    required Size viewportSize,
    required double topPadding,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(
          color: AppColors.white,
          child: PhotoViewGallery.builder(
            key: const ValueKey<String>('generation-gallery-assets-debug-hero'),
            itemCount: _pairs.length,
            pageController: _pageController,
            customSize: previewSize,
            backgroundDecoration: const BoxDecoration(color: AppColors.white),
            onPageChanged: (int index) {
              setState(() {
                _selectedIndex = index;
                _showOriginal = true;
                _animateSwap = false;
              });
              _resolveVisibleImageSizes();
            },
            builder: (BuildContext context, int index) {
              final _DebugGalleryPair pair = _pairs[index];
              return _pageOptions(
                pair: pair,
                previewSize: previewSize,
                viewportSize: viewportSize,
                topPadding: topPadding,
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 18,
          child: Center(
            child: _DebugHeroToolbar(
              showOriginal: _showOriginal,
              onToggle: _toggleImage,
              onAnimate: _playSwapAnimation,
            ),
          ),
        ),
      ],
    );
  }

  PhotoViewGalleryPageOptions _pageOptions({
    required _DebugGalleryPair pair,
    required Size previewSize,
    required Size viewportSize,
    required double topPadding,
  }) {
    final PhotoViewController controller = _controllers.putIfAbsent(
      pair.id,
      PhotoViewController.new,
    );
    final String asset = _showOriginal ? pair.originalAsset : pair.resultAsset;
    final AssetImage imageProvider = AssetImage(asset);
    final Size childSize = _childSizeForAsset(asset, previewSize);
    final Alignment basePosition = _basePositionForAsset(
      asset: asset,
      previewSize: previewSize,
      viewportSize: viewportSize,
      topPadding: topPadding,
    );

    if (_animateSwap && pair == _pairs[_selectedIndex]) {
      return generationHeroBlurredSwapPageOptions(
        originalImageProvider: AssetImage(pair.originalAsset),
        replacementImageProvider: AssetImage(pair.resultAsset),
        childSize: _childSizeForAsset(pair.resultAsset, previewSize),
        controller: controller,
        basePosition: _basePositionForAsset(
          asset: pair.resultAsset,
          previewSize: previewSize,
          viewportSize: viewportSize,
          topPadding: topPadding,
        ),
        semanticLabel: pair.resultAsset,
        replacementMarkerKey: ValueKey<String>(
          'generation-gallery-assets-debug-result-${pair.id}',
        ),
        originalErrorBuilder: _imageErrorBuilder(pair.originalAsset),
        replacementErrorBuilder: _imageErrorBuilder(pair.resultAsset),
      );
    }

    return generationHeroImagePageOptions(
      imageProvider: imageProvider,
      childSize: childSize,
      controller: controller,
      basePosition: basePosition,
      semanticLabel: asset,
      markerKey: ValueKey<String>('generation-gallery-assets-debug-$asset'),
      errorBuilder: _imageErrorBuilder(asset),
    );
  }

  ImageErrorWidgetBuilder _imageErrorBuilder(String asset) {
    return (BuildContext context, Object error, StackTrace? stackTrace) {
      debugPrint(
        '[GenerationGalleryAssetsDebug] image load failure asset=$asset error=$error',
      );
      return Center(
        child: Text(
          'Failed to load $asset',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPlaceholder,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    };
  }

  Widget _buildBottomStrip() {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.white),
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 12, 0, 10 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'RELATED MOMENTS',
                style: TextStyle(
                  color: AppColors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _pairs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (BuildContext context, int index) {
                  final _DebugGalleryPair pair = _pairs[index];
                  final bool selected = index == _selectedIndex;
                  return _DebugMomentTile(
                    pair: pair,
                    selected: selected,
                    onTap: () => _selectPair(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectPair(int index) {
    setState(() {
      _selectedIndex = index;
      _showOriginal = true;
      _animateSwap = false;
    });
    unawaited(
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
    _resolveVisibleImageSizes();
  }

  void _toggleImage() {
    _animationTimer?.cancel();
    setState(() {
      _animateSwap = false;
      _showOriginal = !_showOriginal;
    });
    _resolveVisibleImageSizes();
  }

  void _playSwapAnimation() {
    _animationTimer?.cancel();
    setState(() {
      _showOriginal = false;
      _animateSwap = true;
    });
    _animationTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _animateSwap = false;
      });
    });
  }

  Size _childSizeForAsset(String asset, Size fallback) {
    final Size? imageSize = _imageSizes[asset];
    if (imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
      return imageSize;
    }
    return fallback.width > 0 && fallback.height > 0
        ? fallback
        : const Size(1, 1);
  }

  Alignment _basePositionForAsset({
    required String asset,
    required Size previewSize,
    required Size viewportSize,
    required double topPadding,
  }) {
    final Size? imageSize = _imageSizes[asset];
    if (imageSize == null ||
        imageSize.width <= 0 ||
        imageSize.height <= 0 ||
        viewportSize.height <= 0 ||
        previewSize.height <= 0 ||
        topPadding <= 0) {
      return Alignment.center;
    }

    final double containedScale =
        previewSize.width / imageSize.width <
            previewSize.height / imageSize.height
        ? previewSize.width / imageSize.width
        : previewSize.height / imageSize.height;
    final double displayedImageHeight = imageSize.height * containedScale;
    final double extraSpace = viewportSize.height - displayedImageHeight;
    if (extraSpace <= 0) {
      return Alignment.center;
    }

    final double defaultTop =
        topPadding + (previewSize.height - displayedImageHeight) / 2;
    final double targetAlignmentY = (defaultTop / extraSpace) * 2 - 1;
    return Alignment(0, targetAlignmentY.clamp(-1.0, 1.0));
  }

  void _resolveVisibleImageSizes() {
    final _DebugGalleryPair pair = _pairs[_selectedIndex];
    _resolveImageSize(pair.originalAsset);
    _resolveImageSize(pair.resultAsset);
  }

  void _resolveImageSize(String asset) {
    if (_imageSizes.containsKey(asset) ||
        _resolvingImageSizes.contains(asset)) {
      return;
    }
    _resolvingImageSizes.add(asset);
    final ImageStream stream = AssetImage(
      asset,
    ).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        stream.removeListener(listener);
        final Size imageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _resolvingImageSizes.remove(asset);
          _imageSizes[asset] = imageSize;
        });
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!mounted) {
          return;
        }
        setState(() {
          _resolvingImageSizes.remove(asset);
        });
      },
    );
    stream.addListener(listener);
  }
}

class _DebugGalleryPair {
  const _DebugGalleryPair({
    required this.id,
    required this.originalAsset,
    required this.resultAsset,
  });

  final String id;
  final String originalAsset;
  final String resultAsset;
}

class _DebugMomentTile extends StatelessWidget {
  const _DebugMomentTile({
    required this.pair,
    required this.selected,
    required this.onTap,
  });

  final _DebugGalleryPair pair;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected
                        ? AppColors.focusYellow
                        : AppColors.borderSubtle,
                    width: selected ? 4 : 1,
                  ),
                ),
                child: ClipRect(
                  child: Image.asset(
                    pair.resultAsset,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pair.id.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.black,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugHeroToolbar extends StatelessWidget {
  const _DebugHeroToolbar({
    required this.showOriginal,
    required this.onToggle,
    required this.onAnimate,
  });

  final bool showOriginal;
  final VoidCallback onToggle;
  final VoidCallback onAnimate;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(color: AppColors.blackOverlay(0.42)),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _DebugToolbarButton(
                  icon: showOriginal ? LucideIcons.image : LucideIcons.sparkles,
                  onPressed: onToggle,
                ),
                _DebugToolbarButton(
                  icon: LucideIcons.play,
                  onPressed: onAnimate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DebugToolbarButton extends StatelessWidget {
  const _DebugToolbarButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: SizedBox.square(
        dimension: 36,
        child: Icon(icon, color: AppColors.white, size: 18),
      ),
    );
  }
}
