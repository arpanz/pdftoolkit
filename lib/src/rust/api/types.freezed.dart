// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'types.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EncryptionInfo {

 bool get isEncrypted; int get pageCount;
/// Create a copy of EncryptionInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EncryptionInfoCopyWith<EncryptionInfo> get copyWith => _$EncryptionInfoCopyWithImpl<EncryptionInfo>(this as EncryptionInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EncryptionInfo&&(identical(other.isEncrypted, isEncrypted) || other.isEncrypted == isEncrypted)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount));
}


@override
int get hashCode => Object.hash(runtimeType,isEncrypted,pageCount);

@override
String toString() {
  return 'EncryptionInfo(isEncrypted: $isEncrypted, pageCount: $pageCount)';
}


}

/// @nodoc
abstract mixin class $EncryptionInfoCopyWith<$Res>  {
  factory $EncryptionInfoCopyWith(EncryptionInfo value, $Res Function(EncryptionInfo) _then) = _$EncryptionInfoCopyWithImpl;
@useResult
$Res call({
 bool isEncrypted, int pageCount
});




}
/// @nodoc
class _$EncryptionInfoCopyWithImpl<$Res>
    implements $EncryptionInfoCopyWith<$Res> {
  _$EncryptionInfoCopyWithImpl(this._self, this._then);

  final EncryptionInfo _self;
  final $Res Function(EncryptionInfo) _then;

/// Create a copy of EncryptionInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isEncrypted = null,Object? pageCount = null,}) {
  return _then(_self.copyWith(
isEncrypted: null == isEncrypted ? _self.isEncrypted : isEncrypted // ignore: cast_nullable_to_non_nullable
as bool,pageCount: null == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [EncryptionInfo].
extension EncryptionInfoPatterns on EncryptionInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EncryptionInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EncryptionInfo() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EncryptionInfo value)  $default,){
final _that = this;
switch (_that) {
case _EncryptionInfo():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EncryptionInfo value)?  $default,){
final _that = this;
switch (_that) {
case _EncryptionInfo() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isEncrypted,  int pageCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EncryptionInfo() when $default != null:
return $default(_that.isEncrypted,_that.pageCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isEncrypted,  int pageCount)  $default,) {final _that = this;
switch (_that) {
case _EncryptionInfo():
return $default(_that.isEncrypted,_that.pageCount);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isEncrypted,  int pageCount)?  $default,) {final _that = this;
switch (_that) {
case _EncryptionInfo() when $default != null:
return $default(_that.isEncrypted,_that.pageCount);case _:
  return null;

}
}

}

/// @nodoc


class _EncryptionInfo implements EncryptionInfo {
  const _EncryptionInfo({required this.isEncrypted, required this.pageCount});
  

@override final  bool isEncrypted;
@override final  int pageCount;

/// Create a copy of EncryptionInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EncryptionInfoCopyWith<_EncryptionInfo> get copyWith => __$EncryptionInfoCopyWithImpl<_EncryptionInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EncryptionInfo&&(identical(other.isEncrypted, isEncrypted) || other.isEncrypted == isEncrypted)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount));
}


@override
int get hashCode => Object.hash(runtimeType,isEncrypted,pageCount);

@override
String toString() {
  return 'EncryptionInfo(isEncrypted: $isEncrypted, pageCount: $pageCount)';
}


}

