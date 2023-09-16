import 'dart:async';

import 'package:rxdart/transformers.dart';
import 'package:typed_redux/typed_redux.dart';
import 'package:typed_redux_epics/src/epic.dart';
import 'package:typed_redux_epics/src/epic_store.dart';

/// A [Redux](https://pub.dartlang.org/packages/typed_redux) middleware that passes
/// a stream of dispatched actions to the given [TypedEpic].
///
/// It is recommended that you put your `EpicMiddleware` first when constructing
/// the list of middleware for your store so any actions dispatched from
/// your [TypedEpic] will be intercepted by the remaining Middleware.
///
/// Example:
///
///     var epicMiddleware = new EpicMiddleware(new ExampleEpic());
///     var store = new Store<List<Action>, Action>(reducer,
///       initialState: [], middleware: [epicMiddleware]);
class TypedEpicMiddleware<State, Action>
    extends TypedMiddlewareClass<State, Action> {
  final StreamController<Action> _actions =
      StreamController<Action>.broadcast();
  final StreamController<TypedEpic<State, Action>> _epics =
      StreamController.broadcast(sync: true);

  final bool supportAsyncGenerators;
  TypedEpic<State, Action> _epic;
  bool _isSubscribed = false;

  TypedEpicMiddleware(TypedEpic<State, Action> epic,
      {this.supportAsyncGenerators = true})
      : _epic = epic;

  @override
  void call(TypedStore<State, Action> store, Action action,
      TypedNextDispatcher<Action> next) {
    if (!_isSubscribed) {
      _epics.stream
          .switchMap((epic) => epic(_actions.stream, TypedEpicStore(store)))
          .listen(store.dispatch);

      _epics.add(_epic);

      _isSubscribed = true;
    }

    next(action);

    if (supportAsyncGenerators) {
      // Future.delayed is an ugly hack to support async* functions.
      //
      // See: https://github.com/dart-lang/sdk/issues/33818
      Future.delayed(Duration.zero, () {
        _actions.add(action);
      });
    } else {
      _actions.add(action);
    }
  }

  /// Gets or replaces the epic currently used by the middleware.
  ///
  /// Replacing epics is considered an advanced API. You might need this if your
  /// app grows large and want to instantiate Epics on the fly, rather than
  /// as a whole up front.
  TypedEpic<State, Action> get epic => _epic;

  set epic(TypedEpic<State, Action> newEpic) {
    _epic = newEpic;

    _epics.add(newEpic);
  }
}
