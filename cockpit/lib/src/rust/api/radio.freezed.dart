// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'radio.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RadioEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RadioEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RadioEvent()';
}


}

/// @nodoc
class $RadioEventCopyWith<$Res>  {
$RadioEventCopyWith(RadioEvent _, $Res Function(RadioEvent) __);
}


/// Adds pattern-matching-related methods to [RadioEvent].
extension RadioEventPatterns on RadioEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RadioEvent_Connected value)?  connected,TResult Function( RadioEvent_Disconnected value)?  disconnected,TResult Function( RadioEvent_Message value)?  message,TResult Function( RadioEvent_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RadioEvent_Connected() when connected != null:
return connected(_that);case RadioEvent_Disconnected() when disconnected != null:
return disconnected(_that);case RadioEvent_Message() when message != null:
return message(_that);case RadioEvent_Error() when error != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RadioEvent_Connected value)  connected,required TResult Function( RadioEvent_Disconnected value)  disconnected,required TResult Function( RadioEvent_Message value)  message,required TResult Function( RadioEvent_Error value)  error,}){
final _that = this;
switch (_that) {
case RadioEvent_Connected():
return connected(_that);case RadioEvent_Disconnected():
return disconnected(_that);case RadioEvent_Message():
return message(_that);case RadioEvent_Error():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RadioEvent_Connected value)?  connected,TResult? Function( RadioEvent_Disconnected value)?  disconnected,TResult? Function( RadioEvent_Message value)?  message,TResult? Function( RadioEvent_Error value)?  error,}){
final _that = this;
switch (_that) {
case RadioEvent_Connected() when connected != null:
return connected(_that);case RadioEvent_Disconnected() when disconnected != null:
return disconnected(_that);case RadioEvent_Message() when message != null:
return message(_that);case RadioEvent_Error() when error != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  connected,TResult Function()?  disconnected,TResult Function( ServerMessage field0)?  message,TResult Function( String field0)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RadioEvent_Connected() when connected != null:
return connected();case RadioEvent_Disconnected() when disconnected != null:
return disconnected();case RadioEvent_Message() when message != null:
return message(_that.field0);case RadioEvent_Error() when error != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  connected,required TResult Function()  disconnected,required TResult Function( ServerMessage field0)  message,required TResult Function( String field0)  error,}) {final _that = this;
switch (_that) {
case RadioEvent_Connected():
return connected();case RadioEvent_Disconnected():
return disconnected();case RadioEvent_Message():
return message(_that.field0);case RadioEvent_Error():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  connected,TResult? Function()?  disconnected,TResult? Function( ServerMessage field0)?  message,TResult? Function( String field0)?  error,}) {final _that = this;
switch (_that) {
case RadioEvent_Connected() when connected != null:
return connected();case RadioEvent_Disconnected() when disconnected != null:
return disconnected();case RadioEvent_Message() when message != null:
return message(_that.field0);case RadioEvent_Error() when error != null:
return error(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class RadioEvent_Connected extends RadioEvent {
  const RadioEvent_Connected(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RadioEvent_Connected);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RadioEvent.connected()';
}


}




/// @nodoc


class RadioEvent_Disconnected extends RadioEvent {
  const RadioEvent_Disconnected(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RadioEvent_Disconnected);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RadioEvent.disconnected()';
}


}




/// @nodoc


class RadioEvent_Message extends RadioEvent {
  const RadioEvent_Message(this.field0): super._();
  

 final  ServerMessage field0;

/// Create a copy of RadioEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RadioEvent_MessageCopyWith<RadioEvent_Message> get copyWith => _$RadioEvent_MessageCopyWithImpl<RadioEvent_Message>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RadioEvent_Message&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'RadioEvent.message(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $RadioEvent_MessageCopyWith<$Res> implements $RadioEventCopyWith<$Res> {
  factory $RadioEvent_MessageCopyWith(RadioEvent_Message value, $Res Function(RadioEvent_Message) _then) = _$RadioEvent_MessageCopyWithImpl;
@useResult
$Res call({
 ServerMessage field0
});


$ServerMessageCopyWith<$Res> get field0;

}
/// @nodoc
class _$RadioEvent_MessageCopyWithImpl<$Res>
    implements $RadioEvent_MessageCopyWith<$Res> {
  _$RadioEvent_MessageCopyWithImpl(this._self, this._then);

  final RadioEvent_Message _self;
  final $Res Function(RadioEvent_Message) _then;

/// Create a copy of RadioEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(RadioEvent_Message(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as ServerMessage,
  ));
}

/// Create a copy of RadioEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ServerMessageCopyWith<$Res> get field0 {
  
  return $ServerMessageCopyWith<$Res>(_self.field0, (value) {
    return _then(_self.copyWith(field0: value));
  });
}
}

/// @nodoc


class RadioEvent_Error extends RadioEvent {
  const RadioEvent_Error(this.field0): super._();
  

 final  String field0;

/// Create a copy of RadioEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RadioEvent_ErrorCopyWith<RadioEvent_Error> get copyWith => _$RadioEvent_ErrorCopyWithImpl<RadioEvent_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RadioEvent_Error&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'RadioEvent.error(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $RadioEvent_ErrorCopyWith<$Res> implements $RadioEventCopyWith<$Res> {
  factory $RadioEvent_ErrorCopyWith(RadioEvent_Error value, $Res Function(RadioEvent_Error) _then) = _$RadioEvent_ErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$RadioEvent_ErrorCopyWithImpl<$Res>
    implements $RadioEvent_ErrorCopyWith<$Res> {
  _$RadioEvent_ErrorCopyWithImpl(this._self, this._then);

  final RadioEvent_Error _self;
  final $Res Function(RadioEvent_Error) _then;

/// Create a copy of RadioEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(RadioEvent_Error(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