/// @nodoc
abstract mixin class _$EncryptionInfoCopyWith<$Res> implements $EncryptionInfoCopyWith<$Res> {
  factory _$EncryptionInfoCopyWith(_EncryptionInfo value, $Res Function(_EncryptionInfo) _then) = __$EncryptionInfoCopyWithImpl;
@override @useResult
$Res call({
 bool isEncrypted, int pageCount
});




}
/// @nodoc
class __$EncryptionInfoCopyWithImpl<$Res>
    implements _$EncryptionInfoCopyWith<$Res> {
  __$EncryptionInfoCopyWithImpl(this._self, this._then);

  final _EncryptionInfo _self;
  final $Res Function(_EncryptionInfo) _then;

/// Create a copy of EncryptionInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isEncrypted = null,Object? pageCount = null,}) {
  return _then(_EncryptionInfo(
isEncrypted: null == isEncrypted ? _self.isEncrypted : isEncrypted // ignore: cast_nullable_to_non_nullable
as bool,pageCount: null == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$FileInfo {

 String get path; int get sizeBytes; int get pageCount; bool get isEncrypted;
/// Create a copy of FileInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileInfoCopyWith<FileInfo> get copyWith => _$FileInfoCopyWithImpl<FileInfo>(this as FileInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileInfo&&(identical(other.path, path) || other.path == path)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&(identical(other.isEncrypted, isEncrypted) || other.isEncrypted == isEncrypted));
}


@override
int get hashCode => Object.hash(runtimeType,path,sizeBytes,pageCount,isEncrypted);

@override
String toString() {
  return 'FileInfo(path: $path, sizeBytes: $sizeBytes, pageCount: $pageCount, isEncrypted: $isEncrypted)';
}


}

/// @nodoc
abstract mixin class $FileInfoCopyWith<$Res>  {
  factory $FileInfoCopyWith(FileInfo value, $Res Function(FileInfo) _then) = _$FileInfoCopyWithImpl;
@useResult
$Res call({
 String path, int sizeBytes, int pageCount, bool isEncrypted
});




}
/// @nodoc
class _$FileInfoCopyWithImpl<$Res>
    implements $FileInfoCopyWith<$Res> {
  _$FileInfoCopyWithImpl(this._self, this._then);

  final FileInfo _self;
  final $Res Function(FileInfo) _then;

/// Create a copy of FileInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? sizeBytes = null,Object? pageCount = null,Object? isEncrypted = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,pageCount: null == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int,isEncrypted: null == isEncrypted ? _self.isEncrypted : isEncrypted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [FileInfo].
extension FileInfoPatterns on FileInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FileInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FileInfo() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FileInfo value)  $default,){
final _that = this;
switch (_that) {
case _FileInfo():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FileInfo value)?  $default,){
final _that = this;
switch (_that) {
case _FileInfo() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  int sizeBytes,  int pageCount,  bool isEncrypted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FileInfo() when $default != null:
return $default(_that.path,_that.sizeBytes,_that.pageCount,_that.isEncrypted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  int sizeBytes,  int pageCount,  bool isEncrypted)  $default,) {final _that = this;
switch (_that) {
case _FileInfo():
return $default(_that.path,_that.sizeBytes,_that.pageCount,_that.isEncrypted);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  int sizeBytes,  int pageCount,  bool isEncrypted)?  $default,) {final _that = this;
switch (_that) {
case _FileInfo() when $default != null:
return $default(_that.path,_that.sizeBytes,_that.pageCount,_that.isEncrypted);case _:
  return null;

}
}

}

/// @nodoc


class _FileInfo implements FileInfo {
  const _FileInfo({required this.path, required this.sizeBytes, required this.pageCount, required this.isEncrypted});
  

@override final  String path;
@override final  int sizeBytes;
@override final  int pageCount;
@override final  bool isEncrypted;

/// Create a copy of FileInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FileInfoCopyWith<_FileInfo> get copyWith => __$FileInfoCopyWithImpl<_FileInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FileInfo&&(identical(other.path, path) || other.path == path)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&(identical(other.isEncrypted, isEncrypted) || other.isEncrypted == isEncrypted));
}


@override
int get hashCode => Object.hash(runtimeType,path,sizeBytes,pageCount,isEncrypted);

@override
String toString() {
  return 'FileInfo(path: $path, sizeBytes: $sizeBytes, pageCount: $pageCount, isEncrypted: $isEncrypted)';
}


}

