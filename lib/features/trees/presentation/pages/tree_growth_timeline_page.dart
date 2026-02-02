import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/tree.dart';
import '../../domain/entities/growth_entry.dart';
import '../providers/trees_provider.dart';

class TreeGrowthTimelinePage extends ConsumerWidget {
  final Tree tree;

  const TreeGrowthTimelinePage({super.key, required this.tree});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Històric de Creixement'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<GrowthEntry>>(
        stream: ref
            .read(treesRepositoryProvider)
            .getGrowthEntriesStream(tree.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? [];
          var displayedEntries = List<GrowthEntry>.from(entries);

          // Prepend Main Image if exists and not already in list
          if (tree.photoUrl != null) {
            final mainUrl = tree.photoUrl!;
            final exists = displayedEntries.any((e) => e.photoUrl == mainUrl);
            if (!exists) {
              final mainEntry = GrowthEntry(
                id: 'MAIN_PHOTO',
                date: tree.plantingDate,
                photoUrl: mainUrl,
                height: 0,
                trunkDiameter: 0,
                healthStatus: 'Inicial',
                observations: 'Foto Principal',
              );
              displayedEntries.add(
                mainEntry,
              ); // Add to end (oldest) if sorting desc?
              // Wait, timeline is usually Newest First.
              // If main photo is "Initial", it should be at the END of the list (Oldest).
              // Let's check sort order. Repository usually returns desc (newest first).
              // So if we simply add it, it goes to the end (oldest).
              // BUT we should verify date.

              displayedEntries.sort((a, b) => b.date.compareTo(a.date));
            }
          }

          if (displayedEntries.isEmpty) {
            return const Center(
              child: Text(
                'Encara no hi ha registres de seguiment.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          // Calculate summary
          // Assuming entries are sorted descending (Newest first) by the repository query.
          // Growth = Newest Height - Oldest Height.
          // Note: If only 1 entry, growth is 0 unless we assume initial height was 0?
          // Usually trees are planted at some height.
          // Let's assume growth from FIRST entry to LAST entry.

          // Re-sort to be sure? Repo does orderBy('date', descending: true).
          // So entries[0] is newest. entries.last is oldest.

          double currentHeight = displayedEntries.first.height;
          double initialHeight = displayedEntries.last.height;
          double growth = currentHeight - initialHeight;
          if (growth < 0) {
            growth = 0; // Should not happen usually unless error or cutting.
          }

          return Column(
            children: [
              // Summary Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.indigo.shade50,
                child: Column(
                  children: [
                    Text(
                      'Resum de Creixement',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade300,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Has crescut ${growth.toStringAsFixed(1)} cm',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                    Text(
                      'Des de ${DateFormat('dd/MM/yyyy').format(displayedEntries.last.date)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayedEntries.length,
                  itemBuilder: (context, index) {
                    final entry = displayedEntries[index];
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Timeline
                          SizedBox(
                            width: 60,
                            child: Column(
                              children: [
                                Text(
                                  DateFormat('dd/MM').format(entry.date),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo,
                                  ),
                                ),
                                Text(
                                  DateFormat('yyyy').format(entry.date),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: Colors.indigo.shade100,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Right: Card
                          Expanded(
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 24),
                              clipBehavior: Clip.antiAlias,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (entry.photoUrl.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                _TimelineGalleryPage(
                                                  entries: displayedEntries,
                                                  initialIndex: index,
                                                  tree: tree,
                                                  ref: ref,
                                                ),
                                          ),
                                        );
                                      },
                                      child: SizedBox(
                                        height: 250,
                                        width: double.infinity,
                                        child: Image.network(
                                          entry.photoUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildMetric(
                                              'Alçada',
                                              '${entry.height} cm',
                                            ),
                                            _buildMetric(
                                              'Diàmetre',
                                              '${entry.trunkDiameter} cm',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.health_and_safety,
                                              size: 16,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              entry.healthStatus,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (entry.observations.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            entry.observations,
                                            style: TextStyle(
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// Gallery page for navigating between timeline photos
class _TimelineGalleryPage extends StatefulWidget {
  final List<GrowthEntry> entries;
  final int initialIndex;
  final Tree tree;
  final WidgetRef ref;

  const _TimelineGalleryPage({
    required this.entries,
    required this.initialIndex,
    required this.tree,
    required this.ref,
  });

  @override
  State<_TimelineGalleryPage> createState() => _TimelineGalleryPageState();
}

class _TimelineGalleryPageState extends State<_TimelineGalleryPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  GrowthEntry get _currentEntry => widget.entries[_currentIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.entries.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Photo PageView with navigation buttons
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.entries.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final entry = widget.entries[index];
                    return GestureDetector(
                      onDoubleTap: () => _showZoomView(entry.photoUrl),
                      child: Image.network(
                        entry.photoUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stack) => const Center(
                          child: Icon(Icons.error, color: Colors.red, size: 48),
                        ),
                      ),
                    );
                  },
                ),
                // Navigation buttons
                if (widget.entries.length > 1)
                  Positioned.fill(
                    child: Row(
                      children: [
                        // Previous button
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
                        // Next button
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
          // Info panel
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(_currentEntry.date),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (_currentEntry.healthStatus.isNotEmpty)
                      Chip(
                        label: Text(
                          _currentEntry.healthStatus,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.indigo.shade100,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                if (_currentEntry.observations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _currentEntry.observations,
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (_currentEntry.height > 0 ||
                    _currentEntry.trunkDiameter > 0) ...[
                  const SizedBox(height: 8),
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

  void _showZoomView(String photoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pinça per fer zoom',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
