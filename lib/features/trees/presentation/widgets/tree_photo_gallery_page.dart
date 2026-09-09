import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/growth_entry.dart';
import '../../domain/entities/tree.dart';
import '../providers/trees_provider.dart';

/// Visor unificat de galeria d'imatges d'arbres amb zoom interactiu,
/// navegació per carrusel, gestió de foto principal i panell de metadades.
class TreePhotoGalleryPage extends ConsumerStatefulWidget {
  final List<GrowthEntry> entries;
  final int initialIndex;
  final Tree tree;
  final bool canManagePhotos;

  const TreePhotoGalleryPage({
    super.key,
    required this.entries,
    required this.initialIndex,
    required this.tree,
    this.canManagePhotos = true,
  });

  @override
  ConsumerState<TreePhotoGalleryPage> createState() =>
      _TreePhotoGalleryPageState();
}

class _TreePhotoGalleryPageState extends ConsumerState<TreePhotoGalleryPage> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isZoomed = false;
  final Map<int, GlobalKey<_ZoomablePhotoViewState>> _photoKeys = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.entries.isEmpty ? 0 : widget.entries.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  GrowthEntry get _currentEntry => widget.entries[_currentIndex];

  GlobalKey<_ZoomablePhotoViewState> _getKeyForIndex(int index) {
    return _photoKeys.putIfAbsent(
      index,
      () => GlobalKey<_ZoomablePhotoViewState>(),
    );
  }

  void _onZoomChanged(bool isZoomed) {
    if (_isZoomed != isZoomed) {
      setState(() {
        _isZoomed = isZoomed;
      });
    }
  }

  void _toggleZoom() {
    _getKeyForIndex(_currentIndex).currentState?.toggleZoom();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Cap imatge disponible',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final isMainPhoto = widget.tree.photoUrl == _currentEntry.photoUrl ||
        _currentEntry.id == 'MAIN_PHOTO';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.entries.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          // Botó de Zoom interactiu
          IconButton(
            icon: Icon(_isZoomed ? Icons.zoom_out : Icons.zoom_in),
            tooltip: _isZoomed ? 'Restablir zoom (1x)' : 'Apropar (2.5x)',
            onPressed: _toggleZoom,
          ),
          if (widget.canManagePhotos && !isMainPhoto)
            IconButton(
              icon: const Icon(Icons.wallpaper),
              tooltip: 'Establir com a foto principal',
              onPressed: _setAsMainPhoto,
            ),
          if (widget.canManagePhotos && _currentEntry.id != 'MAIN_PHOTO')
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Eliminar',
              onPressed: _deletePhoto,
            ),
        ],
      ),
      body: Column(
        children: [
          // Àrea central de la foto amb PageView i controls
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  physics: _isZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  itemCount: widget.entries.length,
                  onPageChanged: (index) {
                    _getKeyForIndex(_currentIndex).currentState?.resetZoom();
                    setState(() {
                      _currentIndex = index;
                      _isZoomed = false;
                    });
                  },
                  itemBuilder: (context, index) {
                    final entry = widget.entries[index];
                    return _ZoomablePhotoView(
                      key: _getKeyForIndex(index),
                      photoUrl: entry.photoUrl,
                      onZoomChanged: _onZoomChanged,
                    );
                  },
                ),
                // Botons de navegació lateral (només quan no s'està fent zoom)
                if (widget.entries.length > 1 && !_isZoomed)
                  Positioned.fill(
                    child: Row(
                      children: [
                        if (_currentIndex > 0)
                          GestureDetector(
                            onTap: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              width: 60,
                              color: Colors.transparent,
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.chevron_left,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 60),
                        const Spacer(),
                        if (_currentIndex < widget.entries.length - 1)
                          GestureDetector(
                            onTap: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              width: 60,
                              color: Colors.transparent,
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 60),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Panell inferior de metadades
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: Colors.black87,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(_currentEntry.date),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (_currentEntry.healthStatus.isNotEmpty)
                      Chip(
                        label: Text(
                          _currentEntry.healthStatus,
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: Colors.indigo.shade100,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                if (_currentEntry.observations.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _currentEntry.observations,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (_currentEntry.height > 0 ||
                    _currentEntry.trunkDiameter > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (_currentEntry.height > 0)
                        Text(
                          'Alçada: ${_currentEntry.height.toStringAsFixed(0)} cm',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      if (_currentEntry.height > 0 &&
                          _currentEntry.trunkDiameter > 0)
                        const Text(
                          ' • ',
                          style: TextStyle(color: Colors.white60),
                        ),
                      if (_currentEntry.trunkDiameter > 0)
                        Text(
                          'Diàmetre: ${_currentEntry.trunkDiameter.toStringAsFixed(1)} cm',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setAsMainPhoto() async {
    final currentMain = widget.tree.photoUrl;

    if (currentMain != null && currentMain != _currentEntry.photoUrl) {
      try {
        final entries = await ref
            .read(treesRepositoryProvider)
            .getGrowthEntriesStream(widget.tree.id)
            .first;

        final exists = entries.any((e) => e.photoUrl == currentMain);

        if (!exists && mounted) {
          final shouldSave = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Guardar foto actual?'),
              content: const Text(
                'La foto principal actual no existeix al diari visual. '
                'Vols guardar-la a l\'historial abans de substituir-la?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('NO, PERDRE-LA'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('SÍ, GUARDAR-LA'),
                ),
              ],
            ),
          );

          if (shouldSave == true) {
            final archiveEntry = GrowthEntry(
              id: '',
              date: widget.tree.plantingDate,
              photoUrl: currentMain,
              height: 0,
              trunkDiameter: 0,
              healthStatus: 'Desconegut',
              observations: 'Foto principal anterior arxivada automàticament',
            );
            await ref
                .read(treesRepositoryProvider)
                .addGrowthEntry(widget.tree.id, archiveEntry);
          }
        }
      } catch (e) {
        debugPrint('Error checking duplicate photo: $e');
      }
    }

    final updatedTree = widget.tree.copyWith(photoUrl: _currentEntry.photoUrl);
    await ref.read(treesRepositoryProvider).updateTree(updatedTree);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto principal actualitzada'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deletePhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar foto?'),
        content: const Text('Aquesta acció no es pot desfer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL·LAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref
          .read(treesRepositoryProvider)
          .deleteGrowthEntry(widget.tree.id, _currentEntry.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Foto eliminada')));
      }
    }
  }
}

/// Giny que embolcalla cada foto amb suport de zoom interactiu (pinça, doble toc i botó)
class _ZoomablePhotoView extends StatefulWidget {
  final String photoUrl;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomablePhotoView({
    super.key,
    required this.photoUrl,
    required this.onZoomChanged,
  });

  @override
  State<_ZoomablePhotoView> createState() => _ZoomablePhotoViewState();
}

class _ZoomablePhotoViewState extends State<_ZoomablePhotoView>
    with SingleTickerProviderStateMixin {
  late TransformationController _controller;
  late AnimationController _animController;
  Animation<Matrix4>? _animation;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _controller.addListener(_handleTransformChanged);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _handleTransformChanged() {
    final scale = _controller.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _isZoomed) {
      _isZoomed = zoomed;
      widget.onZoomChanged(zoomed);
    }
  }

  void toggleZoom() {
    _animController.reset();
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final Matrix4 endMatrix = currentScale > 1.2
        ? Matrix4.identity()
        : Matrix4.diagonal3Values(2.5, 2.5, 1.0);

    _animateToMatrix(endMatrix);
  }

  void _handleDoubleTap(TapDownDetails details) {
    _animController.reset();
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final Matrix4 endMatrix;

    if (currentScale > 1.2) {
      endMatrix = Matrix4.identity();
    } else {
      final position = details.localPosition;
      endMatrix = Matrix4.identity()
        ..setTranslationRaw(-position.dx * 1.5, -position.dy * 1.5, 0.0)
        ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
    }

    _animateToMatrix(endMatrix);
  }

  void _animateToMatrix(Matrix4 endMatrix) {
    _animation?.removeListener(_onAnimationTick);
    _animation = Matrix4Tween(
      begin: _controller.value,
      end: endMatrix,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    ));
    _animation!.addListener(_onAnimationTick);
    _animController.forward();
  }

  void _onAnimationTick() {
    if (_animation != null) {
      _controller.value = _animation!.value;
    }
  }

  void resetZoom() {
    if (_controller.value.getMaxScaleOnAxis() > 1.05) {
      _animController.reset();
      _animateToMatrix(Matrix4.identity());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTransformChanged);
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1.0,
        maxScale: 5.0,
        clipBehavior: Clip.none,
        child: Image.network(
          widget.photoUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          },
          errorBuilder: (context, error, stack) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
          ),
        ),
      ),
    );
  }
}
