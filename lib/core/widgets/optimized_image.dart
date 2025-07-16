import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/core/helper/services/logging_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Configuration d'optimisation d'image
class ImageOptimizationConfig {
  final int maxWidth;
  final int maxHeight;
  final int quality;
  final bool enableMemoryCache;
  final bool enableDiskCache;
  final Duration cacheDuration;

  const ImageOptimizationConfig({
    this.maxWidth = 800,
    this.maxHeight = 600,
    this.quality = 85,
    this.enableMemoryCache = true,
    this.enableDiskCache = true,
    this.cacheDuration = const Duration(days: 7),
  });

  /// Configuration pour les vignettes
  static const ImageOptimizationConfig thumbnail = ImageOptimizationConfig(
    maxWidth: 200,
    maxHeight: 150,
    quality: 75,
  );

  /// Configuration pour les images de taille moyenne
  static const ImageOptimizationConfig medium = ImageOptimizationConfig(
    maxWidth: 400,
    maxHeight: 300,
    quality: 80,
  );

  /// Configuration pour les images pleine résolution (limitée)
  static const ImageOptimizationConfig fullSize = ImageOptimizationConfig(
    maxWidth: 1200,
    maxHeight: 900,
    quality: 90,
  );
}

/// Widget d'image optimisée avec lazy loading et limitation de résolution
class OptimizedImage extends StatefulWidget {
  final String? imageUrl;
  final String? assetPath;
  final Uint8List? bytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ImageOptimizationConfig config;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableLazyLoading;
  final VoidCallback? onImageLoaded;
  final VoidCallback? onImageError;

  const OptimizedImage({
    super.key,
    this.imageUrl,
    this.assetPath,
    this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.config = const ImageOptimizationConfig(),
    this.placeholder,
    this.errorWidget,
    this.enableLazyLoading = true,
    this.onImageLoaded,
    this.onImageError,
  }) : assert(
         imageUrl != null || assetPath != null || bytes != null,
         'Au moins une source d\'image doit être fournie',
       );

  @override
  State<OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<OptimizedImage> {
  bool _isInView = false;
  bool _hasLoadStarted = false;
  late final String _imageId;

  @override
  void initState() {
    super.initState();
    _imageId = _generateImageId();
    
    if (!widget.enableLazyLoading) {
      _hasLoadStarted = true;
      _isInView = true;
    }
  }

  String _generateImageId() {
    if (widget.imageUrl != null) return widget.imageUrl!.hashCode.toString();
    if (widget.assetPath != null) return widget.assetPath!.hashCode.toString();
    if (widget.bytes != null) return widget.bytes!.hashCode.toString();
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Widget build(BuildContext context) {
    return widget.enableLazyLoading
        ? _buildWithLazyLoading()
        : _buildImage();
  }

  Widget _buildWithLazyLoading() {
    return VisibilityDetector(
      key: ValueKey(_imageId),
      onVisibilityChanged: (VisibilityInfo info) {
        if (info.visibleFraction > 0.1 && !_hasLoadStarted) {
          setState(() {
            _isInView = true;
            _hasLoadStarted = true;
          });
        }
      },
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    if (widget.enableLazyLoading && !_isInView) {
      return _buildPlaceholder();
    }

    if (widget.bytes != null) {
      return _buildMemoryImage();
    }

    if (widget.assetPath != null) {
      return _buildAssetImage();
    }

    if (widget.imageUrl != null) {
      return _buildNetworkImage();
    }

    return _buildErrorWidget();
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) {
        _onImageError();
        return _buildErrorWidget();
      },
      imageBuilder: (context, imageProvider) => _buildOptimizedImageWidget(imageProvider),
      cacheManager: widget.config.enableDiskCache 
          ? DefaultCacheManager() 
          : null,
      memCacheWidth: widget.config.maxWidth,
      memCacheHeight: widget.config.maxHeight,
    );
  }

  Widget _buildAssetImage() {
    return Image.asset(
      widget.assetPath!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.config.maxWidth,
      cacheHeight: widget.config.maxHeight,
      errorBuilder: (context, error, stackTrace) {
        _onImageError();
        return _buildErrorWidget();
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null) {
          _onImageLoaded();
        }
        return child;
      },
    );
  }

  Widget _buildMemoryImage() {
    return FutureBuilder<Uint8List>(
      future: _optimizeImageBytes(widget.bytes!),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onImageLoaded();
          });
          
          return Image.memory(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            cacheWidth: widget.config.maxWidth,
            cacheHeight: widget.config.maxHeight,
          );
        }

        if (snapshot.hasError) {
          _onImageError();
          return _buildErrorWidget();
        }

        return _buildPlaceholder();
      },
    );
  }

  Widget _buildOptimizedImageWidget(ImageProvider imageProvider) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onImageLoaded();
    });

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: imageProvider,
          fit: widget.fit,
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ?? Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 24,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 4),
            if (widget.enableLazyLoading && !_hasLoadStarted)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ?? Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 24,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              'Erreur',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _optimizeImageBytes(Uint8List originalBytes) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: widget.config.maxWidth,
        targetHeight: widget.config.maxHeight,
      );
      
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
      
      return originalBytes;
    } catch (e) {
      LoggingService.instance.warning(
        'OptimizedImage',
        'Erreur optimisation image',
        data: {'error': e.toString()},
      );
      return originalBytes;
    }
  }

  void _onImageLoaded() {
    widget.onImageLoaded?.call();
    
    MonitoringService.instance.recordMetric(
      'image_loaded',
      1,
      tags: {
        'source': _getImageSource(),
        'lazy_loading': widget.enableLazyLoading.toString(),
      },
    );
  }

  void _onImageError() {
    widget.onImageError?.call();
    
    LoggingService.instance.warning(
      'OptimizedImage',
      'Erreur chargement image',
      data: {
        'source': _getImageSource(),
        'image_id': _imageId,
      },
    );
  }

  String _getImageSource() {
    if (widget.imageUrl != null) return 'network';
    if (widget.assetPath != null) return 'asset';
    if (widget.bytes != null) return 'memory';
    return 'unknown';
  }
}

