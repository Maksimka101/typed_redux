import 'dart:async';

import 'package:typed_redux/typed_redux.dart';

/// A stripped-down Redux [Store]. Removes unsupported [Store] methods.
///
/// Due to the way streams are implemented with Dart, it's impossible to
/// perform `store.dispatch` from within an [Epic] or observe the store directly.
class TypedEpicStore<State, Action> {
  final TypedStore<State, Action> _store;

  TypedEpicStore(this._store);

  /// Returns the current state of the redux store
  State get state => _store.state;

  Stream<State> get onChange => _store.onChange;
}
