// Mocks generated by Mockito 5.4.6 from annotations
// in runaway/test/unit/services/credit_verification_service_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;

import 'package:flutter_bloc/flutter_bloc.dart' as _i6;
import 'package:mockito/mockito.dart' as _i1;
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart' as _i3;
import 'package:runaway/core/blocs/app_data/app_data_event.dart' as _i5;
import 'package:runaway/core/blocs/app_data/app_data_state.dart' as _i2;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: must_be_immutable
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeAppDataState_0 extends _i1.SmartFake implements _i2.AppDataState {
  _FakeAppDataState_0(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

/// A class which mocks [AppDataBloc].
///
/// See the documentation for Mockito's code generation for more information.
class MockAppDataBloc extends _i1.Mock implements _i3.AppDataBloc {
  MockAppDataBloc() {
    _i1.throwOnMissingStub(this);
  }

  @override
  bool get isDataReady =>
      (super.noSuchMethod(Invocation.getter(#isDataReady), returnValue: false)
          as bool);

  @override
  _i2.AppDataState get state =>
      (super.noSuchMethod(
            Invocation.getter(#state),
            returnValue: _FakeAppDataState_0(this, Invocation.getter(#state)),
          )
          as _i2.AppDataState);

  @override
  _i4.Stream<_i2.AppDataState> get stream =>
      (super.noSuchMethod(
            Invocation.getter(#stream),
            returnValue: _i4.Stream<_i2.AppDataState>.empty(),
          )
          as _i4.Stream<_i2.AppDataState>);

  @override
  bool get isClosed =>
      (super.noSuchMethod(Invocation.getter(#isClosed), returnValue: false)
          as bool);

  @override
  void add(_i5.AppDataEvent? event) => super.noSuchMethod(
    Invocation.method(#add, [event]),
    returnValueForMissingStub: null,
  );

  @override
  void onEvent(_i5.AppDataEvent? event) => super.noSuchMethod(
    Invocation.method(#onEvent, [event]),
    returnValueForMissingStub: null,
  );

  @override
  void emit(_i2.AppDataState? state) => super.noSuchMethod(
    Invocation.method(#emit, [state]),
    returnValueForMissingStub: null,
  );

  @override
  void on<E extends _i5.AppDataEvent>(
    _i6.EventHandler<E, _i2.AppDataState>? handler, {
    _i6.EventTransformer<E>? transformer,
  }) => super.noSuchMethod(
    Invocation.method(#on, [handler], {#transformer: transformer}),
    returnValueForMissingStub: null,
  );

  @override
  void onTransition(
    _i6.Transition<_i5.AppDataEvent, _i2.AppDataState>? transition,
  ) => super.noSuchMethod(
    Invocation.method(#onTransition, [transition]),
    returnValueForMissingStub: null,
  );

  @override
  _i4.Future<void> close() =>
      (super.noSuchMethod(
            Invocation.method(#close, []),
            returnValue: _i4.Future<void>.value(),
            returnValueForMissingStub: _i4.Future<void>.value(),
          )
          as _i4.Future<void>);

  @override
  void onChange(_i6.Change<_i2.AppDataState>? change) => super.noSuchMethod(
    Invocation.method(#onChange, [change]),
    returnValueForMissingStub: null,
  );

  @override
  void addError(Object? error, [StackTrace? stackTrace]) => super.noSuchMethod(
    Invocation.method(#addError, [error, stackTrace]),
    returnValueForMissingStub: null,
  );

  @override
  void onError(Object? error, StackTrace? stackTrace) => super.noSuchMethod(
    Invocation.method(#onError, [error, stackTrace]),
    returnValueForMissingStub: null,
  );
}