/// @nodoc
abstract mixin class _$FileInfoCopyWith<$Res> implements $FileInfoCopyWith<$Res> {
  factory _$FileInfoCopyWith(_FileInfo value, $Res Function(_FileInfo) _then) = __$FileInfoCopyWithImpl;
@override @useResult
$Res call({
 String path, int sizeBytes, int pageCount, bool isEncrypted
});




}
/// @nodoc
class __$FileInfoCopyWithImpl<$Res>
    implements _$FileInfoCopyWith<$Res> {
  __$FileInfoCopyWithImpl(this._self, this._then);

  final _FileInfo _self;
  final $Res Function(_FileInfo) _then;

/// Create a copy of FileInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? sizeBytes = null,Object? pageCount = null,Object? isEncrypted = null,}) {
  return _then(_FileInfo(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,pageCount: null == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int,isEncrypted: null == isEncrypted ? _self.isEncrypted : isEncrypted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$PdfResult {

 bool get success; String get outputPath; String? get error; int get pageCount; int get processingMs;
/// Create a copy of PdfResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PdfResultCopyWith<PdfResult> get copyWith => _$PdfResultCopyWithImpl<PdfResult>(this as PdfResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PdfResult&&(identical(other.success, success) || other.success == success)&&(identical(other.outputPath, outputPath) || other.outputPath == outputPath)&&(identical(other.error, error) || other.error == error)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&(identical(other.processingMs, processingMs) || other.processingMs == processingMs));
}


@override
int get hashCode => Object.hash(runtimeType,success,outputPath,error,pageCount,processingMs);

@override
String toString() {
  return 'PdfResult(success: $success, outputPath: $outputPath, error: $error, pageCount: $pageCount, processingMs: $processingMs)';
}


}

/// @nodoc
abstract mixin class $PdfResultCopyWith<$Res>  {
  factory $PdfResultCopyWith(PdfResult value, $Res Function(PdfResult) _then) = _$PdfResultCopyWithImpl;
@useResult
$Res call({
 bool success, String outputPath, String? error, int pageCount, int processingMs
});




}
/// @nodoc
class _$PdfResultCopyWithImpl<$Res>
    implements $PdfResultCopyWith<$Res> {
  _$PdfResultCopyWithImpl(this._self, this._then);

  final PdfResult _self;
  final $Res Function(PdfResult) _then;

/// Create a copy of PdfResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? outputPath = null,Object? error = freezed,Object? pageCount = null,Object? processingMs = null,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,outputPath: null == outputPath ? _self.outputPath : outputPath // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,pageCount: null == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int,processingMs: null == processingMs ? _self.processingMs : processingMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PdfResult].
extension PdfResultPatterns on PdfResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PdfResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PdfResult() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PdfResult value)  $default,){
final _that = this;
switch (_that) {
case _PdfResult():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PdfResult value)?  $default,){
final _that = this;
switch (_that) {
case _PdfResult() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  String outputPath,  String? error,  int pageCount,  int processingMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PdfResult() when $default != null:
return $default(_that.success,_that.outputPath,_that.error,_that.pageCount,_that.processingMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  String outputPath,  String? error,  int pageCount,  int processingMs)  $default,) {final _that = this;
switch (_that) {
case _PdfResult():
return $default(_that.success,_that.outputPath,_that.error,_that.pageCount,_that.processingMs);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  String outputPath,  String? error,  int pageCount,  int processingMs)?  $default,) {final _that = this;
switch (_that) {
case _PdfResult() when $default != null:
return $default(_that.success,_that.outputPath,_that.error,_that.pageCount,_that.processingMs);case _:
  return null;

}
}

}

/// @nodoc


class _PdfResult implements PdfResult {
  const _PdfResult({required this.success, required this.outputPath, this.error, required this.pageCount, required this.processingMs});
  

@override final  bool success;
@override final  String outputPath;
@override final  String? error;
@override final  int pageCount;
@override final  int processingMs;

/// Create a copy of PdfResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PdfResultCopyWith<_PdfResult> get copyWith => __$PdfResultCopyWithImpl<_PdfResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PdfResult&&(identical(other.success, success) || other.success == success)&&(identical(other.outputPath, outputPath) || other.outputPath == outputPath)&&(identical(other.error, error) || other.error == error)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&(identical(other.processingMs, processingMs) || other.processingMs == processingMs));
}


@override
int get hashCode => Object.hash(runtimeType,success,outputPath,error,pageCount,processingMs);

@override
String toString() {
  return 'PdfResult(success: $success, outputPath: $outputPath, error: $error, pageCount: $pageCount, processingMs: $processingMs)';
}


}

/// @nodoc
abstract mixin class _$PdfResultCopyWith<$Res> implements $PdfResultCopyWith<$Res> {
  factory _$PdfResultCopyWith(_PdfResult value, $Res Function(_PdfResult) _then) = __$PdfResultCopyWithImpl;
@override @useResult
$Res call({
 bool success, String outputPath, String? error, int pageCount, int processingMs
});




}
/// @nodoc
class __$PdfResultCopyWithImpl<$Res>
    implements _$PdfResultCopyWith<$Res> {
  __$PdfResultCopyWithImpl(this._self, this._then);

  final _PdfResult _self;
  final $Res Function(_PdfResult) _then;

/// Create a copy of PdfResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? outputPath = null,Object? error = freezed,Object? pageCount = null,Object? processingMs = null,}) {
  return _then(_PdfResult(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,outputPath: null == outputPath ? _self.outputPath : outputPath // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,pageCount: null == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int,processingMs: null == processingMs ? _self.processingMs : processingMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
