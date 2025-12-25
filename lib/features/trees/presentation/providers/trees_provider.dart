import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tree.dart';
import '../../data/repositories/trees_repository.dart';

final treesRepositoryProvider = Provider<TreesRepository>((ref) {
  return TreesRepository();
});

final treesStreamProvider = StreamProvider<List<Tree>>((ref) {
  final repository = ref.watch(treesRepositoryProvider);
  return repository.getTreesStream();
});

final selectedTreeProvider = NotifierProvider<SelectedTreeNotifier, Tree?>(
  SelectedTreeNotifier.new,
);

class SelectedTreeNotifier extends Notifier<Tree?> {
  @override
  Tree? build() => null;

  void selectTree(Tree? tree) {
    state = tree;
  }
}
