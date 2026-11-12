import 'mantle_events.dart';
import 'mantle_node.dart';

/// Describes a mutation patch to update a DOM/UI node incrementally.
sealed class MantlePatch {
  const MantlePatch();
}

/// Indicates the entire node must be replaced with [newNode].
class ReplaceNodePatch extends MantlePatch {
  const ReplaceNodePatch(this.newNode);
  final MantleNode newNode;
}

/// Indicates a text node's content should be updated to [newText].
class UpdateTextPatch extends MantlePatch {
  const UpdateTextPatch(this.newText);
  final String newText;
}

/// Indicates an element node's attributes, classes, styles, and events should be patched.
class UpdateElementPatch extends MantlePatch {
  const UpdateElementPatch({
    this.newId,
    this.classesToRemove = const [],
    this.classesToAdd = const [],
    this.attributesToRemove = const [],
    this.attributesToSet = const {},
    this.stylesToRemove = const [],
    this.stylesToSet = const {},
    this.eventsToRemove = const [],
    this.eventsToSet = const {},
    this.childrenPatches = const [],
  });

  final String? newId;
  final List<String> classesToRemove;
  final List<String> classesToAdd;
  final List<String> attributesToRemove;
  final Map<String, String> attributesToSet;
  final List<String> stylesToRemove;
  final Map<String, String> stylesToSet;
  final List<String> eventsToRemove;
  final Map<String, MantleEventCallback> eventsToSet;
  final List<MantleChildPatch> childrenPatches;

  bool get isEmpty =>
      newId == null &&
      classesToRemove.isEmpty &&
      classesToAdd.isEmpty &&
      attributesToRemove.isEmpty &&
      attributesToSet.isEmpty &&
      stylesToRemove.isEmpty &&
      stylesToSet.isEmpty &&
      eventsToRemove.isEmpty &&
      eventsToSet.isEmpty &&
      childrenPatches.isEmpty;
}

/// Patch describing child list reconciliation.
sealed class MantleChildPatch {
  const MantleChildPatch(this.index);
  final int index;
}

/// Insert new child node at [index].
class InsertChildPatch extends MantleChildPatch {
  const InsertChildPatch(super.index, this.node);
  final MantleNode node;
}

/// Remove child node at [index].
class RemoveChildPatch extends MantleChildPatch {
  const RemoveChildPatch(super.index);
}

/// Update child node at [index] with [patch].
class PatchChildPatch extends MantleChildPatch {
  const PatchChildPatch(super.index, this.patch);
  final MantlePatch patch;
}

/// Computes the diff between [oldNode] and [newNode].
class MantleDiffEngine {
  const MantleDiffEngine();

  /// Returns null if trees are identical, or the [MantlePatch] required to transform [oldNode] into [newNode].
  MantlePatch? diff(MantleNode? oldNode, MantleNode? newNode) {
    if (oldNode == null && newNode == null) return null;
    if (oldNode == null) return ReplaceNodePatch(newNode!);
    if (newNode == null) return const ReplaceNodePatch(MantleTextNode(''));

    // Check if node types differ
    if (oldNode.runtimeType != newNode.runtimeType) {
      return ReplaceNodePatch(newNode);
    }

    // 1. Text node diff
    if (oldNode is MantleTextNode && newNode is MantleTextNode) {
      if (oldNode.text != newNode.text) {
        return UpdateTextPatch(newNode.text);
      }
      return null;
    }

    // 2. Fragment diff
    if (oldNode is MantleFragment && newNode is MantleFragment) {
      final childPatches = _diffChildren(oldNode.children, newNode.children);
      if (childPatches.isEmpty) return null;
      return UpdateElementPatch(childrenPatches: childPatches);
    }

    // 3. Element node diff
    if (oldNode is MantleElementNode && newNode is MantleElementNode) {
      // If tag or key changed, full replace
      if (oldNode.tag != newNode.tag || oldNode.key != newNode.key) {
        return ReplaceNodePatch(newNode);
      }

      // Diff ID
      final newId = (oldNode.id != newNode.id) ? (newNode.id ?? '') : null;

      // Diff classes
      final oldClasses = oldNode.classes.toSet();
      final newClasses = newNode.classes.toSet();
      final classesToRemove = oldClasses.difference(newClasses).toList();
      final classesToAdd = newClasses.difference(oldClasses).toList();

      // Diff attributes
      final attributesToRemove = <String>[];
      final attributesToSet = <String, String>{};
      for (final key in oldNode.attributes.keys) {
        if (!newNode.attributes.containsKey(key)) {
          attributesToRemove.add(key);
        }
      }
      for (final entry in newNode.attributes.entries) {
        if (oldNode.attributes[entry.key] != entry.value) {
          attributesToSet[entry.key] = entry.value;
        }
      }

      // Diff styles
      final stylesToRemove = <String>[];
      final stylesToSet = <String, String>{};
      for (final key in oldNode.styles.keys) {
        if (!newNode.styles.containsKey(key)) {
          stylesToRemove.add(key);
        }
      }
      for (final entry in newNode.styles.entries) {
        if (oldNode.styles[entry.key] != entry.value) {
          stylesToSet[entry.key] = entry.value;
        }
      }

      // Diff events
      final eventsToRemove = <String>[];
      final eventsToSet = <String, MantleEventCallback>{};
      for (final key in oldNode.events.keys) {
        if (!newNode.events.containsKey(key)) {
          eventsToRemove.add(key);
        }
      }
      for (final entry in newNode.events.entries) {
        eventsToSet[entry.key] = entry.value;
      }

      // Diff children
      final childPatches = _diffChildren(oldNode.children, newNode.children);

      final patch = UpdateElementPatch(
        newId: newId,
        classesToRemove: classesToRemove,
        classesToAdd: classesToAdd,
        attributesToRemove: attributesToRemove,
        attributesToSet: attributesToSet,
        stylesToRemove: stylesToRemove,
        stylesToSet: stylesToSet,
        eventsToRemove: eventsToRemove,
        eventsToSet: eventsToSet,
        childrenPatches: childPatches,
      );

      return patch.isEmpty ? null : patch;
    }

    return ReplaceNodePatch(newNode);
  }

  List<MantleChildPatch> _diffChildren(
    List<MantleNode> oldChildren,
    List<MantleNode> newChildren,
  ) {
    final patches = <MantleChildPatch>[];
    final minLength = oldChildren.length < newChildren.length
        ? oldChildren.length
        : newChildren.length;

    for (var i = 0; i < minLength; i++) {
      final childPatch = diff(oldChildren[i], newChildren[i]);
      if (childPatch != null) {
        patches.add(PatchChildPatch(i, childPatch));
      }
    }

    if (newChildren.length > oldChildren.length) {
      for (var i = minLength; i < newChildren.length; i++) {
        patches.add(InsertChildPatch(i, newChildren[i]));
      }
    } else if (oldChildren.length > newChildren.length) {
      for (var i = oldChildren.length - 1; i >= minLength; i--) {
        patches.add(RemoveChildPatch(i));
      }
    }

    return patches;
  }
}