// lib/core/widgets/optimized_list_view.dart
/// ListView optimisée avec lazy loading intelligent
class OptimizedListView extends StatefulWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final Axis scrollDirection;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final double? itemExtent;
  final int preloadItemCount;
  final VoidCallback? onEndReached;
  final double endReachThreshold;

  const OptimizedListView({
    super.key,
    required this.children,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.itemExtent,
    this.preloadItemCount = 5,
    this.onEndReached,
    this.endReachThreshold = 0.8,
  });

  @override
  State<OptimizedListView> createState() => _OptimizedListViewState();
}

class _OptimizedListViewState extends State<OptimizedListView> {
  late ScrollController _scrollController;
  final Set<int> _loadedItems = {};
  bool _hasReachedEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
    
    // Précharger les premiers éléments
    _preloadInitialItems();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _preloadInitialItems() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (int i = 0; i < widget.preloadItemCount && i < widget.children.length; i++) {
        _loadedItems.add(i);
      }
      if (mounted) setState(() {});
    });
  }

  void _onScroll() {
    if (!mounted) return;
    
    final scrollOffset = _scrollController.offset;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    
    // Détecter la fin de liste
    if (!_hasReachedEnd && 
        scrollOffset >= maxScrollExtent * widget.endReachThreshold) {
      _hasReachedEnd = true;
      widget.onEndReached?.call();
    }
    
    // Calculer les éléments visibles
    _updateVisibleItems();
  }

  void _updateVisibleItems() {
    if (!mounted || widget.itemExtent == null) return;
    
    final scrollOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    
    final firstVisibleIndex = (scrollOffset / widget.itemExtent!).floor();
    final lastVisibleIndex = ((scrollOffset + viewportHeight) / widget.itemExtent!).ceil();
    
    // Précharger quelques éléments avant et après
    final startIndex = (firstVisibleIndex - widget.preloadItemCount).clamp(0, widget.children.length);
    final endIndex = (lastVisibleIndex + widget.preloadItemCount).clamp(0, widget.children.length);
    
    bool shouldUpdate = false;
    for (int i = startIndex; i < endIndex; i++) {
      if (!_loadedItems.contains(i)) {
        _loadedItems.add(i);
        shouldUpdate = true;
      }
    }
    
    if (shouldUpdate && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      scrollDirection: widget.scrollDirection,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: widget.children.length,
      itemExtent: widget.itemExtent,
      itemBuilder: (context, index) {
        // Lazy loading : ne charger que les éléments nécessaires
        if (!_loadedItems.contains(index)) {
          return _buildPlaceholderItem();
        }
        
        return widget.children[index];
      },
    );
  }

  Widget _buildPlaceholderItem() {
    return Container(
      height: widget.itemExtent ?? 60,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
          ),
        ),
      ),
    );
  }
}

// lib/core/services/image_cache_service.dart
/// Service de gestion du cache d'images optimisé
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  static ImageCacheService get instance => _instance;
  
  ImageCacheService._internal();

  static const int _maxCacheSize = 100 * 1024 * 1024; // 100 MB
  static const int _maxItemCount = 200;

  /// Initialise le service de cache d'images
  void initialize() {
    // Configuration du cache d'images Flutter
    PaintingBinding.instance.imageCache.maximumSize = _maxItemCount;
    PaintingBinding.instance.imageCache.maximumSizeBytes = _maxCacheSize;
    
    LoggingService.instance.info(
      'ImageCacheService',
      'Cache d\'images initialisé',
      data: {
        'max_size_mb': (_maxCacheSize / (1024 * 1024)).toString(),
        'max_items': _maxItemCount.toString(),
      },
    );
  }

  /// Nettoie le cache d'images
  void clearCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    LoggingService.instance.info('ImageCacheService', 'Cache d\'images nettoyé');
    
    MonitoringService.instance.recordMetric(
      'image_cache_cleared',
      1,
    );
  }

  /// Obtient les statistiques du cache
  Map<String, dynamic> getCacheStats() {
    final cache = PaintingBinding.instance.imageCache;
    
    return {
      'current_size_bytes': cache.currentSizeBytes,
      'current_size_mb': (cache.currentSizeBytes / (1024 * 1024)).toStringAsFixed(2),
      'current_count': cache.currentSize,
      'live_images': cache.liveImageCount,
      'pending_images': cache.pendingImageCount,
      'max_size_bytes': cache.maximumSizeBytes,
      'max_count': cache.maximumSize,
    };
  }

  /// Précharge une liste d'images
  Future<void> preloadImages(List<String> imageUrls, BuildContext context) async {
    if (imageUrls.isEmpty) return;
    
    try {
      final futures = imageUrls.take(10).map((url) async {
        try {
          await precacheImage(
            CachedNetworkImageProvider(url),
            context,
            size: const Size(400, 300),
          );
        } catch (e) {
          LoggingService.instance.warning(
            'ImageCacheService',
            'Erreur préchargement image',
            data: {'url': url, 'error': e.toString()},
          );
        }
      });
      
      await Future.wait(futures);
      
      LoggingService.instance.info(
        'ImageCacheService',
        'Images préchargées',
        data: {'count': imageUrls.length.toString()},
      );
      
    } catch (e) {
      LoggingService.instance.error(
        'ImageCacheService',
        'Erreur préchargement images',
        data: {'error': e.toString()},
      );
    }
  }
}