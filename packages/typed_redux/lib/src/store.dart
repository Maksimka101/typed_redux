import 'dart:async';

/// Defines an application's state change
///
/// Implement this typedef to modify your app state in response to a given
/// action.
typedef TypedReducer<State, Action> = State Function(
    State state, Action action);

/// Defines a [Reducer] using a class interface.
///
/// Implement this class to modify your app state in response to a given action.
///
/// For some use cases, a class may be preferred to a function. In these
/// instances, a TypedReducerClass can be used.
abstract class TypedReducerClass<State, Action> {
  /// The [Reducer] function that converts the current state and action into a
  /// new state
  State call(State state, Action action);
}

/// A function that intercepts actions and potentially transform actions before
/// they reach the reducer.
///
/// Middleware intercept actions before they reach the reducer. This gives them
/// the ability to produce side-effects or modify the passed in action before
/// they reach the reducer.
typedef TypedMiddleware<State, Action> = void Function(
  TypedStore<State, Action> store,
  Action action,
  TypedNextDispatcher<Action> next,
);

/// Defines a [TypedMiddleware] using a Class interface.
///
/// Middleware intercept actions before they reach the reducer. This gives them
/// the ability to produce side-effects or modify the passed in action before
/// they reach the reducer.
///
/// For some use cases, a class may be preferred to a function. In these
/// instances, a TypedMiddlewareClass can be used.
abstract class TypedMiddlewareClass<State, Action> {
  /// A [Middleware] function that intercepts a dispatched action
  void call(
    TypedStore<State, Action> store,
    Action action,
    TypedNextDispatcher<Action> next,
  );
}

/// The contract between one piece of middleware and the next in the chain. Use
/// it to send the current action in your [TypedMiddleware] to the next piece of
/// [TypedMiddleware] in the chain.
///
/// Middleware can optionally pass the original action or a modified action to
/// the next piece of middleware, or never call the next piece of middleware at
/// all.
typedef TypedNextDispatcher<Action> = void Function(Action action);

/// Creates a Redux store that holds the app state tree.
///
/// The only way to change the state tree in the store is to [dispatch] an
/// action. the action will then be intercepted by any provided [TypedMiddleware].
/// After running through the middleware, the action will be sent to the given
/// [TypedReducer] to update the state tree.
///
/// To access the state tree, call the [state] getter or listen to the
/// [onChange] stream.
class TypedStore<State, Action> {
  /// The [TypedReducer] for your TypedStore. Allows you to get the current reducer or
  /// replace it with a new one if need be.
  TypedReducer<State, Action> reducer;

  final StreamController<State> _changeController;
  State _state;
  late final List<TypedNextDispatcher<Action>> _dispatchers;

  /// Creates an instance of a Redux TypedStore.
  ///
  /// The [reducer] argument specifies how the state should be changed in
  /// response to dispatched actions.
  ///
  /// The optional [initialState] argument defines the State of the store when
  /// the TypedStore is first created.
  ///
  /// The optional [middleware] argument takes a list of [TypedMiddleware] functions
  /// or [TypedMiddlewareClass]. See the [TypedMiddleware] documentation for information
  /// on how they are used.
  ///
  /// The [syncStream] argument allows you to use a synchronous
  /// [StreamController] instead of an async `StreamController` under the hood.
  /// By default, the Stream is async.
  TypedStore(
    this.reducer, {
    required State initialState,
    List<TypedMiddleware<State, Action>> middleware = const [],
    bool syncStream = false,

    /// If set to true, the TypedStore will not emit onChange events if the new State
    /// that is returned from your [reducer] in response to an Action is equal
    /// to the previous state.
    ///
    /// Under the hood, it will use the `==` method from your State class to
    /// determine whether or not the two States are equal.
    bool distinct = false,
  })  : _changeController = StreamController.broadcast(sync: syncStream),
        _state = initialState {
    _dispatchers = _createDispatchers(
      middleware,
      _createReduceAndNotify(distinct),
    );
  }

  /// Returns the current state of the app
  State get state => _state;

  /// A stream that emits the current state when it changes.
  ///
  /// ### Example
  ///
  ///     // First, create the TypedStore
  ///     final store = new TypedStore<int>(counterReducer, 0);
  ///
  ///     // Next, listen to the TypedStore's onChange stream, and print the latest
  ///     // state to your console whenever the reducer produces a new State.
  ///     //
  ///     // We'll store the StreamSubscription as a variable so we can stop
  ///     // listening later.
  ///     final subscription = store.onChange.listen(print);
  ///
  ///     // Dispatch some actions, and see the printing magic!
  ///     store.dispatch("INCREMENT"); // prints 1
  ///     store.dispatch("INCREMENT"); // prints 2
  ///     store.dispatch("DECREMENT"); // prints 1
  ///
  ///     // When you want to stop printing the state to the console, simply
  ///     `cancel` your `subscription`.
  ///     subscription.cancel();
  Stream<State> get onChange => _changeController.stream;

  // Creates the base [NextDispatcher].
  //
  // The base NextDispatcher will be called after all other middleware provided
  // by the user have been run. Its job is simple: Run the current state through
  // the reducer, save the result, and notify any subscribers.
  TypedNextDispatcher<Action> _createReduceAndNotify(bool distinct) {
    return (Action action) {
      final state = reducer(_state, action);

      if (distinct && state == _state) return;

      _state = state;
      _changeController.add(state);
    };
  }

  List<TypedNextDispatcher<Action>> _createDispatchers(
    List<TypedMiddleware<State, Action>> middleware,
    TypedNextDispatcher<Action> reduceAndNotify,
  ) {
    final dispatchers = <TypedNextDispatcher<Action>>[reduceAndNotify];

    // Convert each [Middleware] into a [NextDispatcher]
    for (var nextMiddleware in middleware.reversed) {
      final next = dispatchers.last;

      dispatchers.add(
        (Action action) => nextMiddleware(this, action, next),
      );
    }

    return dispatchers.reversed.toList();
  }

  /// Runs the action through all provided [Middleware], then applies an action
  /// to the state using the given [Reducer]. Please note: [Middleware] can
  /// intercept actions, and can modify actions or stop them from passing
  /// through to the reducer.
  void dispatch(Action action) {
    return _dispatchers[0](action);
  }

  /// Closes down the TypedStore so it will no longer be operational. Only use this
  /// if you want to destroy the TypedStore while your app is running. Do not use
  /// this method as a way to stop listening to [onChange] state changes. For
  /// that purpose, view the [onChange] documentation.
  Future<void> teardown() async {
    return _changeController.close();
  }
}
