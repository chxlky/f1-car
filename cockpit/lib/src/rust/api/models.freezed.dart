// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ServerMessage {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessage);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ServerMessage()';
}


}

/// @nodoc
class $ServerMessageCopyWith<$Res>  {
$ServerMessageCopyWith(ServerMessage _, $Res Function(ServerMessage) __);
}


/// Adds pattern-matching-related methods to [ServerMessage].
extension ServerMessagePatterns on ServerMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ServerMessage_Identity value)?  identity,TResult Function( ServerMessage_Physics value)?  physics,TResult Function( ServerMessage_Pong value)?  pong,TResult Function( ServerMessage_IdentityUpdated value)?  identityUpdated,TResult Function( ServerMessage_PhysicsUpdated value)?  physicsUpdated,TResult Function( ServerMessage_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ServerMessage_Identity() when identity != null:
return identity(_that);case ServerMessage_Physics() when physics != null:
return physics(_that);case ServerMessage_Pong() when pong != null:
return pong(_that);case ServerMessage_IdentityUpdated() when identityUpdated != null:
return identityUpdated(_that);case ServerMessage_PhysicsUpdated() when physicsUpdated != null:
return physicsUpdated(_that);case ServerMessage_Error() when error != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ServerMessage_Identity value)  identity,required TResult Function( ServerMessage_Physics value)  physics,required TResult Function( ServerMessage_Pong value)  pong,required TResult Function( ServerMessage_IdentityUpdated value)  identityUpdated,required TResult Function( ServerMessage_PhysicsUpdated value)  physicsUpdated,required TResult Function( ServerMessage_Error value)  error,}){
final _that = this;
switch (_that) {
case ServerMessage_Identity():
return identity(_that);case ServerMessage_Physics():
return physics(_that);case ServerMessage_Pong():
return pong(_that);case ServerMessage_IdentityUpdated():
return identityUpdated(_that);case ServerMessage_PhysicsUpdated():
return physicsUpdated(_that);case ServerMessage_Error():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ServerMessage_Identity value)?  identity,TResult? Function( ServerMessage_Physics value)?  physics,TResult? Function( ServerMessage_Pong value)?  pong,TResult? Function( ServerMessage_IdentityUpdated value)?  identityUpdated,TResult? Function( ServerMessage_PhysicsUpdated value)?  physicsUpdated,TResult? Function( ServerMessage_Error value)?  error,}){
final _that = this;
switch (_that) {
case ServerMessage_Identity() when identity != null:
return identity(_that);case ServerMessage_Physics() when physics != null:
return physics(_that);case ServerMessage_Pong() when pong != null:
return pong(_that);case ServerMessage_IdentityUpdated() when identityUpdated != null:
return identityUpdated(_that);case ServerMessage_PhysicsUpdated() when physicsUpdated != null:
return physicsUpdated(_that);case ServerMessage_Error() when error != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( CarIdentity field0)?  identity,TResult Function( CarPhysics field0)?  physics,TResult Function( PlatformInt64 timestamp)?  pong,TResult Function( bool success,  String message)?  identityUpdated,TResult Function( bool success,  String message)?  physicsUpdated,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ServerMessage_Identity() when identity != null:
return identity(_that.field0);case ServerMessage_Physics() when physics != null:
return physics(_that.field0);case ServerMessage_Pong() when pong != null:
return pong(_that.timestamp);case ServerMessage_IdentityUpdated() when identityUpdated != null:
return identityUpdated(_that.success,_that.message);case ServerMessage_PhysicsUpdated() when physicsUpdated != null:
return physicsUpdated(_that.success,_that.message);case ServerMessage_Error() when error != null:
return error(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( CarIdentity field0)  identity,required TResult Function( CarPhysics field0)  physics,required TResult Function( PlatformInt64 timestamp)  pong,required TResult Function( bool success,  String message)  identityUpdated,required TResult Function( bool success,  String message)  physicsUpdated,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case ServerMessage_Identity():
return identity(_that.field0);case ServerMessage_Physics():
return physics(_that.field0);case ServerMessage_Pong():
return pong(_that.timestamp);case ServerMessage_IdentityUpdated():
return identityUpdated(_that.success,_that.message);case ServerMessage_PhysicsUpdated():
return physicsUpdated(_that.success,_that.message);case ServerMessage_Error():
return error(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( CarIdentity field0)?  identity,TResult? Function( CarPhysics field0)?  physics,TResult? Function( PlatformInt64 timestamp)?  pong,TResult? Function( bool success,  String message)?  identityUpdated,TResult? Function( bool success,  String message)?  physicsUpdated,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case ServerMessage_Identity() when identity != null:
return identity(_that.field0);case ServerMessage_Physics() when physics != null:
return physics(_that.field0);case ServerMessage_Pong() when pong != null:
return pong(_that.timestamp);case ServerMessage_IdentityUpdated() when identityUpdated != null:
return identityUpdated(_that.success,_that.message);case ServerMessage_PhysicsUpdated() when physicsUpdated != null:
return physicsUpdated(_that.success,_that.message);case ServerMessage_Error() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class ServerMessage_Identity extends ServerMessage {
  const ServerMessage_Identity(this.field0): super._();
  

 final  CarIdentity field0;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerMessage_IdentityCopyWith<ServerMessage_Identity> get copyWith => _$ServerMessage_IdentityCopyWithImpl<ServerMessage_Identity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessage_Identity&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ServerMessage.identity(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ServerMessage_IdentityCopyWith<$Res> implements $ServerMessageCopyWith<$Res> {
  factory $ServerMessage_IdentityCopyWith(ServerMessage_Identity value, $Res Function(ServerMessage_Identity) _then) = _$ServerMessage_IdentityCopyWithImpl;
@useResult
$Res call({
 CarIdentity field0
});




}
/// @nodoc
class _$ServerMessage_IdentityCopyWithImpl<$Res>
    implements $ServerMessage_IdentityCopyWith<$Res> {
  _$ServerMessage_IdentityCopyWithImpl(this._self, this._then);

  final ServerMessage_Identity _self;
  final $Res Function(ServerMessage_Identity) _then;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ServerMessage_Identity(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as CarIdentity,
  ));
}


}

/// @nodoc


class ServerMessage_Physics extends ServerMessage {
  const ServerMessage_Physics(this.field0): super._();
  

 final  CarPhysics field0;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerMessage_PhysicsCopyWith<ServerMessage_Physics> get copyWith => _$ServerMessage_PhysicsCopyWithImpl<ServerMessage_Physics>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessage_Physics&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ServerMessage.physics(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ServerMessage_PhysicsCopyWith<$Res> implements $ServerMessageCopyWith<$Res> {
  factory $ServerMessage_PhysicsCopyWith(ServerMessage_Physics value, $Res Function(ServerMessage_Physics) _then) = _$ServerMessage_PhysicsCopyWithImpl;
@useResult
$Res call({
 CarPhysics field0
});




}
/// @nodoc
class _$ServerMessage_PhysicsCopyWithImpl<$Res>
    implements $ServerMessage_PhysicsCopyWith<$Res> {
  _$ServerMessage_PhysicsCopyWithImpl(this._self, this._then);

  final ServerMessage_Physics _self;
  final $Res Function(ServerMessage_Physics) _then;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ServerMessage_Physics(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as CarPhysics,
  ));
}


}

/// @nodoc


class ServerMessage_Pong extends ServerMessage {
  const ServerMessage_Pong({required this.timestamp}): super._();
  

 final  PlatformInt64 timestamp;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerMessage_PongCopyWith<ServerMessage_Pong> get copyWith => _$ServerMessage_PongCopyWithImpl<ServerMessage_Pong>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessage_Pong&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}


@override
int get hashCode => Object.hash(runtimeType,timestamp);

@override
String toString() {
  return 'ServerMessage.pong(timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $ServerMessage_PongCopyWith<$Res> implements $ServerMessageCopyWith<$Res> {
  factory $ServerMessage_PongCopyWith(ServerMessage_Pong value, $Res Function(ServerMessage_Pong) _then) = _$ServerMessage_PongCopyWithImpl;
@useResult
$Res call({
 PlatformInt64 timestamp
});




}
/// @nodoc
class _$ServerMessage_PongCopyWithImpl<$Res>
    implements $ServerMessage_PongCopyWith<$Res> {
  _$ServerMessage_PongCopyWithImpl(this._self, this._then);

  final ServerMessage_Pong _self;
  final $Res Function(ServerMessage_Pong) _then;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? timestamp = null,}) {
  return _then(ServerMessage_Pong(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as PlatformInt64,
  ));
}


}

/// @nodoc


class ServerMessage_IdentityUpdated extends ServerMessage {
  const ServerMessage_IdentityUpdated({required this.success, required this.message}): super._();
  

 final  bool success;
 final  String message;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerMessage_IdentityUpdatedCopyWith<ServerMessage_IdentityUpdated> get copyWith => _$ServerMessage_IdentityUpdatedCopyWithImpl<ServerMessage_IdentityUpdated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessage_IdentityUpdated&&(identical(other.success, success) || other.success == success)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,success,message);

@override
String toString() {
  return 'ServerMessage.identityUpdated(success: $success, message: $message)';
}


}

/// @nodoc
abstract mixin class $ServerMessage_IdentityUpdatedCopyWith<$Res> implements $ServerMessageCopyWith<$Res> {
  factory $ServerMessage_IdentityUpdatedCopyWith(ServerMessage_IdentityUpdated value, $Res Function(ServerMessage_IdentityUpdated) _then) = _$ServerMessage_IdentityUpdatedCopyWithImpl;
@useResult
$Res call({
 bool success, String message
});




}
/// @nodoc
class _$ServerMessage_IdentityUpdatedCopyWithImpl<$Res>
    implements $ServerMessage_IdentityUpdatedCopyWith<$Res> {
  _$ServerMessage_IdentityUpdatedCopyWithImpl(this._self, this._then);

  final ServerMessage_IdentityUpdated _self;
  final $Res Function(ServerMessage_IdentityUpdated) _then;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? success = null,Object? message = null,}) {
  return _then(ServerMessage_IdentityUpdated(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ServerMessage_PhysicsUpdated extends ServerMessage {
  const ServerMessage_PhysicsUpdated({required this.success, required this.message}): super._();
  

 final  bool success;
 final  String message;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerMessage_PhysicsUpdatedCopyWith<ServerMessage_PhysicsUpdated> get copyWith => _$ServerMessage_PhysicsUpdatedCopyWithImpl<ServerMessage_PhysicsUpdated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessage_PhysicsUpdated&&(identical(other.success, success) || other.success == success)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,success,message);

@override
String toString() {
  return 'ServerMessage.physicsUpdated(success: $success, message: $message)';
}


}

/// @nodoc
abstract mixin class $ServerMessage_PhysicsUpdatedCopyWith<$Res> implements $ServerMessageCopyWith<$Res> {
  factory $ServerMessage_PhysicsUpdatedCopyWith(ServerMessage_PhysicsUpdated value, $Res Function(ServerMessage_PhysicsUpdated) _then) = _$ServerMessage_PhysicsUpdatedCopyWithImpl;
@useResult
$Res call({
 bool success, String message
});




}
/// @nodoc
class _$ServerMessage_PhysicsUpdatedCopyWithImpl<$Res>
    implements $ServerMessage_PhysicsUpdatedCopyWith<$Res> {
  _$ServerMessage_PhysicsUpdatedCopyWithImpl(this._self, this._then);

  final ServerMessage_PhysicsUpdated _self;
  final $Res Function(ServerMessage_PhysicsUpdated) _then;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? success = null,Object? message = null,}) {
  return _then(ServerMessage_PhysicsUpdated(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ServerMessage_Error extends ServerMessage {
  const ServerMessage_Error({required this.message}): super._();
  

 final  String message;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerMessage_ErrorCopyWith<ServerMessage_Error> get copyWith => _$ServerMessage_ErrorCopyWithImpl<ServerMessage_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessage_Error&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'ServerMessage.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $ServerMessage_ErrorCopyWith<$Res> implements $ServerMessageCopyWith<$Res> {
  factory $ServerMessage_ErrorCopyWith(ServerMessage_Error value, $Res Function(ServerMessage_Error) _then) = _$ServerMessage_ErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$ServerMessage_ErrorCopyWithImpl<$Res>
    implements $ServerMessage_ErrorCopyWith<$Res> {
  _$ServerMessage_ErrorCopyWithImpl(this._self, this._then);

  final ServerMessage_Error _self;
  final $Res Function(ServerMessage_Error) _then;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(ServerMessage_Error(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
