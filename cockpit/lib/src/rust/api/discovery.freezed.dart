// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'discovery.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiscoveryEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiscoveryEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DiscoveryEvent()';
}


}

/// @nodoc
class $DiscoveryEventCopyWith<$Res>  {
$DiscoveryEventCopyWith(DiscoveryEvent _, $Res Function(DiscoveryEvent) __);
}


/// Adds pattern-matching-related methods to [DiscoveryEvent].
extension DiscoveryEventPatterns on DiscoveryEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DiscoveryEvent_CarDiscovered value)?  carDiscovered,TResult Function( DiscoveryEvent_CarUpdated value)?  carUpdated,TResult Function( DiscoveryEvent_DiscoveryStarted value)?  discoveryStarted,TResult Function( DiscoveryEvent_DiscoveryStopped value)?  discoveryStopped,TResult Function( DiscoveryEvent_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DiscoveryEvent_CarDiscovered() when carDiscovered != null:
return carDiscovered(_that);case DiscoveryEvent_CarUpdated() when carUpdated != null:
return carUpdated(_that);case DiscoveryEvent_DiscoveryStarted() when discoveryStarted != null:
return discoveryStarted(_that);case DiscoveryEvent_DiscoveryStopped() when discoveryStopped != null:
return discoveryStopped(_that);case DiscoveryEvent_Error() when error != null:
return error(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DiscoveryEvent_CarDiscovered value)  carDiscovered,required TResult Function( DiscoveryEvent_CarUpdated value)  carUpdated,required TResult Function( DiscoveryEvent_DiscoveryStarted value)  discoveryStarted,required TResult Function( DiscoveryEvent_DiscoveryStopped value)  discoveryStopped,required TResult Function( DiscoveryEvent_Error value)  error,}){
final _that = this;
switch (_that) {
case DiscoveryEvent_CarDiscovered():
return carDiscovered(_that);case DiscoveryEvent_CarUpdated():
return carUpdated(_that);case DiscoveryEvent_DiscoveryStarted():
return discoveryStarted(_that);case DiscoveryEvent_DiscoveryStopped():
return discoveryStopped(_that);case DiscoveryEvent_Error():
return error(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DiscoveryEvent_CarDiscovered value)?  carDiscovered,TResult? Function( DiscoveryEvent_CarUpdated value)?  carUpdated,TResult? Function( DiscoveryEvent_DiscoveryStarted value)?  discoveryStarted,TResult? Function( DiscoveryEvent_DiscoveryStopped value)?  discoveryStopped,TResult? Function( DiscoveryEvent_Error value)?  error,}){
final _that = this;
switch (_that) {
case DiscoveryEvent_CarDiscovered() when carDiscovered != null:
return carDiscovered(_that);case DiscoveryEvent_CarUpdated() when carUpdated != null:
return carUpdated(_that);case DiscoveryEvent_DiscoveryStarted() when discoveryStarted != null:
return discoveryStarted(_that);case DiscoveryEvent_DiscoveryStopped() when discoveryStopped != null:
return discoveryStopped(_that);case DiscoveryEvent_Error() when error != null:
return error(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( F1Car field0)?  carDiscovered,TResult Function( F1Car field0)?  carUpdated,TResult Function()?  discoveryStarted,TResult Function()?  discoveryStopped,TResult Function( String field0)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DiscoveryEvent_CarDiscovered() when carDiscovered != null:
return carDiscovered(_that.field0);case DiscoveryEvent_CarUpdated() when carUpdated != null:
return carUpdated(_that.field0);case DiscoveryEvent_DiscoveryStarted() when discoveryStarted != null:
return discoveryStarted();case DiscoveryEvent_DiscoveryStopped() when discoveryStopped != null:
return discoveryStopped();case DiscoveryEvent_Error() when error != null:
return error(_that.field0);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( F1Car field0)  carDiscovered,required TResult Function( F1Car field0)  carUpdated,required TResult Function()  discoveryStarted,required TResult Function()  discoveryStopped,required TResult Function( String field0)  error,}) {final _that = this;
switch (_that) {
case DiscoveryEvent_CarDiscovered():
return carDiscovered(_that.field0);case DiscoveryEvent_CarUpdated():
return carUpdated(_that.field0);case DiscoveryEvent_DiscoveryStarted():
return discoveryStarted();case DiscoveryEvent_DiscoveryStopped():
return discoveryStopped();case DiscoveryEvent_Error():
return error(_that.field0);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( F1Car field0)?  carDiscovered,TResult? Function( F1Car field0)?  carUpdated,TResult? Function()?  discoveryStarted,TResult? Function()?  discoveryStopped,TResult? Function( String field0)?  error,}) {final _that = this;
switch (_that) {
case DiscoveryEvent_CarDiscovered() when carDiscovered != null:
return carDiscovered(_that.field0);case DiscoveryEvent_CarUpdated() when carUpdated != null:
return carUpdated(_that.field0);case DiscoveryEvent_DiscoveryStarted() when discoveryStarted != null:
return discoveryStarted();case DiscoveryEvent_DiscoveryStopped() when discoveryStopped != null:
return discoveryStopped();case DiscoveryEvent_Error() when error != null:
return error(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class DiscoveryEvent_CarDiscovered extends DiscoveryEvent {
  const DiscoveryEvent_CarDiscovered(this.field0): super._();
  

 final  F1Car field0;

/// Create a copy of DiscoveryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiscoveryEvent_CarDiscoveredCopyWith<DiscoveryEvent_CarDiscovered> get copyWith => _$DiscoveryEvent_CarDiscoveredCopyWithImpl<DiscoveryEvent_CarDiscovered>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiscoveryEvent_CarDiscovered&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'DiscoveryEvent.carDiscovered(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $DiscoveryEvent_CarDiscoveredCopyWith<$Res> implements $DiscoveryEventCopyWith<$Res> {
  factory $DiscoveryEvent_CarDiscoveredCopyWith(DiscoveryEvent_CarDiscovered value, $Res Function(DiscoveryEvent_CarDiscovered) _then) = _$DiscoveryEvent_CarDiscoveredCopyWithImpl;
@useResult
$Res call({
 F1Car field0
});




}
/// @nodoc
class _$DiscoveryEvent_CarDiscoveredCopyWithImpl<$Res>
    implements $DiscoveryEvent_CarDiscoveredCopyWith<$Res> {
  _$DiscoveryEvent_CarDiscoveredCopyWithImpl(this._self, this._then);

  final DiscoveryEvent_CarDiscovered _self;
  final $Res Function(DiscoveryEvent_CarDiscovered) _then;

/// Create a copy of DiscoveryEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(DiscoveryEvent_CarDiscovered(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as F1Car,
  ));
}


}

/// @nodoc


class DiscoveryEvent_CarUpdated extends DiscoveryEvent {
  const DiscoveryEvent_CarUpdated(this.field0): super._();
  

 final  F1Car field0;

/// Create a copy of DiscoveryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiscoveryEvent_CarUpdatedCopyWith<DiscoveryEvent_CarUpdated> get copyWith => _$DiscoveryEvent_CarUpdatedCopyWithImpl<DiscoveryEvent_CarUpdated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiscoveryEvent_CarUpdated&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'DiscoveryEvent.carUpdated(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $DiscoveryEvent_CarUpdatedCopyWith<$Res> implements $DiscoveryEventCopyWith<$Res> {
  factory $DiscoveryEvent_CarUpdatedCopyWith(DiscoveryEvent_CarUpdated value, $Res Function(DiscoveryEvent_CarUpdated) _then) = _$DiscoveryEvent_CarUpdatedCopyWithImpl;
@useResult
$Res call({
 F1Car field0
});




}
/// @nodoc
class _$DiscoveryEvent_CarUpdatedCopyWithImpl<$Res>
    implements $DiscoveryEvent_CarUpdatedCopyWith<$Res> {
  _$DiscoveryEvent_CarUpdatedCopyWithImpl(this._self, this._then);

  final DiscoveryEvent_CarUpdated _self;
  final $Res Function(DiscoveryEvent_CarUpdated) _then;

/// Create a copy of DiscoveryEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(DiscoveryEvent_CarUpdated(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as F1Car,
  ));
}


}

