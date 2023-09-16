import 'dart:async';

import 'package:rxdart/streams.dart';
import 'package:typed_redux_epics/src/epic.dart';
import 'package:typed_redux_epics/src/epic_store.dart';

/// Combines a list of [TypedEpic]s into one.
///
/// Rather than having one massive [TypedEpic] that handles every possible type of
/// action, it's best to break [TypedEpic]s down into smaller, more manageable and
/// testable units. This way we could have a `searchEpic`, a `chatEpic`,
/// and an `updateProfileEpic`, for example.
///
/// However, the [EpicMiddleware] accepts only one [TypedEpic]. So what are we to do?
/// Fear not: redux_epics includes class for combining [TypedEpic]s together!
///
/// Example:
///
///     final epic = combineEpics<State>([
///       searchEpic,
///       chatEpic,
///       updateProfileEpic,
///     ]);
TypedEpic<State, Action> combineEpics<State, Action>(
    List<TypedEpic<State, Action>> epics) {
  return (Stream<Action> actions, TypedEpicStore<State, Action> store) {
    return MergeStream<Action>(
        epics.map((epic) => epic(actions, store)).toList());
  };
}