/// @nodoc


class DiscoveryEvent_DiscoveryStarted extends DiscoveryEvent {
  const DiscoveryEvent_DiscoveryStarted(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiscoveryEvent_DiscoveryStarted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DiscoveryEvent.discoveryStarted()';
}


}




/// @nodoc


class DiscoveryEvent_DiscoveryStopped extends DiscoveryEvent {
  const DiscoveryEvent_DiscoveryStopped(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiscoveryEvent_DiscoveryStopped);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DiscoveryEvent.discoveryStopped()';
}


}




/// @nodoc


class DiscoveryEvent_Error extends DiscoveryEvent {
  const DiscoveryEvent_Error(this.field0): super._();
  

 final  String field0;

/// Create a copy of DiscoveryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiscoveryEvent_ErrorCopyWith<DiscoveryEvent_Error> get copyWith => _$DiscoveryEvent_ErrorCopyWithImpl<DiscoveryEvent_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiscoveryEvent_Error&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'DiscoveryEvent.error(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $DiscoveryEvent_ErrorCopyWith<$Res> implements $DiscoveryEventCopyWith<$Res> {
  factory $DiscoveryEvent_ErrorCopyWith(DiscoveryEvent_Error value, $Res Function(DiscoveryEvent_Error) _then) = _$DiscoveryEvent_ErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$DiscoveryEvent_ErrorCopyWithImpl<$Res>
    implements $DiscoveryEvent_ErrorCopyWith<$Res> {
  _$DiscoveryEvent_ErrorCopyWithImpl(this._self, this._then);

  final DiscoveryEvent_Error _self;
  final $Res Function(DiscoveryEvent_Error) _then;

/// Create a copy of DiscoveryEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(DiscoveryEvent_Error(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
