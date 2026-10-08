// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $HabitsTable extends Habits with TableInfo<$HabitsTable, ConfirmedHabit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetValueMeta = const VerificationMeta(
    'targetValue',
  );
  @override
  late final GeneratedColumn<String> targetValue = GeneratedColumn<String>(
    'target_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _frequencyTypeMeta = const VerificationMeta(
    'frequencyType',
  );
  @override
  late final GeneratedColumn<String> frequencyType = GeneratedColumn<String>(
    'frequency_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _frequencyConfigMeta = const VerificationMeta(
    'frequencyConfig',
  );
  @override
  late final GeneratedColumn<String> frequencyConfig = GeneratedColumn<String>(
    'frequency_config',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startLocalDateMeta = const VerificationMeta(
    'startLocalDate',
  );
  @override
  late final GeneratedColumn<String> startLocalDate = GeneratedColumn<String>(
    'start_local_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<String> archivedAt = GeneratedColumn<String>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _definitionVersionMeta = const VerificationMeta(
    'definitionVersion',
  );
  @override
  late final GeneratedColumn<int> definitionVersion = GeneratedColumn<int>(
    'definition_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _definitionsMeta = const VerificationMeta(
    'definitions',
  );
  @override
  late final GeneratedColumn<String> definitions = GeneratedColumn<String>(
    'definitions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeRangesMeta = const VerificationMeta(
    'activeRanges',
  );
  @override
  late final GeneratedColumn<String> activeRanges = GeneratedColumn<String>(
    'active_ranges',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extraMeta = const VerificationMeta('extra');
  @override
  late final GeneratedColumn<String> extra = GeneratedColumn<String>(
    'extra',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    unit,
    category,
    targetValue,
    frequencyType,
    frequencyConfig,
    startLocalDate,
    archivedAt,
    version,
    definitionVersion,
    definitions,
    activeRanges,
    extra,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habits';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConfirmedHabit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('target_value')) {
      context.handle(
        _targetValueMeta,
        targetValue.isAcceptableOrUnknown(
          data['target_value']!,
          _targetValueMeta,
        ),
      );
    }
    if (data.containsKey('frequency_type')) {
      context.handle(
        _frequencyTypeMeta,
        frequencyType.isAcceptableOrUnknown(
          data['frequency_type']!,
          _frequencyTypeMeta,
        ),
      );
    }
    if (data.containsKey('frequency_config')) {
      context.handle(
        _frequencyConfigMeta,
        frequencyConfig.isAcceptableOrUnknown(
          data['frequency_config']!,
          _frequencyConfigMeta,
        ),
      );
    }
    if (data.containsKey('start_local_date')) {
      context.handle(
        _startLocalDateMeta,
        startLocalDate.isAcceptableOrUnknown(
          data['start_local_date']!,
          _startLocalDateMeta,
        ),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('definition_version')) {
      context.handle(
        _definitionVersionMeta,
        definitionVersion.isAcceptableOrUnknown(
          data['definition_version']!,
          _definitionVersionMeta,
        ),
      );
    }
    if (data.containsKey('definitions')) {
      context.handle(
        _definitionsMeta,
        definitions.isAcceptableOrUnknown(
          data['definitions']!,
          _definitionsMeta,
        ),
      );
    }
    if (data.containsKey('active_ranges')) {
      context.handle(
        _activeRangesMeta,
        activeRanges.isAcceptableOrUnknown(
          data['active_ranges']!,
          _activeRangesMeta,
        ),
      );
    }
    if (data.containsKey('extra')) {
      context.handle(
        _extraMeta,
        extra.isAcceptableOrUnknown(data['extra']!, _extraMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConfirmedHabit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConfirmedHabit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      targetValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_value'],
      ),
      frequencyType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency_type'],
      ),
      frequencyConfig: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency_config'],
      ),
      startLocalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_local_date'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archived_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      definitionVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}definition_version'],
      ),
      definitions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definitions'],
      ),
      activeRanges: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_ranges'],
      ),
      extra: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra'],
      )!,
    );
  }

  @override
  $HabitsTable createAlias(String alias) {
    return $HabitsTable(attachedDatabase, alias);
  }
}

class ConfirmedHabit extends DataClass implements Insertable<ConfirmedHabit> {
  final String id;
  final String? name;
  final String? type;
  final String? unit;
  final String? category;

  /// Wire value as JSON (`1`, `"2000.000"`, `600`).
  final String? targetValue;
  final String? frequencyType;
  final String? frequencyConfig;
  final String? startLocalDate;
  final String? archivedAt;
  final int version;
  final int? definitionVersion;
  final String? definitions;
  final String? activeRanges;
  final String extra;
  const ConfirmedHabit({
    required this.id,
    this.name,
    this.type,
    this.unit,
    this.category,
    this.targetValue,
    this.frequencyType,
    this.frequencyConfig,
    this.startLocalDate,
    this.archivedAt,
    required this.version,
    this.definitionVersion,
    this.definitions,
    this.activeRanges,
    required this.extra,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || targetValue != null) {
      map['target_value'] = Variable<String>(targetValue);
    }
    if (!nullToAbsent || frequencyType != null) {
      map['frequency_type'] = Variable<String>(frequencyType);
    }
    if (!nullToAbsent || frequencyConfig != null) {
      map['frequency_config'] = Variable<String>(frequencyConfig);
    }
    if (!nullToAbsent || startLocalDate != null) {
      map['start_local_date'] = Variable<String>(startLocalDate);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<String>(archivedAt);
    }
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || definitionVersion != null) {
      map['definition_version'] = Variable<int>(definitionVersion);
    }
    if (!nullToAbsent || definitions != null) {
      map['definitions'] = Variable<String>(definitions);
    }
    if (!nullToAbsent || activeRanges != null) {
      map['active_ranges'] = Variable<String>(activeRanges);
    }
    map['extra'] = Variable<String>(extra);
    return map;
  }

  HabitsCompanion toCompanion(bool nullToAbsent) {
    return HabitsCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      targetValue: targetValue == null && nullToAbsent
          ? const Value.absent()
          : Value(targetValue),
      frequencyType: frequencyType == null && nullToAbsent
          ? const Value.absent()
          : Value(frequencyType),
      frequencyConfig: frequencyConfig == null && nullToAbsent
          ? const Value.absent()
          : Value(frequencyConfig),
      startLocalDate: startLocalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startLocalDate),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      version: Value(version),
      definitionVersion: definitionVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(definitionVersion),
      definitions: definitions == null && nullToAbsent
          ? const Value.absent()
          : Value(definitions),
      activeRanges: activeRanges == null && nullToAbsent
          ? const Value.absent()
          : Value(activeRanges),
      extra: Value(extra),
    );
  }

  factory ConfirmedHabit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConfirmedHabit(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      type: serializer.fromJson<String?>(json['type']),
      unit: serializer.fromJson<String?>(json['unit']),
      category: serializer.fromJson<String?>(json['category']),
      targetValue: serializer.fromJson<String?>(json['targetValue']),
      frequencyType: serializer.fromJson<String?>(json['frequencyType']),
      frequencyConfig: serializer.fromJson<String?>(json['frequencyConfig']),
      startLocalDate: serializer.fromJson<String?>(json['startLocalDate']),
      archivedAt: serializer.fromJson<String?>(json['archivedAt']),
      version: serializer.fromJson<int>(json['version']),
      definitionVersion: serializer.fromJson<int?>(json['definitionVersion']),
      definitions: serializer.fromJson<String?>(json['definitions']),
      activeRanges: serializer.fromJson<String?>(json['activeRanges']),
      extra: serializer.fromJson<String>(json['extra']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String?>(name),
      'type': serializer.toJson<String?>(type),
      'unit': serializer.toJson<String?>(unit),
      'category': serializer.toJson<String?>(category),
      'targetValue': serializer.toJson<String?>(targetValue),
      'frequencyType': serializer.toJson<String?>(frequencyType),
      'frequencyConfig': serializer.toJson<String?>(frequencyConfig),
      'startLocalDate': serializer.toJson<String?>(startLocalDate),
      'archivedAt': serializer.toJson<String?>(archivedAt),
      'version': serializer.toJson<int>(version),
      'definitionVersion': serializer.toJson<int?>(definitionVersion),
      'definitions': serializer.toJson<String?>(definitions),
      'activeRanges': serializer.toJson<String?>(activeRanges),
      'extra': serializer.toJson<String>(extra),
    };
  }

  ConfirmedHabit copyWith({
    String? id,
    Value<String?> name = const Value.absent(),
    Value<String?> type = const Value.absent(),
    Value<String?> unit = const Value.absent(),
    Value<String?> category = const Value.absent(),
    Value<String?> targetValue = const Value.absent(),
    Value<String?> frequencyType = const Value.absent(),
    Value<String?> frequencyConfig = const Value.absent(),
    Value<String?> startLocalDate = const Value.absent(),
    Value<String?> archivedAt = const Value.absent(),
    int? version,
    Value<int?> definitionVersion = const Value.absent(),
    Value<String?> definitions = const Value.absent(),
    Value<String?> activeRanges = const Value.absent(),
    String? extra,
  }) => ConfirmedHabit(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    type: type.present ? type.value : this.type,
    unit: unit.present ? unit.value : this.unit,
    category: category.present ? category.value : this.category,
    targetValue: targetValue.present ? targetValue.value : this.targetValue,
    frequencyType: frequencyType.present
        ? frequencyType.value
        : this.frequencyType,
    frequencyConfig: frequencyConfig.present
        ? frequencyConfig.value
        : this.frequencyConfig,
    startLocalDate: startLocalDate.present
        ? startLocalDate.value
        : this.startLocalDate,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    version: version ?? this.version,
    definitionVersion: definitionVersion.present
        ? definitionVersion.value
        : this.definitionVersion,
    definitions: definitions.present ? definitions.value : this.definitions,
    activeRanges: activeRanges.present ? activeRanges.value : this.activeRanges,
    extra: extra ?? this.extra,
  );
  ConfirmedHabit copyWithCompanion(HabitsCompanion data) {
    return ConfirmedHabit(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      unit: data.unit.present ? data.unit.value : this.unit,
      category: data.category.present ? data.category.value : this.category,
      targetValue: data.targetValue.present
          ? data.targetValue.value
          : this.targetValue,
      frequencyType: data.frequencyType.present
          ? data.frequencyType.value
          : this.frequencyType,
      frequencyConfig: data.frequencyConfig.present
          ? data.frequencyConfig.value
          : this.frequencyConfig,
      startLocalDate: data.startLocalDate.present
          ? data.startLocalDate.value
          : this.startLocalDate,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      version: data.version.present ? data.version.value : this.version,
      definitionVersion: data.definitionVersion.present
          ? data.definitionVersion.value
          : this.definitionVersion,
      definitions: data.definitions.present
          ? data.definitions.value
          : this.definitions,
      activeRanges: data.activeRanges.present
          ? data.activeRanges.value
          : this.activeRanges,
      extra: data.extra.present ? data.extra.value : this.extra,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConfirmedHabit(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('unit: $unit, ')
          ..write('category: $category, ')
          ..write('targetValue: $targetValue, ')
          ..write('frequencyType: $frequencyType, ')
          ..write('frequencyConfig: $frequencyConfig, ')
          ..write('startLocalDate: $startLocalDate, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('version: $version, ')
          ..write('definitionVersion: $definitionVersion, ')
          ..write('definitions: $definitions, ')
          ..write('activeRanges: $activeRanges, ')
          ..write('extra: $extra')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    unit,
    category,
    targetValue,
    frequencyType,
    frequencyConfig,
    startLocalDate,
    archivedAt,
    version,
    definitionVersion,
    definitions,
    activeRanges,
    extra,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfirmedHabit &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.unit == this.unit &&
          other.category == this.category &&
          other.targetValue == this.targetValue &&
          other.frequencyType == this.frequencyType &&
          other.frequencyConfig == this.frequencyConfig &&
          other.startLocalDate == this.startLocalDate &&
          other.archivedAt == this.archivedAt &&
          other.version == this.version &&
          other.definitionVersion == this.definitionVersion &&
          other.definitions == this.definitions &&
          other.activeRanges == this.activeRanges &&
          other.extra == this.extra);
}

class HabitsCompanion extends UpdateCompanion<ConfirmedHabit> {
  final Value<String> id;
  final Value<String?> name;
  final Value<String?> type;
  final Value<String?> unit;
  final Value<String?> category;
  final Value<String?> targetValue;
  final Value<String?> frequencyType;
  final Value<String?> frequencyConfig;
  final Value<String?> startLocalDate;
  final Value<String?> archivedAt;
  final Value<int> version;
  final Value<int?> definitionVersion;
  final Value<String?> definitions;
  final Value<String?> activeRanges;
  final Value<String> extra;
  final Value<int> rowid;
  const HabitsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.unit = const Value.absent(),
    this.category = const Value.absent(),
    this.targetValue = const Value.absent(),
    this.frequencyType = const Value.absent(),
    this.frequencyConfig = const Value.absent(),
    this.startLocalDate = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.definitionVersion = const Value.absent(),
    this.definitions = const Value.absent(),
    this.activeRanges = const Value.absent(),
    this.extra = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitsCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.unit = const Value.absent(),
    this.category = const Value.absent(),
    this.targetValue = const Value.absent(),
    this.frequencyType = const Value.absent(),
    this.frequencyConfig = const Value.absent(),
    this.startLocalDate = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required int version,
    this.definitionVersion = const Value.absent(),
    this.definitions = const Value.absent(),
    this.activeRanges = const Value.absent(),
    this.extra = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       version = Value(version);
  static Insertable<ConfirmedHabit> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? unit,
    Expression<String>? category,
    Expression<String>? targetValue,
    Expression<String>? frequencyType,
    Expression<String>? frequencyConfig,
    Expression<String>? startLocalDate,
    Expression<String>? archivedAt,
    Expression<int>? version,
    Expression<int>? definitionVersion,
    Expression<String>? definitions,
    Expression<String>? activeRanges,
    Expression<String>? extra,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (unit != null) 'unit': unit,
      if (category != null) 'category': category,
      if (targetValue != null) 'target_value': targetValue,
      if (frequencyType != null) 'frequency_type': frequencyType,
      if (frequencyConfig != null) 'frequency_config': frequencyConfig,
      if (startLocalDate != null) 'start_local_date': startLocalDate,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (version != null) 'version': version,
      if (definitionVersion != null) 'definition_version': definitionVersion,
      if (definitions != null) 'definitions': definitions,
      if (activeRanges != null) 'active_ranges': activeRanges,
      if (extra != null) 'extra': extra,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitsCompanion copyWith({
    Value<String>? id,
    Value<String?>? name,
    Value<String?>? type,
    Value<String?>? unit,
    Value<String?>? category,
    Value<String?>? targetValue,
    Value<String?>? frequencyType,
    Value<String?>? frequencyConfig,
    Value<String?>? startLocalDate,
    Value<String?>? archivedAt,
    Value<int>? version,
    Value<int?>? definitionVersion,
    Value<String?>? definitions,
    Value<String?>? activeRanges,
    Value<String>? extra,
    Value<int>? rowid,
  }) {
    return HabitsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      targetValue: targetValue ?? this.targetValue,
      frequencyType: frequencyType ?? this.frequencyType,
      frequencyConfig: frequencyConfig ?? this.frequencyConfig,
      startLocalDate: startLocalDate ?? this.startLocalDate,
      archivedAt: archivedAt ?? this.archivedAt,
      version: version ?? this.version,
      definitionVersion: definitionVersion ?? this.definitionVersion,
      definitions: definitions ?? this.definitions,
      activeRanges: activeRanges ?? this.activeRanges,
      extra: extra ?? this.extra,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (targetValue.present) {
      map['target_value'] = Variable<String>(targetValue.value);
    }
    if (frequencyType.present) {
      map['frequency_type'] = Variable<String>(frequencyType.value);
    }
    if (frequencyConfig.present) {
      map['frequency_config'] = Variable<String>(frequencyConfig.value);
    }
    if (startLocalDate.present) {
      map['start_local_date'] = Variable<String>(startLocalDate.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<String>(archivedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (definitionVersion.present) {
      map['definition_version'] = Variable<int>(definitionVersion.value);
    }
    if (definitions.present) {
      map['definitions'] = Variable<String>(definitions.value);
    }
    if (activeRanges.present) {
      map['active_ranges'] = Variable<String>(activeRanges.value);
    }
    if (extra.present) {
      map['extra'] = Variable<String>(extra.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('unit: $unit, ')
          ..write('category: $category, ')
          ..write('targetValue: $targetValue, ')
          ..write('frequencyType: $frequencyType, ')
          ..write('frequencyConfig: $frequencyConfig, ')
          ..write('startLocalDate: $startLocalDate, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('version: $version, ')
          ..write('definitionVersion: $definitionVersion, ')
          ..write('definitions: $definitions, ')
          ..write('activeRanges: $activeRanges, ')
          ..write('extra: $extra, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitLogsTable extends HabitLogs
    with TableInfo<$HabitLogsTable, ConfirmedLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
    'habit_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logDateMeta = const VerificationMeta(
    'logDate',
  );
  @override
  late final GeneratedColumn<String> logDate = GeneratedColumn<String>(
    'log_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<String> occurredAt = GeneratedColumn<String>(
    'occurred_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolvedTimezoneMeta = const VerificationMeta(
    'resolvedTimezone',
  );
  @override
  late final GeneratedColumn<String> resolvedTimezone = GeneratedColumn<String>(
    'resolved_timezone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayStartOffsetMinutesMeta =
      const VerificationMeta('dayStartOffsetMinutes');
  @override
  late final GeneratedColumn<int> dayStartOffsetMinutes = GeneratedColumn<int>(
    'day_start_offset_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _definitionVersionMeta = const VerificationMeta(
    'definitionVersion',
  );
  @override
  late final GeneratedColumn<int> definitionVersion = GeneratedColumn<int>(
    'definition_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extraMeta = const VerificationMeta('extra');
  @override
  late final GeneratedColumn<String> extra = GeneratedColumn<String>(
    'extra',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    habitId,
    logDate,
    value,
    detail,
    occurredAt,
    completedAt,
    resolvedTimezone,
    dayStartOffsetMinutes,
    definitionVersion,
    version,
    deletedAt,
    extra,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConfirmedLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    }
    if (data.containsKey('log_date')) {
      context.handle(
        _logDateMeta,
        logDate.isAcceptableOrUnknown(data['log_date']!, _logDateMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('resolved_timezone')) {
      context.handle(
        _resolvedTimezoneMeta,
        resolvedTimezone.isAcceptableOrUnknown(
          data['resolved_timezone']!,
          _resolvedTimezoneMeta,
        ),
      );
    }
    if (data.containsKey('day_start_offset_minutes')) {
      context.handle(
        _dayStartOffsetMinutesMeta,
        dayStartOffsetMinutes.isAcceptableOrUnknown(
          data['day_start_offset_minutes']!,
          _dayStartOffsetMinutesMeta,
        ),
      );
    }
    if (data.containsKey('definition_version')) {
      context.handle(
        _definitionVersionMeta,
        definitionVersion.isAcceptableOrUnknown(
          data['definition_version']!,
          _definitionVersionMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('extra')) {
      context.handle(
        _extraMeta,
        extra.isAcceptableOrUnknown(data['extra']!, _extraMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConfirmedLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConfirmedLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      ),
      logDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}log_date'],
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      ),
      resolvedTimezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolved_timezone'],
      ),
      dayStartOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_start_offset_minutes'],
      ),
      definitionVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}definition_version'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      extra: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra'],
      )!,
    );
  }

  @override
  $HabitLogsTable createAlias(String alias) {
    return $HabitLogsTable(attachedDatabase, alias);
  }
}

class ConfirmedLog extends DataClass implements Insertable<ConfirmedLog> {
  final String id;
  final String? habitId;
  final String? logDate;

  /// Wire value as JSON.
  final String? value;
  final String? detail;
  final String? occurredAt;
  final String? completedAt;
  final String? resolvedTimezone;
  final int? dayStartOffsetMinutes;
  final int? definitionVersion;
  final int version;
  final String? deletedAt;
  final String extra;
  const ConfirmedLog({
    required this.id,
    this.habitId,
    this.logDate,
    this.value,
    this.detail,
    this.occurredAt,
    this.completedAt,
    this.resolvedTimezone,
    this.dayStartOffsetMinutes,
    this.definitionVersion,
    required this.version,
    this.deletedAt,
    required this.extra,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || habitId != null) {
      map['habit_id'] = Variable<String>(habitId);
    }
    if (!nullToAbsent || logDate != null) {
      map['log_date'] = Variable<String>(logDate);
    }
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    if (!nullToAbsent || occurredAt != null) {
      map['occurred_at'] = Variable<String>(occurredAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    if (!nullToAbsent || resolvedTimezone != null) {
      map['resolved_timezone'] = Variable<String>(resolvedTimezone);
    }
    if (!nullToAbsent || dayStartOffsetMinutes != null) {
      map['day_start_offset_minutes'] = Variable<int>(dayStartOffsetMinutes);
    }
    if (!nullToAbsent || definitionVersion != null) {
      map['definition_version'] = Variable<int>(definitionVersion);
    }
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['extra'] = Variable<String>(extra);
    return map;
  }

  HabitLogsCompanion toCompanion(bool nullToAbsent) {
    return HabitLogsCompanion(
      id: Value(id),
      habitId: habitId == null && nullToAbsent
          ? const Value.absent()
          : Value(habitId),
      logDate: logDate == null && nullToAbsent
          ? const Value.absent()
          : Value(logDate),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      occurredAt: occurredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(occurredAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      resolvedTimezone: resolvedTimezone == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedTimezone),
      dayStartOffsetMinutes: dayStartOffsetMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(dayStartOffsetMinutes),
      definitionVersion: definitionVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(definitionVersion),
      version: Value(version),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      extra: Value(extra),
    );
  }

  factory ConfirmedLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConfirmedLog(
      id: serializer.fromJson<String>(json['id']),
      habitId: serializer.fromJson<String?>(json['habitId']),
      logDate: serializer.fromJson<String?>(json['logDate']),
      value: serializer.fromJson<String?>(json['value']),
      detail: serializer.fromJson<String?>(json['detail']),
      occurredAt: serializer.fromJson<String?>(json['occurredAt']),
      completedAt: serializer.fromJson<String?>(json['completedAt']),
      resolvedTimezone: serializer.fromJson<String?>(json['resolvedTimezone']),
      dayStartOffsetMinutes: serializer.fromJson<int?>(
        json['dayStartOffsetMinutes'],
      ),
      definitionVersion: serializer.fromJson<int?>(json['definitionVersion']),
      version: serializer.fromJson<int>(json['version']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      extra: serializer.fromJson<String>(json['extra']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'habitId': serializer.toJson<String?>(habitId),
      'logDate': serializer.toJson<String?>(logDate),
      'value': serializer.toJson<String?>(value),
      'detail': serializer.toJson<String?>(detail),
      'occurredAt': serializer.toJson<String?>(occurredAt),
      'completedAt': serializer.toJson<String?>(completedAt),
      'resolvedTimezone': serializer.toJson<String?>(resolvedTimezone),
      'dayStartOffsetMinutes': serializer.toJson<int?>(dayStartOffsetMinutes),
      'definitionVersion': serializer.toJson<int?>(definitionVersion),
      'version': serializer.toJson<int>(version),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'extra': serializer.toJson<String>(extra),
    };
  }

  ConfirmedLog copyWith({
    String? id,
    Value<String?> habitId = const Value.absent(),
    Value<String?> logDate = const Value.absent(),
    Value<String?> value = const Value.absent(),
    Value<String?> detail = const Value.absent(),
    Value<String?> occurredAt = const Value.absent(),
    Value<String?> completedAt = const Value.absent(),
    Value<String?> resolvedTimezone = const Value.absent(),
    Value<int?> dayStartOffsetMinutes = const Value.absent(),
    Value<int?> definitionVersion = const Value.absent(),
    int? version,
    Value<String?> deletedAt = const Value.absent(),
    String? extra,
  }) => ConfirmedLog(
    id: id ?? this.id,
    habitId: habitId.present ? habitId.value : this.habitId,
    logDate: logDate.present ? logDate.value : this.logDate,
    value: value.present ? value.value : this.value,
    detail: detail.present ? detail.value : this.detail,
    occurredAt: occurredAt.present ? occurredAt.value : this.occurredAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    resolvedTimezone: resolvedTimezone.present
        ? resolvedTimezone.value
        : this.resolvedTimezone,
    dayStartOffsetMinutes: dayStartOffsetMinutes.present
        ? dayStartOffsetMinutes.value
        : this.dayStartOffsetMinutes,
    definitionVersion: definitionVersion.present
        ? definitionVersion.value
        : this.definitionVersion,
    version: version ?? this.version,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    extra: extra ?? this.extra,
  );
  ConfirmedLog copyWithCompanion(HabitLogsCompanion data) {
    return ConfirmedLog(
      id: data.id.present ? data.id.value : this.id,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      logDate: data.logDate.present ? data.logDate.value : this.logDate,
      value: data.value.present ? data.value.value : this.value,
      detail: data.detail.present ? data.detail.value : this.detail,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      resolvedTimezone: data.resolvedTimezone.present
          ? data.resolvedTimezone.value
          : this.resolvedTimezone,
      dayStartOffsetMinutes: data.dayStartOffsetMinutes.present
          ? data.dayStartOffsetMinutes.value
          : this.dayStartOffsetMinutes,
      definitionVersion: data.definitionVersion.present
          ? data.definitionVersion.value
          : this.definitionVersion,
      version: data.version.present ? data.version.value : this.version,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      extra: data.extra.present ? data.extra.value : this.extra,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConfirmedLog(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('logDate: $logDate, ')
          ..write('value: $value, ')
          ..write('detail: $detail, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('resolvedTimezone: $resolvedTimezone, ')
          ..write('dayStartOffsetMinutes: $dayStartOffsetMinutes, ')
          ..write('definitionVersion: $definitionVersion, ')
          ..write('version: $version, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('extra: $extra')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    habitId,
    logDate,
    value,
    detail,
    occurredAt,
    completedAt,
    resolvedTimezone,
    dayStartOffsetMinutes,
    definitionVersion,
    version,
    deletedAt,
    extra,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfirmedLog &&
          other.id == this.id &&
          other.habitId == this.habitId &&
          other.logDate == this.logDate &&
          other.value == this.value &&
          other.detail == this.detail &&
          other.occurredAt == this.occurredAt &&
          other.completedAt == this.completedAt &&
          other.resolvedTimezone == this.resolvedTimezone &&
          other.dayStartOffsetMinutes == this.dayStartOffsetMinutes &&
          other.definitionVersion == this.definitionVersion &&
          other.version == this.version &&
          other.deletedAt == this.deletedAt &&
          other.extra == this.extra);
}

class HabitLogsCompanion extends UpdateCompanion<ConfirmedLog> {
  final Value<String> id;
  final Value<String?> habitId;
  final Value<String?> logDate;
  final Value<String?> value;
  final Value<String?> detail;
  final Value<String?> occurredAt;
  final Value<String?> completedAt;
  final Value<String?> resolvedTimezone;
  final Value<int?> dayStartOffsetMinutes;
  final Value<int?> definitionVersion;
  final Value<int> version;
  final Value<String?> deletedAt;
  final Value<String> extra;
  final Value<int> rowid;
  const HabitLogsCompanion({
    this.id = const Value.absent(),
    this.habitId = const Value.absent(),
    this.logDate = const Value.absent(),
    this.value = const Value.absent(),
    this.detail = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.resolvedTimezone = const Value.absent(),
    this.dayStartOffsetMinutes = const Value.absent(),
    this.definitionVersion = const Value.absent(),
    this.version = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.extra = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitLogsCompanion.insert({
    required String id,
    this.habitId = const Value.absent(),
    this.logDate = const Value.absent(),
    this.value = const Value.absent(),
    this.detail = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.resolvedTimezone = const Value.absent(),
    this.dayStartOffsetMinutes = const Value.absent(),
    this.definitionVersion = const Value.absent(),
    required int version,
    this.deletedAt = const Value.absent(),
    this.extra = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       version = Value(version);
  static Insertable<ConfirmedLog> custom({
    Expression<String>? id,
    Expression<String>? habitId,
    Expression<String>? logDate,
    Expression<String>? value,
    Expression<String>? detail,
    Expression<String>? occurredAt,
    Expression<String>? completedAt,
    Expression<String>? resolvedTimezone,
    Expression<int>? dayStartOffsetMinutes,
    Expression<int>? definitionVersion,
    Expression<int>? version,
    Expression<String>? deletedAt,
    Expression<String>? extra,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      if (logDate != null) 'log_date': logDate,
      if (value != null) 'value': value,
      if (detail != null) 'detail': detail,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (resolvedTimezone != null) 'resolved_timezone': resolvedTimezone,
      if (dayStartOffsetMinutes != null)
        'day_start_offset_minutes': dayStartOffsetMinutes,
      if (definitionVersion != null) 'definition_version': definitionVersion,
      if (version != null) 'version': version,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (extra != null) 'extra': extra,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitLogsCompanion copyWith({
    Value<String>? id,
    Value<String?>? habitId,
    Value<String?>? logDate,
    Value<String?>? value,
    Value<String?>? detail,
    Value<String?>? occurredAt,
    Value<String?>? completedAt,
    Value<String?>? resolvedTimezone,
    Value<int?>? dayStartOffsetMinutes,
    Value<int?>? definitionVersion,
    Value<int>? version,
    Value<String?>? deletedAt,
    Value<String>? extra,
    Value<int>? rowid,
  }) {
    return HabitLogsCompanion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      logDate: logDate ?? this.logDate,
      value: value ?? this.value,
      detail: detail ?? this.detail,
      occurredAt: occurredAt ?? this.occurredAt,
      completedAt: completedAt ?? this.completedAt,
      resolvedTimezone: resolvedTimezone ?? this.resolvedTimezone,
      dayStartOffsetMinutes:
          dayStartOffsetMinutes ?? this.dayStartOffsetMinutes,
      definitionVersion: definitionVersion ?? this.definitionVersion,
      version: version ?? this.version,
      deletedAt: deletedAt ?? this.deletedAt,
      extra: extra ?? this.extra,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (logDate.present) {
      map['log_date'] = Variable<String>(logDate.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<String>(occurredAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (resolvedTimezone.present) {
      map['resolved_timezone'] = Variable<String>(resolvedTimezone.value);
    }
    if (dayStartOffsetMinutes.present) {
      map['day_start_offset_minutes'] = Variable<int>(
        dayStartOffsetMinutes.value,
      );
    }
    if (definitionVersion.present) {
      map['definition_version'] = Variable<int>(definitionVersion.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (extra.present) {
      map['extra'] = Variable<String>(extra.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitLogsCompanion(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('logDate: $logDate, ')
          ..write('value: $value, ')
          ..write('detail: $detail, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('resolvedTimezone: $resolvedTimezone, ')
          ..write('dayStartOffsetMinutes: $dayStartOffsetMinutes, ')
          ..write('definitionVersion: $definitionVersion, ')
          ..write('version: $version, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('extra: $extra, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OpaqueEntitiesTable extends OpaqueEntities
    with TableInfo<$OpaqueEntitiesTable, OpaqueEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OpaqueEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entityType,
    entityId,
    version,
    operation,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'opaque_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<OpaqueEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entityType, entityId};
  @override
  OpaqueEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OpaqueEntity(
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $OpaqueEntitiesTable createAlias(String alias) {
    return $OpaqueEntitiesTable(attachedDatabase, alias);
  }
}

class OpaqueEntity extends DataClass implements Insertable<OpaqueEntity> {
  final String entityType;
  final String entityId;
  final int version;
  final String operation;
  final String payload;
  const OpaqueEntity({
    required this.entityType,
    required this.entityId,
    required this.version,
    required this.operation,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['version'] = Variable<int>(version);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  OpaqueEntitiesCompanion toCompanion(bool nullToAbsent) {
    return OpaqueEntitiesCompanion(
      entityType: Value(entityType),
      entityId: Value(entityId),
      version: Value(version),
      operation: Value(operation),
      payload: Value(payload),
    );
  }

  factory OpaqueEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OpaqueEntity(
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      version: serializer.fromJson<int>(json['version']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'version': serializer.toJson<int>(version),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
    };
  }

  OpaqueEntity copyWith({
    String? entityType,
    String? entityId,
    int? version,
    String? operation,
    String? payload,
  }) => OpaqueEntity(
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    version: version ?? this.version,
    operation: operation ?? this.operation,
    payload: payload ?? this.payload,
  );
  OpaqueEntity copyWithCompanion(OpaqueEntitiesCompanion data) {
    return OpaqueEntity(
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      version: data.version.present ? data.version.value : this.version,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OpaqueEntity(')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('version: $version, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(entityType, entityId, version, operation, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OpaqueEntity &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.version == this.version &&
          other.operation == this.operation &&
          other.payload == this.payload);
}

class OpaqueEntitiesCompanion extends UpdateCompanion<OpaqueEntity> {
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<int> version;
  final Value<String> operation;
  final Value<String> payload;
  final Value<int> rowid;
  const OpaqueEntitiesCompanion({
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.version = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OpaqueEntitiesCompanion.insert({
    required String entityType,
    required String entityId,
    required int version,
    required String operation,
    required String payload,
    this.rowid = const Value.absent(),
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       version = Value(version),
       operation = Value(operation),
       payload = Value(payload);
  static Insertable<OpaqueEntity> custom({
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? version,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (version != null) 'version': version,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OpaqueEntitiesCompanion copyWith({
    Value<String>? entityType,
    Value<String>? entityId,
    Value<int>? version,
    Value<String>? operation,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return OpaqueEntitiesCompanion(
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      version: version ?? this.version,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OpaqueEntitiesCompanion(')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('version: $version, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<String> occurredAt = GeneratedColumn<String>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedTimezoneMeta = const VerificationMeta(
    'capturedTimezone',
  );
  @override
  late final GeneratedColumn<String> capturedTimezone = GeneratedColumn<String>(
    'captured_timezone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localDateHintMeta = const VerificationMeta(
    'localDateHint',
  );
  @override
  late final GeneratedColumn<String> localDateHint = GeneratedColumn<String>(
    'local_date_hint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
    'habit_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<int> nextAttemptAt = GeneratedColumn<int>(
    'next_attempt_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstFailedAtMeta = const VerificationMeta(
    'firstFailedAt',
  );
  @override
  late final GeneratedColumn<int> firstFailedAt = GeneratedColumn<int>(
    'first_failed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _surfacedMeta = const VerificationMeta(
    'surfaced',
  );
  @override
  late final GeneratedColumn<bool> surfaced = GeneratedColumn<bool>(
    'surfaced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("surfaced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ackVersionMeta = const VerificationMeta(
    'ackVersion',
  );
  @override
  late final GeneratedColumn<int> ackVersion = GeneratedColumn<int>(
    'ack_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    mutationId,
    entity,
    entityId,
    operation,
    baseVersion,
    occurredAt,
    capturedTimezone,
    localDateHint,
    payload,
    habitId,
    state,
    attempts,
    nextAttemptAt,
    firstFailedAt,
    surfaced,
    lastError,
    ackVersion,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('captured_timezone')) {
      context.handle(
        _capturedTimezoneMeta,
        capturedTimezone.isAcceptableOrUnknown(
          data['captured_timezone']!,
          _capturedTimezoneMeta,
        ),
      );
    }
    if (data.containsKey('local_date_hint')) {
      context.handle(
        _localDateHintMeta,
        localDateHint.isAcceptableOrUnknown(
          data['local_date_hint']!,
          _localDateHintMeta,
        ),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('first_failed_at')) {
      context.handle(
        _firstFailedAtMeta,
        firstFailedAt.isAcceptableOrUnknown(
          data['first_failed_at']!,
          _firstFailedAtMeta,
        ),
      );
    }
    if (data.containsKey('surfaced')) {
      context.handle(
        _surfacedMeta,
        surfaced.isAcceptableOrUnknown(data['surfaced']!, _surfacedMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('ack_version')) {
      context.handle(
        _ackVersionMeta,
        ackVersion.isAcceptableOrUnknown(data['ack_version']!, _ackVersionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_at'],
      )!,
      capturedTimezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}captured_timezone'],
      ),
      localDateHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date_hint'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_attempt_at'],
      ),
      firstFailedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_failed_at'],
      ),
      surfaced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}surfaced'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      ackVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ack_version'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final int seq;
  final String mutationId;
  final String entity;
  final String entityId;
  final String operation;
  final int? baseVersion;
  final String occurredAt;
  final String? capturedTimezone;
  final String? localDateHint;
  final String payload;

  /// For log rows: the habit they belong to (dependency and remapping).
  final String? habitId;
  final String state;
  final int attempts;
  final int? nextAttemptAt;
  final int? firstFailedAt;
  final bool surfaced;
  final String? lastError;
  final int? ackVersion;
  final int createdAt;
  const OutboxRow({
    required this.seq,
    required this.mutationId,
    required this.entity,
    required this.entityId,
    required this.operation,
    this.baseVersion,
    required this.occurredAt,
    this.capturedTimezone,
    this.localDateHint,
    required this.payload,
    this.habitId,
    required this.state,
    required this.attempts,
    this.nextAttemptAt,
    this.firstFailedAt,
    required this.surfaced,
    this.lastError,
    this.ackVersion,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['mutation_id'] = Variable<String>(mutationId);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['occurred_at'] = Variable<String>(occurredAt);
    if (!nullToAbsent || capturedTimezone != null) {
      map['captured_timezone'] = Variable<String>(capturedTimezone);
    }
    if (!nullToAbsent || localDateHint != null) {
      map['local_date_hint'] = Variable<String>(localDateHint);
    }
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || habitId != null) {
      map['habit_id'] = Variable<String>(habitId);
    }
    map['state'] = Variable<String>(state);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<int>(nextAttemptAt);
    }
    if (!nullToAbsent || firstFailedAt != null) {
      map['first_failed_at'] = Variable<int>(firstFailedAt);
    }
    map['surfaced'] = Variable<bool>(surfaced);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || ackVersion != null) {
      map['ack_version'] = Variable<int>(ackVersion);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      seq: Value(seq),
      mutationId: Value(mutationId),
      entity: Value(entity),
      entityId: Value(entityId),
      operation: Value(operation),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      occurredAt: Value(occurredAt),
      capturedTimezone: capturedTimezone == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedTimezone),
      localDateHint: localDateHint == null && nullToAbsent
          ? const Value.absent()
          : Value(localDateHint),
      payload: Value(payload),
      habitId: habitId == null && nullToAbsent
          ? const Value.absent()
          : Value(habitId),
      state: Value(state),
      attempts: Value(attempts),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      firstFailedAt: firstFailedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(firstFailedAt),
      surfaced: Value(surfaced),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      ackVersion: ackVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(ackVersion),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      seq: serializer.fromJson<int>(json['seq']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      baseVersion: serializer.fromJson<int?>(json['baseVersion']),
      occurredAt: serializer.fromJson<String>(json['occurredAt']),
      capturedTimezone: serializer.fromJson<String?>(json['capturedTimezone']),
      localDateHint: serializer.fromJson<String?>(json['localDateHint']),
      payload: serializer.fromJson<String>(json['payload']),
      habitId: serializer.fromJson<String?>(json['habitId']),
      state: serializer.fromJson<String>(json['state']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<int?>(json['nextAttemptAt']),
      firstFailedAt: serializer.fromJson<int?>(json['firstFailedAt']),
      surfaced: serializer.fromJson<bool>(json['surfaced']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      ackVersion: serializer.fromJson<int?>(json['ackVersion']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'mutationId': serializer.toJson<String>(mutationId),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'baseVersion': serializer.toJson<int?>(baseVersion),
      'occurredAt': serializer.toJson<String>(occurredAt),
      'capturedTimezone': serializer.toJson<String?>(capturedTimezone),
      'localDateHint': serializer.toJson<String?>(localDateHint),
      'payload': serializer.toJson<String>(payload),
      'habitId': serializer.toJson<String?>(habitId),
      'state': serializer.toJson<String>(state),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<int?>(nextAttemptAt),
      'firstFailedAt': serializer.toJson<int?>(firstFailedAt),
      'surfaced': serializer.toJson<bool>(surfaced),
      'lastError': serializer.toJson<String?>(lastError),
      'ackVersion': serializer.toJson<int?>(ackVersion),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  OutboxRow copyWith({
    int? seq,
    String? mutationId,
    String? entity,
    String? entityId,
    String? operation,
    Value<int?> baseVersion = const Value.absent(),
    String? occurredAt,
    Value<String?> capturedTimezone = const Value.absent(),
    Value<String?> localDateHint = const Value.absent(),
    String? payload,
    Value<String?> habitId = const Value.absent(),
    String? state,
    int? attempts,
    Value<int?> nextAttemptAt = const Value.absent(),
    Value<int?> firstFailedAt = const Value.absent(),
    bool? surfaced,
    Value<String?> lastError = const Value.absent(),
    Value<int?> ackVersion = const Value.absent(),
    int? createdAt,
  }) => OutboxRow(
    seq: seq ?? this.seq,
    mutationId: mutationId ?? this.mutationId,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    occurredAt: occurredAt ?? this.occurredAt,
    capturedTimezone: capturedTimezone.present
        ? capturedTimezone.value
        : this.capturedTimezone,
    localDateHint: localDateHint.present
        ? localDateHint.value
        : this.localDateHint,
    payload: payload ?? this.payload,
    habitId: habitId.present ? habitId.value : this.habitId,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    firstFailedAt: firstFailedAt.present
        ? firstFailedAt.value
        : this.firstFailedAt,
    surfaced: surfaced ?? this.surfaced,
    lastError: lastError.present ? lastError.value : this.lastError,
    ackVersion: ackVersion.present ? ackVersion.value : this.ackVersion,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      capturedTimezone: data.capturedTimezone.present
          ? data.capturedTimezone.value
          : this.capturedTimezone,
      localDateHint: data.localDateHint.present
          ? data.localDateHint.value
          : this.localDateHint,
      payload: data.payload.present ? data.payload.value : this.payload,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      firstFailedAt: data.firstFailedAt.present
          ? data.firstFailedAt.value
          : this.firstFailedAt,
      surfaced: data.surfaced.present ? data.surfaced.value : this.surfaced,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      ackVersion: data.ackVersion.present
          ? data.ackVersion.value
          : this.ackVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('seq: $seq, ')
          ..write('mutationId: $mutationId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('capturedTimezone: $capturedTimezone, ')
          ..write('localDateHint: $localDateHint, ')
          ..write('payload: $payload, ')
          ..write('habitId: $habitId, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('firstFailedAt: $firstFailedAt, ')
          ..write('surfaced: $surfaced, ')
          ..write('lastError: $lastError, ')
          ..write('ackVersion: $ackVersion, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    mutationId,
    entity,
    entityId,
    operation,
    baseVersion,
    occurredAt,
    capturedTimezone,
    localDateHint,
    payload,
    habitId,
    state,
    attempts,
    nextAttemptAt,
    firstFailedAt,
    surfaced,
    lastError,
    ackVersion,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.seq == this.seq &&
          other.mutationId == this.mutationId &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.baseVersion == this.baseVersion &&
          other.occurredAt == this.occurredAt &&
          other.capturedTimezone == this.capturedTimezone &&
          other.localDateHint == this.localDateHint &&
          other.payload == this.payload &&
          other.habitId == this.habitId &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.firstFailedAt == this.firstFailedAt &&
          other.surfaced == this.surfaced &&
          other.lastError == this.lastError &&
          other.ackVersion == this.ackVersion &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> seq;
  final Value<String> mutationId;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<int?> baseVersion;
  final Value<String> occurredAt;
  final Value<String?> capturedTimezone;
  final Value<String?> localDateHint;
  final Value<String> payload;
  final Value<String?> habitId;
  final Value<String> state;
  final Value<int> attempts;
  final Value<int?> nextAttemptAt;
  final Value<int?> firstFailedAt;
  final Value<bool> surfaced;
  final Value<String?> lastError;
  final Value<int?> ackVersion;
  final Value<int> createdAt;
  const OutboxCompanion({
    this.seq = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.capturedTimezone = const Value.absent(),
    this.localDateHint = const Value.absent(),
    this.payload = const Value.absent(),
    this.habitId = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.firstFailedAt = const Value.absent(),
    this.surfaced = const Value.absent(),
    this.lastError = const Value.absent(),
    this.ackVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String mutationId,
    required String entity,
    required String entityId,
    required String operation,
    this.baseVersion = const Value.absent(),
    required String occurredAt,
    this.capturedTimezone = const Value.absent(),
    this.localDateHint = const Value.absent(),
    required String payload,
    this.habitId = const Value.absent(),
    required String state,
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.firstFailedAt = const Value.absent(),
    this.surfaced = const Value.absent(),
    this.lastError = const Value.absent(),
    this.ackVersion = const Value.absent(),
    required int createdAt,
  }) : mutationId = Value(mutationId),
       entity = Value(entity),
       entityId = Value(entityId),
       operation = Value(operation),
       occurredAt = Value(occurredAt),
       payload = Value(payload),
       state = Value(state),
       createdAt = Value(createdAt);
  static Insertable<OutboxRow> custom({
    Expression<int>? seq,
    Expression<String>? mutationId,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<int>? baseVersion,
    Expression<String>? occurredAt,
    Expression<String>? capturedTimezone,
    Expression<String>? localDateHint,
    Expression<String>? payload,
    Expression<String>? habitId,
    Expression<String>? state,
    Expression<int>? attempts,
    Expression<int>? nextAttemptAt,
    Expression<int>? firstFailedAt,
    Expression<bool>? surfaced,
    Expression<String>? lastError,
    Expression<int>? ackVersion,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (mutationId != null) 'mutation_id': mutationId,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (baseVersion != null) 'base_version': baseVersion,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (capturedTimezone != null) 'captured_timezone': capturedTimezone,
      if (localDateHint != null) 'local_date_hint': localDateHint,
      if (payload != null) 'payload': payload,
      if (habitId != null) 'habit_id': habitId,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (firstFailedAt != null) 'first_failed_at': firstFailedAt,
      if (surfaced != null) 'surfaced': surfaced,
      if (lastError != null) 'last_error': lastError,
      if (ackVersion != null) 'ack_version': ackVersion,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? mutationId,
    Value<String>? entity,
    Value<String>? entityId,
    Value<String>? operation,
    Value<int?>? baseVersion,
    Value<String>? occurredAt,
    Value<String?>? capturedTimezone,
    Value<String?>? localDateHint,
    Value<String>? payload,
    Value<String?>? habitId,
    Value<String>? state,
    Value<int>? attempts,
    Value<int?>? nextAttemptAt,
    Value<int?>? firstFailedAt,
    Value<bool>? surfaced,
    Value<String?>? lastError,
    Value<int?>? ackVersion,
    Value<int>? createdAt,
  }) {
    return OutboxCompanion(
      seq: seq ?? this.seq,
      mutationId: mutationId ?? this.mutationId,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      baseVersion: baseVersion ?? this.baseVersion,
      occurredAt: occurredAt ?? this.occurredAt,
      capturedTimezone: capturedTimezone ?? this.capturedTimezone,
      localDateHint: localDateHint ?? this.localDateHint,
      payload: payload ?? this.payload,
      habitId: habitId ?? this.habitId,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      firstFailedAt: firstFailedAt ?? this.firstFailedAt,
      surfaced: surfaced ?? this.surfaced,
      lastError: lastError ?? this.lastError,
      ackVersion: ackVersion ?? this.ackVersion,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<String>(occurredAt.value);
    }
    if (capturedTimezone.present) {
      map['captured_timezone'] = Variable<String>(capturedTimezone.value);
    }
    if (localDateHint.present) {
      map['local_date_hint'] = Variable<String>(localDateHint.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<int>(nextAttemptAt.value);
    }
    if (firstFailedAt.present) {
      map['first_failed_at'] = Variable<int>(firstFailedAt.value);
    }
    if (surfaced.present) {
      map['surfaced'] = Variable<bool>(surfaced.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (ackVersion.present) {
      map['ack_version'] = Variable<int>(ackVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('mutationId: $mutationId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('capturedTimezone: $capturedTimezone, ')
          ..write('localDateHint: $localDateHint, ')
          ..write('payload: $payload, ')
          ..write('habitId: $habitId, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('firstFailedAt: $firstFailedAt, ')
          ..write('surfaced: $surfaced, ')
          ..write('lastError: $lastError, ')
          ..write('ackVersion: $ackVersion, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bootstrapCursorMeta = const VerificationMeta(
    'bootstrapCursor',
  );
  @override
  late final GeneratedColumn<String> bootstrapCursor = GeneratedColumn<String>(
    'bootstrap_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calendarTimezoneMeta = const VerificationMeta(
    'calendarTimezone',
  );
  @override
  late final GeneratedColumn<String> calendarTimezone = GeneratedColumn<String>(
    'calendar_timezone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calendarDayStartOffsetMeta =
      const VerificationMeta('calendarDayStartOffset');
  @override
  late final GeneratedColumn<int> calendarDayStartOffset = GeneratedColumn<int>(
    'calendar_day_start_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _calendarEffectiveAtMeta =
      const VerificationMeta('calendarEffectiveAt');
  @override
  late final GeneratedColumn<String> calendarEffectiveAt =
      GeneratedColumn<String>(
        'calendar_effective_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _capabilitiesMeta = const VerificationMeta(
    'capabilities',
  );
  @override
  late final GeneratedColumn<String> capabilities = GeneratedColumn<String>(
    'capabilities',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userPayloadMeta = const VerificationMeta(
    'userPayload',
  );
  @override
  late final GeneratedColumn<String> userPayload = GeneratedColumn<String>(
    'user_payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leaseOwnerMeta = const VerificationMeta(
    'leaseOwner',
  );
  @override
  late final GeneratedColumn<String> leaseOwner = GeneratedColumn<String>(
    'lease_owner',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leaseUntilMeta = const VerificationMeta(
    'leaseUntil',
  );
  @override
  late final GeneratedColumn<int> leaseUntil = GeneratedColumn<int>(
    'lease_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextSyncAtMeta = const VerificationMeta(
    'nextSyncAt',
  );
  @override
  late final GeneratedColumn<int> nextSyncAt = GeneratedColumn<int>(
    'next_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncedAt = GeneratedColumn<int>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _consecutiveFailuresMeta =
      const VerificationMeta('consecutiveFailures');
  @override
  late final GeneratedColumn<int> consecutiveFailures = GeneratedColumn<int>(
    'consecutive_failures',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _backoffUntilMeta = const VerificationMeta(
    'backoffUntil',
  );
  @override
  late final GeneratedColumn<int> backoffUntil = GeneratedColumn<int>(
    'backoff_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestRejectionsMeta = const VerificationMeta(
    'requestRejections',
  );
  @override
  late final GeneratedColumn<int> requestRejections = GeneratedColumn<int>(
    'request_rejections',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _statusCodeMeta = const VerificationMeta(
    'statusCode',
  );
  @override
  late final GeneratedColumn<String> statusCode = GeneratedColumn<String>(
    'status_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clockSkewMsMeta = const VerificationMeta(
    'clockSkewMs',
  );
  @override
  late final GeneratedColumn<int> clockSkewMs = GeneratedColumn<int>(
    'clock_skew_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _appVersionMeta = const VerificationMeta(
    'appVersion',
  );
  @override
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
    'app_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    deviceId,
    cursor,
    bootstrapCursor,
    calendarTimezone,
    calendarDayStartOffset,
    calendarEffectiveAt,
    capabilities,
    userPayload,
    leaseOwner,
    leaseUntil,
    nextSyncAt,
    lastSyncedAt,
    consecutiveFailures,
    backoffUntil,
    requestRejections,
    status,
    statusCode,
    lastError,
    clockSkewMs,
    appVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    if (data.containsKey('bootstrap_cursor')) {
      context.handle(
        _bootstrapCursorMeta,
        bootstrapCursor.isAcceptableOrUnknown(
          data['bootstrap_cursor']!,
          _bootstrapCursorMeta,
        ),
      );
    }
    if (data.containsKey('calendar_timezone')) {
      context.handle(
        _calendarTimezoneMeta,
        calendarTimezone.isAcceptableOrUnknown(
          data['calendar_timezone']!,
          _calendarTimezoneMeta,
        ),
      );
    }
    if (data.containsKey('calendar_day_start_offset')) {
      context.handle(
        _calendarDayStartOffsetMeta,
        calendarDayStartOffset.isAcceptableOrUnknown(
          data['calendar_day_start_offset']!,
          _calendarDayStartOffsetMeta,
        ),
      );
    }
    if (data.containsKey('calendar_effective_at')) {
      context.handle(
        _calendarEffectiveAtMeta,
        calendarEffectiveAt.isAcceptableOrUnknown(
          data['calendar_effective_at']!,
          _calendarEffectiveAtMeta,
        ),
      );
    }
    if (data.containsKey('capabilities')) {
      context.handle(
        _capabilitiesMeta,
        capabilities.isAcceptableOrUnknown(
          data['capabilities']!,
          _capabilitiesMeta,
        ),
      );
    }
    if (data.containsKey('user_payload')) {
      context.handle(
        _userPayloadMeta,
        userPayload.isAcceptableOrUnknown(
          data['user_payload']!,
          _userPayloadMeta,
        ),
      );
    }
    if (data.containsKey('lease_owner')) {
      context.handle(
        _leaseOwnerMeta,
        leaseOwner.isAcceptableOrUnknown(data['lease_owner']!, _leaseOwnerMeta),
      );
    }
    if (data.containsKey('lease_until')) {
      context.handle(
        _leaseUntilMeta,
        leaseUntil.isAcceptableOrUnknown(data['lease_until']!, _leaseUntilMeta),
      );
    }
    if (data.containsKey('next_sync_at')) {
      context.handle(
        _nextSyncAtMeta,
        nextSyncAt.isAcceptableOrUnknown(
          data['next_sync_at']!,
          _nextSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('consecutive_failures')) {
      context.handle(
        _consecutiveFailuresMeta,
        consecutiveFailures.isAcceptableOrUnknown(
          data['consecutive_failures']!,
          _consecutiveFailuresMeta,
        ),
      );
    }
    if (data.containsKey('backoff_until')) {
      context.handle(
        _backoffUntilMeta,
        backoffUntil.isAcceptableOrUnknown(
          data['backoff_until']!,
          _backoffUntilMeta,
        ),
      );
    }
    if (data.containsKey('request_rejections')) {
      context.handle(
        _requestRejectionsMeta,
        requestRejections.isAcceptableOrUnknown(
          data['request_rejections']!,
          _requestRejectionsMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('status_code')) {
      context.handle(
        _statusCodeMeta,
        statusCode.isAcceptableOrUnknown(data['status_code']!, _statusCodeMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('clock_skew_ms')) {
      context.handle(
        _clockSkewMsMeta,
        clockSkewMs.isAcceptableOrUnknown(
          data['clock_skew_ms']!,
          _clockSkewMsMeta,
        ),
      );
    }
    if (data.containsKey('app_version')) {
      context.handle(
        _appVersionMeta,
        appVersion.isAcceptableOrUnknown(data['app_version']!, _appVersionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      ),
      bootstrapCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bootstrap_cursor'],
      ),
      calendarTimezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_timezone'],
      ),
      calendarDayStartOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calendar_day_start_offset'],
      )!,
      calendarEffectiveAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_effective_at'],
      ),
      capabilities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities'],
      ),
      userPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_payload'],
      ),
      leaseOwner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lease_owner'],
      ),
      leaseUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lease_until'],
      ),
      nextSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_sync_at'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_at'],
      ),
      consecutiveFailures: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}consecutive_failures'],
      )!,
      backoffUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}backoff_until'],
      ),
      requestRejections: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}request_rejections'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      statusCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status_code'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      clockSkewMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}clock_skew_ms'],
      )!,
      appVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_version'],
      ),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final int id;
  final String userId;
  final String deviceId;
  final String? cursor;
  final String? bootstrapCursor;

  /// The server's calendar entry: the zone sent as captured_timezone (A5), never the device's.
  final String? calendarTimezone;
  final int calendarDayStartOffset;
  final String? calendarEffectiveAt;
  final String? capabilities;
  final String? userPayload;
  final String? leaseOwner;
  final int? leaseUntil;

  /// 429: no request before this instant (Retry-After). Nothing bypasses it.
  final int? nextSyncAt;
  final int? lastSyncedAt;

  /// 5xx, network and whole-request 4xx failures in a row, and the backoff they earned (F6).
  final int consecutiveFailures;
  final int? backoffUntil;

  /// Whole-request 403/404/422 on /sync in a row; at 3 the status becomes paused (F7).
  final int requestRejections;

  /// `active` or `paused`; [statusCode] is the server's error code while paused.
  final String status;
  final String? statusCode;

  /// The last failure of a run, as JSON `{code, message}` (F2). Cleared by a completed run.
  final String? lastError;

  /// Server time minus device time, from `meta.server_time` (F10).
  final int clockSkewMs;

  /// The app version that last synced this database; a change replays undecodable items (G5).
  final String? appVersion;
  const SyncStateRow({
    required this.id,
    required this.userId,
    required this.deviceId,
    this.cursor,
    this.bootstrapCursor,
    this.calendarTimezone,
    required this.calendarDayStartOffset,
    this.calendarEffectiveAt,
    this.capabilities,
    this.userPayload,
    this.leaseOwner,
    this.leaseUntil,
    this.nextSyncAt,
    this.lastSyncedAt,
    required this.consecutiveFailures,
    this.backoffUntil,
    required this.requestRejections,
    required this.status,
    this.statusCode,
    this.lastError,
    required this.clockSkewMs,
    this.appVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<String>(cursor);
    }
    if (!nullToAbsent || bootstrapCursor != null) {
      map['bootstrap_cursor'] = Variable<String>(bootstrapCursor);
    }
    if (!nullToAbsent || calendarTimezone != null) {
      map['calendar_timezone'] = Variable<String>(calendarTimezone);
    }
    map['calendar_day_start_offset'] = Variable<int>(calendarDayStartOffset);
    if (!nullToAbsent || calendarEffectiveAt != null) {
      map['calendar_effective_at'] = Variable<String>(calendarEffectiveAt);
    }
    if (!nullToAbsent || capabilities != null) {
      map['capabilities'] = Variable<String>(capabilities);
    }
    if (!nullToAbsent || userPayload != null) {
      map['user_payload'] = Variable<String>(userPayload);
    }
    if (!nullToAbsent || leaseOwner != null) {
      map['lease_owner'] = Variable<String>(leaseOwner);
    }
    if (!nullToAbsent || leaseUntil != null) {
      map['lease_until'] = Variable<int>(leaseUntil);
    }
    if (!nullToAbsent || nextSyncAt != null) {
      map['next_sync_at'] = Variable<int>(nextSyncAt);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt);
    }
    map['consecutive_failures'] = Variable<int>(consecutiveFailures);
    if (!nullToAbsent || backoffUntil != null) {
      map['backoff_until'] = Variable<int>(backoffUntil);
    }
    map['request_rejections'] = Variable<int>(requestRejections);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || statusCode != null) {
      map['status_code'] = Variable<String>(statusCode);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['clock_skew_ms'] = Variable<int>(clockSkewMs);
    if (!nullToAbsent || appVersion != null) {
      map['app_version'] = Variable<String>(appVersion);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      id: Value(id),
      userId: Value(userId),
      deviceId: Value(deviceId),
      cursor: cursor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursor),
      bootstrapCursor: bootstrapCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(bootstrapCursor),
      calendarTimezone: calendarTimezone == null && nullToAbsent
          ? const Value.absent()
          : Value(calendarTimezone),
      calendarDayStartOffset: Value(calendarDayStartOffset),
      calendarEffectiveAt: calendarEffectiveAt == null && nullToAbsent
          ? const Value.absent()
          : Value(calendarEffectiveAt),
      capabilities: capabilities == null && nullToAbsent
          ? const Value.absent()
          : Value(capabilities),
      userPayload: userPayload == null && nullToAbsent
          ? const Value.absent()
          : Value(userPayload),
      leaseOwner: leaseOwner == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseOwner),
      leaseUntil: leaseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseUntil),
      nextSyncAt: nextSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextSyncAt),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      consecutiveFailures: Value(consecutiveFailures),
      backoffUntil: backoffUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(backoffUntil),
      requestRejections: Value(requestRejections),
      status: Value(status),
      statusCode: statusCode == null && nullToAbsent
          ? const Value.absent()
          : Value(statusCode),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      clockSkewMs: Value(clockSkewMs),
      appVersion: appVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(appVersion),
    );
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      cursor: serializer.fromJson<String?>(json['cursor']),
      bootstrapCursor: serializer.fromJson<String?>(json['bootstrapCursor']),
      calendarTimezone: serializer.fromJson<String?>(json['calendarTimezone']),
      calendarDayStartOffset: serializer.fromJson<int>(
        json['calendarDayStartOffset'],
      ),
      calendarEffectiveAt: serializer.fromJson<String?>(
        json['calendarEffectiveAt'],
      ),
      capabilities: serializer.fromJson<String?>(json['capabilities']),
      userPayload: serializer.fromJson<String?>(json['userPayload']),
      leaseOwner: serializer.fromJson<String?>(json['leaseOwner']),
      leaseUntil: serializer.fromJson<int?>(json['leaseUntil']),
      nextSyncAt: serializer.fromJson<int?>(json['nextSyncAt']),
      lastSyncedAt: serializer.fromJson<int?>(json['lastSyncedAt']),
      consecutiveFailures: serializer.fromJson<int>(
        json['consecutiveFailures'],
      ),
      backoffUntil: serializer.fromJson<int?>(json['backoffUntil']),
      requestRejections: serializer.fromJson<int>(json['requestRejections']),
      status: serializer.fromJson<String>(json['status']),
      statusCode: serializer.fromJson<String?>(json['statusCode']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      clockSkewMs: serializer.fromJson<int>(json['clockSkewMs']),
      appVersion: serializer.fromJson<String?>(json['appVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'deviceId': serializer.toJson<String>(deviceId),
      'cursor': serializer.toJson<String?>(cursor),
      'bootstrapCursor': serializer.toJson<String?>(bootstrapCursor),
      'calendarTimezone': serializer.toJson<String?>(calendarTimezone),
      'calendarDayStartOffset': serializer.toJson<int>(calendarDayStartOffset),
      'calendarEffectiveAt': serializer.toJson<String?>(calendarEffectiveAt),
      'capabilities': serializer.toJson<String?>(capabilities),
      'userPayload': serializer.toJson<String?>(userPayload),
      'leaseOwner': serializer.toJson<String?>(leaseOwner),
      'leaseUntil': serializer.toJson<int?>(leaseUntil),
      'nextSyncAt': serializer.toJson<int?>(nextSyncAt),
      'lastSyncedAt': serializer.toJson<int?>(lastSyncedAt),
      'consecutiveFailures': serializer.toJson<int>(consecutiveFailures),
      'backoffUntil': serializer.toJson<int?>(backoffUntil),
      'requestRejections': serializer.toJson<int>(requestRejections),
      'status': serializer.toJson<String>(status),
      'statusCode': serializer.toJson<String?>(statusCode),
      'lastError': serializer.toJson<String?>(lastError),
      'clockSkewMs': serializer.toJson<int>(clockSkewMs),
      'appVersion': serializer.toJson<String?>(appVersion),
    };
  }

  SyncStateRow copyWith({
    int? id,
    String? userId,
    String? deviceId,
    Value<String?> cursor = const Value.absent(),
    Value<String?> bootstrapCursor = const Value.absent(),
    Value<String?> calendarTimezone = const Value.absent(),
    int? calendarDayStartOffset,
    Value<String?> calendarEffectiveAt = const Value.absent(),
    Value<String?> capabilities = const Value.absent(),
    Value<String?> userPayload = const Value.absent(),
    Value<String?> leaseOwner = const Value.absent(),
    Value<int?> leaseUntil = const Value.absent(),
    Value<int?> nextSyncAt = const Value.absent(),
    Value<int?> lastSyncedAt = const Value.absent(),
    int? consecutiveFailures,
    Value<int?> backoffUntil = const Value.absent(),
    int? requestRejections,
    String? status,
    Value<String?> statusCode = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    int? clockSkewMs,
    Value<String?> appVersion = const Value.absent(),
  }) => SyncStateRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    deviceId: deviceId ?? this.deviceId,
    cursor: cursor.present ? cursor.value : this.cursor,
    bootstrapCursor: bootstrapCursor.present
        ? bootstrapCursor.value
        : this.bootstrapCursor,
    calendarTimezone: calendarTimezone.present
        ? calendarTimezone.value
        : this.calendarTimezone,
    calendarDayStartOffset:
        calendarDayStartOffset ?? this.calendarDayStartOffset,
    calendarEffectiveAt: calendarEffectiveAt.present
        ? calendarEffectiveAt.value
        : this.calendarEffectiveAt,
    capabilities: capabilities.present ? capabilities.value : this.capabilities,
    userPayload: userPayload.present ? userPayload.value : this.userPayload,
    leaseOwner: leaseOwner.present ? leaseOwner.value : this.leaseOwner,
    leaseUntil: leaseUntil.present ? leaseUntil.value : this.leaseUntil,
    nextSyncAt: nextSyncAt.present ? nextSyncAt.value : this.nextSyncAt,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    backoffUntil: backoffUntil.present ? backoffUntil.value : this.backoffUntil,
    requestRejections: requestRejections ?? this.requestRejections,
    status: status ?? this.status,
    statusCode: statusCode.present ? statusCode.value : this.statusCode,
    lastError: lastError.present ? lastError.value : this.lastError,
    clockSkewMs: clockSkewMs ?? this.clockSkewMs,
    appVersion: appVersion.present ? appVersion.value : this.appVersion,
  );
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      bootstrapCursor: data.bootstrapCursor.present
          ? data.bootstrapCursor.value
          : this.bootstrapCursor,
      calendarTimezone: data.calendarTimezone.present
          ? data.calendarTimezone.value
          : this.calendarTimezone,
      calendarDayStartOffset: data.calendarDayStartOffset.present
          ? data.calendarDayStartOffset.value
          : this.calendarDayStartOffset,
      calendarEffectiveAt: data.calendarEffectiveAt.present
          ? data.calendarEffectiveAt.value
          : this.calendarEffectiveAt,
      capabilities: data.capabilities.present
          ? data.capabilities.value
          : this.capabilities,
      userPayload: data.userPayload.present
          ? data.userPayload.value
          : this.userPayload,
      leaseOwner: data.leaseOwner.present
          ? data.leaseOwner.value
          : this.leaseOwner,
      leaseUntil: data.leaseUntil.present
          ? data.leaseUntil.value
          : this.leaseUntil,
      nextSyncAt: data.nextSyncAt.present
          ? data.nextSyncAt.value
          : this.nextSyncAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      consecutiveFailures: data.consecutiveFailures.present
          ? data.consecutiveFailures.value
          : this.consecutiveFailures,
      backoffUntil: data.backoffUntil.present
          ? data.backoffUntil.value
          : this.backoffUntil,
      requestRejections: data.requestRejections.present
          ? data.requestRejections.value
          : this.requestRejections,
      status: data.status.present ? data.status.value : this.status,
      statusCode: data.statusCode.present
          ? data.statusCode.value
          : this.statusCode,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      clockSkewMs: data.clockSkewMs.present
          ? data.clockSkewMs.value
          : this.clockSkewMs,
      appVersion: data.appVersion.present
          ? data.appVersion.value
          : this.appVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('cursor: $cursor, ')
          ..write('bootstrapCursor: $bootstrapCursor, ')
          ..write('calendarTimezone: $calendarTimezone, ')
          ..write('calendarDayStartOffset: $calendarDayStartOffset, ')
          ..write('calendarEffectiveAt: $calendarEffectiveAt, ')
          ..write('capabilities: $capabilities, ')
          ..write('userPayload: $userPayload, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('nextSyncAt: $nextSyncAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('consecutiveFailures: $consecutiveFailures, ')
          ..write('backoffUntil: $backoffUntil, ')
          ..write('requestRejections: $requestRejections, ')
          ..write('status: $status, ')
          ..write('statusCode: $statusCode, ')
          ..write('lastError: $lastError, ')
          ..write('clockSkewMs: $clockSkewMs, ')
          ..write('appVersion: $appVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    userId,
    deviceId,
    cursor,
    bootstrapCursor,
    calendarTimezone,
    calendarDayStartOffset,
    calendarEffectiveAt,
    capabilities,
    userPayload,
    leaseOwner,
    leaseUntil,
    nextSyncAt,
    lastSyncedAt,
    consecutiveFailures,
    backoffUntil,
    requestRejections,
    status,
    statusCode,
    lastError,
    clockSkewMs,
    appVersion,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.deviceId == this.deviceId &&
          other.cursor == this.cursor &&
          other.bootstrapCursor == this.bootstrapCursor &&
          other.calendarTimezone == this.calendarTimezone &&
          other.calendarDayStartOffset == this.calendarDayStartOffset &&
          other.calendarEffectiveAt == this.calendarEffectiveAt &&
          other.capabilities == this.capabilities &&
          other.userPayload == this.userPayload &&
          other.leaseOwner == this.leaseOwner &&
          other.leaseUntil == this.leaseUntil &&
          other.nextSyncAt == this.nextSyncAt &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.consecutiveFailures == this.consecutiveFailures &&
          other.backoffUntil == this.backoffUntil &&
          other.requestRejections == this.requestRejections &&
          other.status == this.status &&
          other.statusCode == this.statusCode &&
          other.lastError == this.lastError &&
          other.clockSkewMs == this.clockSkewMs &&
          other.appVersion == this.appVersion);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> deviceId;
  final Value<String?> cursor;
  final Value<String?> bootstrapCursor;
  final Value<String?> calendarTimezone;
  final Value<int> calendarDayStartOffset;
  final Value<String?> calendarEffectiveAt;
  final Value<String?> capabilities;
  final Value<String?> userPayload;
  final Value<String?> leaseOwner;
  final Value<int?> leaseUntil;
  final Value<int?> nextSyncAt;
  final Value<int?> lastSyncedAt;
  final Value<int> consecutiveFailures;
  final Value<int?> backoffUntil;
  final Value<int> requestRejections;
  final Value<String> status;
  final Value<String?> statusCode;
  final Value<String?> lastError;
  final Value<int> clockSkewMs;
  final Value<String?> appVersion;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.cursor = const Value.absent(),
    this.bootstrapCursor = const Value.absent(),
    this.calendarTimezone = const Value.absent(),
    this.calendarDayStartOffset = const Value.absent(),
    this.calendarEffectiveAt = const Value.absent(),
    this.capabilities = const Value.absent(),
    this.userPayload = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.nextSyncAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.consecutiveFailures = const Value.absent(),
    this.backoffUntil = const Value.absent(),
    this.requestRejections = const Value.absent(),
    this.status = const Value.absent(),
    this.statusCode = const Value.absent(),
    this.lastError = const Value.absent(),
    this.clockSkewMs = const Value.absent(),
    this.appVersion = const Value.absent(),
  });
  SyncStateCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required String deviceId,
    this.cursor = const Value.absent(),
    this.bootstrapCursor = const Value.absent(),
    this.calendarTimezone = const Value.absent(),
    this.calendarDayStartOffset = const Value.absent(),
    this.calendarEffectiveAt = const Value.absent(),
    this.capabilities = const Value.absent(),
    this.userPayload = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.nextSyncAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.consecutiveFailures = const Value.absent(),
    this.backoffUntil = const Value.absent(),
    this.requestRejections = const Value.absent(),
    this.status = const Value.absent(),
    this.statusCode = const Value.absent(),
    this.lastError = const Value.absent(),
    this.clockSkewMs = const Value.absent(),
    this.appVersion = const Value.absent(),
  }) : userId = Value(userId),
       deviceId = Value(deviceId);
  static Insertable<SyncStateRow> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? deviceId,
    Expression<String>? cursor,
    Expression<String>? bootstrapCursor,
    Expression<String>? calendarTimezone,
    Expression<int>? calendarDayStartOffset,
    Expression<String>? calendarEffectiveAt,
    Expression<String>? capabilities,
    Expression<String>? userPayload,
    Expression<String>? leaseOwner,
    Expression<int>? leaseUntil,
    Expression<int>? nextSyncAt,
    Expression<int>? lastSyncedAt,
    Expression<int>? consecutiveFailures,
    Expression<int>? backoffUntil,
    Expression<int>? requestRejections,
    Expression<String>? status,
    Expression<String>? statusCode,
    Expression<String>? lastError,
    Expression<int>? clockSkewMs,
    Expression<String>? appVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      if (cursor != null) 'cursor': cursor,
      if (bootstrapCursor != null) 'bootstrap_cursor': bootstrapCursor,
      if (calendarTimezone != null) 'calendar_timezone': calendarTimezone,
      if (calendarDayStartOffset != null)
        'calendar_day_start_offset': calendarDayStartOffset,
      if (calendarEffectiveAt != null)
        'calendar_effective_at': calendarEffectiveAt,
      if (capabilities != null) 'capabilities': capabilities,
      if (userPayload != null) 'user_payload': userPayload,
      if (leaseOwner != null) 'lease_owner': leaseOwner,
      if (leaseUntil != null) 'lease_until': leaseUntil,
      if (nextSyncAt != null) 'next_sync_at': nextSyncAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (consecutiveFailures != null)
        'consecutive_failures': consecutiveFailures,
      if (backoffUntil != null) 'backoff_until': backoffUntil,
      if (requestRejections != null) 'request_rejections': requestRejections,
      if (status != null) 'status': status,
      if (statusCode != null) 'status_code': statusCode,
      if (lastError != null) 'last_error': lastError,
      if (clockSkewMs != null) 'clock_skew_ms': clockSkewMs,
      if (appVersion != null) 'app_version': appVersion,
    });
  }

  SyncStateCompanion copyWith({
    Value<int>? id,
    Value<String>? userId,
    Value<String>? deviceId,
    Value<String?>? cursor,
    Value<String?>? bootstrapCursor,
    Value<String?>? calendarTimezone,
    Value<int>? calendarDayStartOffset,
    Value<String?>? calendarEffectiveAt,
    Value<String?>? capabilities,
    Value<String?>? userPayload,
    Value<String?>? leaseOwner,
    Value<int?>? leaseUntil,
    Value<int?>? nextSyncAt,
    Value<int?>? lastSyncedAt,
    Value<int>? consecutiveFailures,
    Value<int?>? backoffUntil,
    Value<int>? requestRejections,
    Value<String>? status,
    Value<String?>? statusCode,
    Value<String?>? lastError,
    Value<int>? clockSkewMs,
    Value<String?>? appVersion,
  }) {
    return SyncStateCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      cursor: cursor ?? this.cursor,
      bootstrapCursor: bootstrapCursor ?? this.bootstrapCursor,
      calendarTimezone: calendarTimezone ?? this.calendarTimezone,
      calendarDayStartOffset:
          calendarDayStartOffset ?? this.calendarDayStartOffset,
      calendarEffectiveAt: calendarEffectiveAt ?? this.calendarEffectiveAt,
      capabilities: capabilities ?? this.capabilities,
      userPayload: userPayload ?? this.userPayload,
      leaseOwner: leaseOwner ?? this.leaseOwner,
      leaseUntil: leaseUntil ?? this.leaseUntil,
      nextSyncAt: nextSyncAt ?? this.nextSyncAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      backoffUntil: backoffUntil ?? this.backoffUntil,
      requestRejections: requestRejections ?? this.requestRejections,
      status: status ?? this.status,
      statusCode: statusCode ?? this.statusCode,
      lastError: lastError ?? this.lastError,
      clockSkewMs: clockSkewMs ?? this.clockSkewMs,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (bootstrapCursor.present) {
      map['bootstrap_cursor'] = Variable<String>(bootstrapCursor.value);
    }
    if (calendarTimezone.present) {
      map['calendar_timezone'] = Variable<String>(calendarTimezone.value);
    }
    if (calendarDayStartOffset.present) {
      map['calendar_day_start_offset'] = Variable<int>(
        calendarDayStartOffset.value,
      );
    }
    if (calendarEffectiveAt.present) {
      map['calendar_effective_at'] = Variable<String>(
        calendarEffectiveAt.value,
      );
    }
    if (capabilities.present) {
      map['capabilities'] = Variable<String>(capabilities.value);
    }
    if (userPayload.present) {
      map['user_payload'] = Variable<String>(userPayload.value);
    }
    if (leaseOwner.present) {
      map['lease_owner'] = Variable<String>(leaseOwner.value);
    }
    if (leaseUntil.present) {
      map['lease_until'] = Variable<int>(leaseUntil.value);
    }
    if (nextSyncAt.present) {
      map['next_sync_at'] = Variable<int>(nextSyncAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt.value);
    }
    if (consecutiveFailures.present) {
      map['consecutive_failures'] = Variable<int>(consecutiveFailures.value);
    }
    if (backoffUntil.present) {
      map['backoff_until'] = Variable<int>(backoffUntil.value);
    }
    if (requestRejections.present) {
      map['request_rejections'] = Variable<int>(requestRejections.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (statusCode.present) {
      map['status_code'] = Variable<String>(statusCode.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (clockSkewMs.present) {
      map['clock_skew_ms'] = Variable<int>(clockSkewMs.value);
    }
    if (appVersion.present) {
      map['app_version'] = Variable<String>(appVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('cursor: $cursor, ')
          ..write('bootstrapCursor: $bootstrapCursor, ')
          ..write('calendarTimezone: $calendarTimezone, ')
          ..write('calendarDayStartOffset: $calendarDayStartOffset, ')
          ..write('calendarEffectiveAt: $calendarEffectiveAt, ')
          ..write('capabilities: $capabilities, ')
          ..write('userPayload: $userPayload, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('nextSyncAt: $nextSyncAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('consecutiveFailures: $consecutiveFailures, ')
          ..write('backoffUntil: $backoffUntil, ')
          ..write('requestRejections: $requestRejections, ')
          ..write('status: $status, ')
          ..write('statusCode: $statusCode, ')
          ..write('lastError: $lastError, ')
          ..write('clockSkewMs: $clockSkewMs, ')
          ..write('appVersion: $appVersion')
          ..write(')'))
        .toString();
  }
}

class $DiscardedMutationsTable extends DiscardedMutations
    with TableInfo<$DiscardedMutationsTable, DiscardedMutation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiscardedMutationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDateHintMeta = const VerificationMeta(
    'localDateHint',
  );
  @override
  late final GeneratedColumn<String> localDateHint = GeneratedColumn<String>(
    'local_date_hint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discardedAtMeta = const VerificationMeta(
    'discardedAt',
  );
  @override
  late final GeneratedColumn<int> discardedAt = GeneratedColumn<int>(
    'discarded_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mutationId,
    entity,
    entityId,
    operation,
    payload,
    localDateHint,
    lastError,
    discardedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'discarded_mutations';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiscardedMutation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('local_date_hint')) {
      context.handle(
        _localDateHintMeta,
        localDateHint.isAcceptableOrUnknown(
          data['local_date_hint']!,
          _localDateHintMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('discarded_at')) {
      context.handle(
        _discardedAtMeta,
        discardedAt.isAcceptableOrUnknown(
          data['discarded_at']!,
          _discardedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_discardedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mutationId};
  @override
  DiscardedMutation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiscardedMutation(
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      localDateHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date_hint'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      discardedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discarded_at'],
      )!,
    );
  }

  @override
  $DiscardedMutationsTable createAlias(String alias) {
    return $DiscardedMutationsTable(attachedDatabase, alias);
  }
}

class DiscardedMutation extends DataClass
    implements Insertable<DiscardedMutation> {
  final String mutationId;
  final String entity;
  final String entityId;
  final String operation;
  final String payload;
  final String? localDateHint;
  final String? lastError;
  final int discardedAt;
  const DiscardedMutation({
    required this.mutationId,
    required this.entity,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.localDateHint,
    this.lastError,
    required this.discardedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mutation_id'] = Variable<String>(mutationId);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || localDateHint != null) {
      map['local_date_hint'] = Variable<String>(localDateHint);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['discarded_at'] = Variable<int>(discardedAt);
    return map;
  }

  DiscardedMutationsCompanion toCompanion(bool nullToAbsent) {
    return DiscardedMutationsCompanion(
      mutationId: Value(mutationId),
      entity: Value(entity),
      entityId: Value(entityId),
      operation: Value(operation),
      payload: Value(payload),
      localDateHint: localDateHint == null && nullToAbsent
          ? const Value.absent()
          : Value(localDateHint),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      discardedAt: Value(discardedAt),
    );
  }

  factory DiscardedMutation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiscardedMutation(
      mutationId: serializer.fromJson<String>(json['mutationId']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
      localDateHint: serializer.fromJson<String?>(json['localDateHint']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      discardedAt: serializer.fromJson<int>(json['discardedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mutationId': serializer.toJson<String>(mutationId),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
      'localDateHint': serializer.toJson<String?>(localDateHint),
      'lastError': serializer.toJson<String?>(lastError),
      'discardedAt': serializer.toJson<int>(discardedAt),
    };
  }

  DiscardedMutation copyWith({
    String? mutationId,
    String? entity,
    String? entityId,
    String? operation,
    String? payload,
    Value<String?> localDateHint = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    int? discardedAt,
  }) => DiscardedMutation(
    mutationId: mutationId ?? this.mutationId,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    payload: payload ?? this.payload,
    localDateHint: localDateHint.present
        ? localDateHint.value
        : this.localDateHint,
    lastError: lastError.present ? lastError.value : this.lastError,
    discardedAt: discardedAt ?? this.discardedAt,
  );
  DiscardedMutation copyWithCompanion(DiscardedMutationsCompanion data) {
    return DiscardedMutation(
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      localDateHint: data.localDateHint.present
          ? data.localDateHint.value
          : this.localDateHint,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      discardedAt: data.discardedAt.present
          ? data.discardedAt.value
          : this.discardedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiscardedMutation(')
          ..write('mutationId: $mutationId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('localDateHint: $localDateHint, ')
          ..write('lastError: $lastError, ')
          ..write('discardedAt: $discardedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mutationId,
    entity,
    entityId,
    operation,
    payload,
    localDateHint,
    lastError,
    discardedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiscardedMutation &&
          other.mutationId == this.mutationId &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.localDateHint == this.localDateHint &&
          other.lastError == this.lastError &&
          other.discardedAt == this.discardedAt);
}

class DiscardedMutationsCompanion extends UpdateCompanion<DiscardedMutation> {
  final Value<String> mutationId;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String> payload;
  final Value<String?> localDateHint;
  final Value<String?> lastError;
  final Value<int> discardedAt;
  final Value<int> rowid;
  const DiscardedMutationsCompanion({
    this.mutationId = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.localDateHint = const Value.absent(),
    this.lastError = const Value.absent(),
    this.discardedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiscardedMutationsCompanion.insert({
    required String mutationId,
    required String entity,
    required String entityId,
    required String operation,
    required String payload,
    this.localDateHint = const Value.absent(),
    this.lastError = const Value.absent(),
    required int discardedAt,
    this.rowid = const Value.absent(),
  }) : mutationId = Value(mutationId),
       entity = Value(entity),
       entityId = Value(entityId),
       operation = Value(operation),
       payload = Value(payload),
       discardedAt = Value(discardedAt);
  static Insertable<DiscardedMutation> custom({
    Expression<String>? mutationId,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<String>? localDateHint,
    Expression<String>? lastError,
    Expression<int>? discardedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mutationId != null) 'mutation_id': mutationId,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (localDateHint != null) 'local_date_hint': localDateHint,
      if (lastError != null) 'last_error': lastError,
      if (discardedAt != null) 'discarded_at': discardedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiscardedMutationsCompanion copyWith({
    Value<String>? mutationId,
    Value<String>? entity,
    Value<String>? entityId,
    Value<String>? operation,
    Value<String>? payload,
    Value<String?>? localDateHint,
    Value<String?>? lastError,
    Value<int>? discardedAt,
    Value<int>? rowid,
  }) {
    return DiscardedMutationsCompanion(
      mutationId: mutationId ?? this.mutationId,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      localDateHint: localDateHint ?? this.localDateHint,
      lastError: lastError ?? this.lastError,
      discardedAt: discardedAt ?? this.discardedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (localDateHint.present) {
      map['local_date_hint'] = Variable<String>(localDateHint.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (discardedAt.present) {
      map['discarded_at'] = Variable<int>(discardedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiscardedMutationsCompanion(')
          ..write('mutationId: $mutationId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('localDateHint: $localDateHint, ')
          ..write('lastError: $lastError, ')
          ..write('discardedAt: $discardedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $HabitsTable habits = $HabitsTable(this);
  late final $HabitLogsTable habitLogs = $HabitLogsTable(this);
  late final $OpaqueEntitiesTable opaqueEntities = $OpaqueEntitiesTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $DiscardedMutationsTable discardedMutations =
      $DiscardedMutationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    habits,
    habitLogs,
    opaqueEntities,
    outbox,
    syncState,
    discardedMutations,
  ];
}

typedef $$HabitsTableCreateCompanionBuilder = HabitsCompanion Function({
  required String id,
  Value<String?> name,
  Value<String?> type,
  Value<String?> unit,
  Value<String?> category,
  Value<String?> targetValue,
  Value<String?> frequencyType,
  Value<String?> frequencyConfig,
  Value<String?> startLocalDate,
  Value<String?> archivedAt,
  required int version,
  Value<int?> definitionVersion,
  Value<String?> definitions,
  Value<String?> activeRanges,
  Value<String> extra,
  Value<int> rowid,
});
typedef $$HabitsTableUpdateCompanionBuilder = HabitsCompanion Function({
  Value<String> id,
  Value<String?> name,
  Value<String?> type,
  Value<String?> unit,
  Value<String?> category,
  Value<String?> targetValue,
  Value<String?> frequencyType,
  Value<String?> frequencyConfig,
  Value<String?> startLocalDate,
  Value<String?> archivedAt,
  Value<int> version,
  Value<int?> definitionVersion,
  Value<String?> definitions,
  Value<String?> activeRanges,
  Value<String> extra,
  Value<int> rowid,
});

class $$HabitsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequencyType => $composableBuilder(
    column: $table.frequencyType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequencyConfig => $composableBuilder(
    column: $table.frequencyConfig,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startLocalDate => $composableBuilder(
    column: $table.startLocalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get definitionVersion => $composableBuilder(
    column: $table.definitionVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitions => $composableBuilder(
    column: $table.definitions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeRanges => $composableBuilder(
    column: $table.activeRanges,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequencyType => $composableBuilder(
    column: $table.frequencyType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequencyConfig => $composableBuilder(
    column: $table.frequencyConfig,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startLocalDate => $composableBuilder(
    column: $table.startLocalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get definitionVersion => $composableBuilder(
    column: $table.definitionVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitions => $composableBuilder(
    column: $table.definitions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeRanges => $composableBuilder(
    column: $table.activeRanges,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frequencyType => $composableBuilder(
    column: $table.frequencyType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frequencyConfig => $composableBuilder(
    column: $table.frequencyConfig,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startLocalDate => $composableBuilder(
    column: $table.startLocalDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get definitionVersion => $composableBuilder(
    column: $table.definitionVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get definitions => $composableBuilder(
    column: $table.definitions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeRanges => $composableBuilder(
    column: $table.activeRanges,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extra =>
      $composableBuilder(column: $table.extra, builder: (column) => column);
}

class $$HabitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitsTable,
          ConfirmedHabit,
          $$HabitsTableFilterComposer,
          $$HabitsTableOrderingComposer,
          $$HabitsTableAnnotationComposer,
          $$HabitsTableCreateCompanionBuilder,
          $$HabitsTableUpdateCompanionBuilder,
          (
            ConfirmedHabit,
            BaseReferences<_$AppDatabase, $HabitsTable, ConfirmedHabit>,
          ),
          ConfirmedHabit,
          PrefetchHooks Function()
        > {
  $$HabitsTableTableManager(_$AppDatabase db, $HabitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> targetValue = const Value.absent(),
                Value<String?> frequencyType = const Value.absent(),
                Value<String?> frequencyConfig = const Value.absent(),
                Value<String?> startLocalDate = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> definitionVersion = const Value.absent(),
                Value<String?> definitions = const Value.absent(),
                Value<String?> activeRanges = const Value.absent(),
                Value<String> extra = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion(
                id: id,
                name: name,
                type: type,
                unit: unit,
                category: category,
                targetValue: targetValue,
                frequencyType: frequencyType,
                frequencyConfig: frequencyConfig,
                startLocalDate: startLocalDate,
                archivedAt: archivedAt,
                version: version,
                definitionVersion: definitionVersion,
                definitions: definitions,
                activeRanges: activeRanges,
                extra: extra,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> name = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> targetValue = const Value.absent(),
                Value<String?> frequencyType = const Value.absent(),
                Value<String?> frequencyConfig = const Value.absent(),
                Value<String?> startLocalDate = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                required int version,
                Value<int?> definitionVersion = const Value.absent(),
                Value<String?> definitions = const Value.absent(),
                Value<String?> activeRanges = const Value.absent(),
                Value<String> extra = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion.insert(
                id: id,
                name: name,
                type: type,
                unit: unit,
                category: category,
                targetValue: targetValue,
                frequencyType: frequencyType,
                frequencyConfig: frequencyConfig,
                startLocalDate: startLocalDate,
                archivedAt: archivedAt,
                version: version,
                definitionVersion: definitionVersion,
                definitions: definitions,
                activeRanges: activeRanges,
                extra: extra,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitsTable, ConfirmedHabit>(table),
                  BaseReferences<_$AppDatabase, $HabitsTable, ConfirmedHabit>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitsTable,
      ConfirmedHabit,
      $$HabitsTableFilterComposer,
      $$HabitsTableOrderingComposer,
      $$HabitsTableAnnotationComposer,
      $$HabitsTableCreateCompanionBuilder,
      $$HabitsTableUpdateCompanionBuilder,
      (
        ConfirmedHabit,
        BaseReferences<_$AppDatabase, $HabitsTable, ConfirmedHabit>,
      ),
      ConfirmedHabit,
      PrefetchHooks Function()
    >;
typedef $$HabitLogsTableCreateCompanionBuilder = HabitLogsCompanion Function({
  required String id,
  Value<String?> habitId,
  Value<String?> logDate,
  Value<String?> value,
  Value<String?> detail,
  Value<String?> occurredAt,
  Value<String?> completedAt,
  Value<String?> resolvedTimezone,
  Value<int?> dayStartOffsetMinutes,
  Value<int?> definitionVersion,
  required int version,
  Value<String?> deletedAt,
  Value<String> extra,
  Value<int> rowid,
});
typedef $$HabitLogsTableUpdateCompanionBuilder = HabitLogsCompanion Function({
  Value<String> id,
  Value<String?> habitId,
  Value<String?> logDate,
  Value<String?> value,
  Value<String?> detail,
  Value<String?> occurredAt,
  Value<String?> completedAt,
  Value<String?> resolvedTimezone,
  Value<int?> dayStartOffsetMinutes,
  Value<int?> definitionVersion,
  Value<int> version,
  Value<String?> deletedAt,
  Value<String> extra,
  Value<int> rowid,
});

class $$HabitLogsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logDate => $composableBuilder(
    column: $table.logDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolvedTimezone => $composableBuilder(
    column: $table.resolvedTimezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayStartOffsetMinutes => $composableBuilder(
    column: $table.dayStartOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get definitionVersion => $composableBuilder(
    column: $table.definitionVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logDate => $composableBuilder(
    column: $table.logDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolvedTimezone => $composableBuilder(
    column: $table.resolvedTimezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayStartOffsetMinutes => $composableBuilder(
    column: $table.dayStartOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get definitionVersion => $composableBuilder(
    column: $table.definitionVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<String> get logDate =>
      $composableBuilder(column: $table.logDate, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolvedTimezone => $composableBuilder(
    column: $table.resolvedTimezone,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayStartOffsetMinutes => $composableBuilder(
    column: $table.dayStartOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get definitionVersion => $composableBuilder(
    column: $table.definitionVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get extra =>
      $composableBuilder(column: $table.extra, builder: (column) => column);
}

class $$HabitLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitLogsTable,
          ConfirmedLog,
          $$HabitLogsTableFilterComposer,
          $$HabitLogsTableOrderingComposer,
          $$HabitLogsTableAnnotationComposer,
          $$HabitLogsTableCreateCompanionBuilder,
          $$HabitLogsTableUpdateCompanionBuilder,
          (
            ConfirmedLog,
            BaseReferences<_$AppDatabase, $HabitLogsTable, ConfirmedLog>,
          ),
          ConfirmedLog,
          PrefetchHooks Function()
        > {
  $$HabitLogsTableTableManager(_$AppDatabase db, $HabitLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> habitId = const Value.absent(),
                Value<String?> logDate = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<String?> occurredAt = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<String?> resolvedTimezone = const Value.absent(),
                Value<int?> dayStartOffsetMinutes = const Value.absent(),
                Value<int?> definitionVersion = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String> extra = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitLogsCompanion(
                id: id,
                habitId: habitId,
                logDate: logDate,
                value: value,
                detail: detail,
                occurredAt: occurredAt,
                completedAt: completedAt,
                resolvedTimezone: resolvedTimezone,
                dayStartOffsetMinutes: dayStartOffsetMinutes,
                definitionVersion: definitionVersion,
                version: version,
                deletedAt: deletedAt,
                extra: extra,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> habitId = const Value.absent(),
                Value<String?> logDate = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<String?> occurredAt = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<String?> resolvedTimezone = const Value.absent(),
                Value<int?> dayStartOffsetMinutes = const Value.absent(),
                Value<int?> definitionVersion = const Value.absent(),
                required int version,
                Value<String?> deletedAt = const Value.absent(),
                Value<String> extra = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitLogsCompanion.insert(
                id: id,
                habitId: habitId,
                logDate: logDate,
                value: value,
                detail: detail,
                occurredAt: occurredAt,
                completedAt: completedAt,
                resolvedTimezone: resolvedTimezone,
                dayStartOffsetMinutes: dayStartOffsetMinutes,
                definitionVersion: definitionVersion,
                version: version,
                deletedAt: deletedAt,
                extra: extra,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitLogsTable, ConfirmedLog>(table),
                  BaseReferences<_$AppDatabase, $HabitLogsTable, ConfirmedLog>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitLogsTable,
      ConfirmedLog,
      $$HabitLogsTableFilterComposer,
      $$HabitLogsTableOrderingComposer,
      $$HabitLogsTableAnnotationComposer,
      $$HabitLogsTableCreateCompanionBuilder,
      $$HabitLogsTableUpdateCompanionBuilder,
      (
        ConfirmedLog,
        BaseReferences<_$AppDatabase, $HabitLogsTable, ConfirmedLog>,
      ),
      ConfirmedLog,
      PrefetchHooks Function()
    >;
typedef $$OpaqueEntitiesTableCreateCompanionBuilder =
    OpaqueEntitiesCompanion Function({
      required String entityType,
      required String entityId,
      required int version,
      required String operation,
      required String payload,
      Value<int> rowid,
    });
typedef $$OpaqueEntitiesTableUpdateCompanionBuilder =
    OpaqueEntitiesCompanion Function({
      Value<String> entityType,
      Value<String> entityId,
      Value<int> version,
      Value<String> operation,
      Value<String> payload,
      Value<int> rowid,
    });

class $$OpaqueEntitiesTableFilterComposer
    extends Composer<_$AppDatabase, $OpaqueEntitiesTable> {
  $$OpaqueEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OpaqueEntitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $OpaqueEntitiesTable> {
  $$OpaqueEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OpaqueEntitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OpaqueEntitiesTable> {
  $$OpaqueEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$OpaqueEntitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OpaqueEntitiesTable,
          OpaqueEntity,
          $$OpaqueEntitiesTableFilterComposer,
          $$OpaqueEntitiesTableOrderingComposer,
          $$OpaqueEntitiesTableAnnotationComposer,
          $$OpaqueEntitiesTableCreateCompanionBuilder,
          $$OpaqueEntitiesTableUpdateCompanionBuilder,
          (
            OpaqueEntity,
            BaseReferences<_$AppDatabase, $OpaqueEntitiesTable, OpaqueEntity>,
          ),
          OpaqueEntity,
          PrefetchHooks Function()
        > {
  $$OpaqueEntitiesTableTableManager(
    _$AppDatabase db,
    $OpaqueEntitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OpaqueEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OpaqueEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OpaqueEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OpaqueEntitiesCompanion(
                entityType: entityType,
                entityId: entityId,
                version: version,
                operation: operation,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entityType,
                required String entityId,
                required int version,
                required String operation,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => OpaqueEntitiesCompanion.insert(
                entityType: entityType,
                entityId: entityId,
                version: version,
                operation: operation,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OpaqueEntitiesTable, OpaqueEntity>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OpaqueEntitiesTable,
                    OpaqueEntity
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OpaqueEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OpaqueEntitiesTable,
      OpaqueEntity,
      $$OpaqueEntitiesTableFilterComposer,
      $$OpaqueEntitiesTableOrderingComposer,
      $$OpaqueEntitiesTableAnnotationComposer,
      $$OpaqueEntitiesTableCreateCompanionBuilder,
      $$OpaqueEntitiesTableUpdateCompanionBuilder,
      (
        OpaqueEntity,
        BaseReferences<_$AppDatabase, $OpaqueEntitiesTable, OpaqueEntity>,
      ),
      OpaqueEntity,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  required String mutationId,
  required String entity,
  required String entityId,
  required String operation,
  Value<int?> baseVersion,
  required String occurredAt,
  Value<String?> capturedTimezone,
  Value<String?> localDateHint,
  required String payload,
  Value<String?> habitId,
  required String state,
  Value<int> attempts,
  Value<int?> nextAttemptAt,
  Value<int?> firstFailedAt,
  Value<bool> surfaced,
  Value<String?> lastError,
  Value<int?> ackVersion,
  required int createdAt,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  Value<String> mutationId,
  Value<String> entity,
  Value<String> entityId,
  Value<String> operation,
  Value<int?> baseVersion,
  Value<String> occurredAt,
  Value<String?> capturedTimezone,
  Value<String?> localDateHint,
  Value<String> payload,
  Value<String?> habitId,
  Value<String> state,
  Value<int> attempts,
  Value<int?> nextAttemptAt,
  Value<int?> firstFailedAt,
  Value<bool> surfaced,
  Value<String?> lastError,
  Value<int?> ackVersion,
  Value<int> createdAt,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capturedTimezone => $composableBuilder(
    column: $table.capturedTimezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDateHint => $composableBuilder(
    column: $table.localDateHint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstFailedAt => $composableBuilder(
    column: $table.firstFailedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get surfaced => $composableBuilder(
    column: $table.surfaced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ackVersion => $composableBuilder(
    column: $table.ackVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capturedTimezone => $composableBuilder(
    column: $table.capturedTimezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDateHint => $composableBuilder(
    column: $table.localDateHint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstFailedAt => $composableBuilder(
    column: $table.firstFailedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get surfaced => $composableBuilder(
    column: $table.surfaced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ackVersion => $composableBuilder(
    column: $table.ackVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capturedTimezone => $composableBuilder(
    column: $table.capturedTimezone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localDateHint => $composableBuilder(
    column: $table.localDateHint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get firstFailedAt => $composableBuilder(
    column: $table.firstFailedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get surfaced =>
      $composableBuilder(column: $table.surfaced, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get ackVersion => $composableBuilder(
    column: $table.ackVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> occurredAt = const Value.absent(),
                Value<String?> capturedTimezone = const Value.absent(),
                Value<String?> localDateHint = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String?> habitId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int?> nextAttemptAt = const Value.absent(),
                Value<int?> firstFailedAt = const Value.absent(),
                Value<bool> surfaced = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int?> ackVersion = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => OutboxCompanion(
                seq: seq,
                mutationId: mutationId,
                entity: entity,
                entityId: entityId,
                operation: operation,
                baseVersion: baseVersion,
                occurredAt: occurredAt,
                capturedTimezone: capturedTimezone,
                localDateHint: localDateHint,
                payload: payload,
                habitId: habitId,
                state: state,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                firstFailedAt: firstFailedAt,
                surfaced: surfaced,
                lastError: lastError,
                ackVersion: ackVersion,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String mutationId,
                required String entity,
                required String entityId,
                required String operation,
                Value<int?> baseVersion = const Value.absent(),
                required String occurredAt,
                Value<String?> capturedTimezone = const Value.absent(),
                Value<String?> localDateHint = const Value.absent(),
                required String payload,
                Value<String?> habitId = const Value.absent(),
                required String state,
                Value<int> attempts = const Value.absent(),
                Value<int?> nextAttemptAt = const Value.absent(),
                Value<int?> firstFailedAt = const Value.absent(),
                Value<bool> surfaced = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int?> ackVersion = const Value.absent(),
                required int createdAt,
              }) => OutboxCompanion.insert(
                seq: seq,
                mutationId: mutationId,
                entity: entity,
                entityId: entityId,
                operation: operation,
                baseVersion: baseVersion,
                occurredAt: occurredAt,
                capturedTimezone: capturedTimezone,
                localDateHint: localDateHint,
                payload: payload,
                habitId: habitId,
                state: state,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                firstFailedAt: firstFailedAt,
                surfaced: surfaced,
                lastError: lastError,
                ackVersion: ackVersion,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxRow>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  Value<int> id,
  required String userId,
  required String deviceId,
  Value<String?> cursor,
  Value<String?> bootstrapCursor,
  Value<String?> calendarTimezone,
  Value<int> calendarDayStartOffset,
  Value<String?> calendarEffectiveAt,
  Value<String?> capabilities,
  Value<String?> userPayload,
  Value<String?> leaseOwner,
  Value<int?> leaseUntil,
  Value<int?> nextSyncAt,
  Value<int?> lastSyncedAt,
  Value<int> consecutiveFailures,
  Value<int?> backoffUntil,
  Value<int> requestRejections,
  Value<String> status,
  Value<String?> statusCode,
  Value<String?> lastError,
  Value<int> clockSkewMs,
  Value<String?> appVersion,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<int> id,
  Value<String> userId,
  Value<String> deviceId,
  Value<String?> cursor,
  Value<String?> bootstrapCursor,
  Value<String?> calendarTimezone,
  Value<int> calendarDayStartOffset,
  Value<String?> calendarEffectiveAt,
  Value<String?> capabilities,
  Value<String?> userPayload,
  Value<String?> leaseOwner,
  Value<int?> leaseUntil,
  Value<int?> nextSyncAt,
  Value<int?> lastSyncedAt,
  Value<int> consecutiveFailures,
  Value<int?> backoffUntil,
  Value<int> requestRejections,
  Value<String> status,
  Value<String?> statusCode,
  Value<String?> lastError,
  Value<int> clockSkewMs,
  Value<String?> appVersion,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bootstrapCursor => $composableBuilder(
    column: $table.bootstrapCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calendarTimezone => $composableBuilder(
    column: $table.calendarTimezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calendarDayStartOffset => $composableBuilder(
    column: $table.calendarDayStartOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calendarEffectiveAt => $composableBuilder(
    column: $table.calendarEffectiveAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userPayload => $composableBuilder(
    column: $table.userPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextSyncAt => $composableBuilder(
    column: $table.nextSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get backoffUntil => $composableBuilder(
    column: $table.backoffUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requestRejections => $composableBuilder(
    column: $table.requestRejections,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statusCode => $composableBuilder(
    column: $table.statusCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clockSkewMs => $composableBuilder(
    column: $table.clockSkewMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bootstrapCursor => $composableBuilder(
    column: $table.bootstrapCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calendarTimezone => $composableBuilder(
    column: $table.calendarTimezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calendarDayStartOffset => $composableBuilder(
    column: $table.calendarDayStartOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calendarEffectiveAt => $composableBuilder(
    column: $table.calendarEffectiveAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userPayload => $composableBuilder(
    column: $table.userPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextSyncAt => $composableBuilder(
    column: $table.nextSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get backoffUntil => $composableBuilder(
    column: $table.backoffUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requestRejections => $composableBuilder(
    column: $table.requestRejections,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusCode => $composableBuilder(
    column: $table.statusCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clockSkewMs => $composableBuilder(
    column: $table.clockSkewMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<String> get bootstrapCursor => $composableBuilder(
    column: $table.bootstrapCursor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get calendarTimezone => $composableBuilder(
    column: $table.calendarTimezone,
    builder: (column) => column,
  );

  GeneratedColumn<int> get calendarDayStartOffset => $composableBuilder(
    column: $table.calendarDayStartOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get calendarEffectiveAt => $composableBuilder(
    column: $table.calendarEffectiveAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userPayload => $composableBuilder(
    column: $table.userPayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => column,
  );

  GeneratedColumn<int> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextSyncAt => $composableBuilder(
    column: $table.nextSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => column,
  );

  GeneratedColumn<int> get backoffUntil => $composableBuilder(
    column: $table.backoffUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get requestRejections => $composableBuilder(
    column: $table.requestRejections,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get statusCode => $composableBuilder(
    column: $table.statusCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get clockSkewMs => $composableBuilder(
    column: $table.clockSkewMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => column,
  );
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateRow,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<String?> bootstrapCursor = const Value.absent(),
                Value<String?> calendarTimezone = const Value.absent(),
                Value<int> calendarDayStartOffset = const Value.absent(),
                Value<String?> calendarEffectiveAt = const Value.absent(),
                Value<String?> capabilities = const Value.absent(),
                Value<String?> userPayload = const Value.absent(),
                Value<String?> leaseOwner = const Value.absent(),
                Value<int?> leaseUntil = const Value.absent(),
                Value<int?> nextSyncAt = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<int> consecutiveFailures = const Value.absent(),
                Value<int?> backoffUntil = const Value.absent(),
                Value<int> requestRejections = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> statusCode = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> clockSkewMs = const Value.absent(),
                Value<String?> appVersion = const Value.absent(),
              }) => SyncStateCompanion(
                id: id,
                userId: userId,
                deviceId: deviceId,
                cursor: cursor,
                bootstrapCursor: bootstrapCursor,
                calendarTimezone: calendarTimezone,
                calendarDayStartOffset: calendarDayStartOffset,
                calendarEffectiveAt: calendarEffectiveAt,
                capabilities: capabilities,
                userPayload: userPayload,
                leaseOwner: leaseOwner,
                leaseUntil: leaseUntil,
                nextSyncAt: nextSyncAt,
                lastSyncedAt: lastSyncedAt,
                consecutiveFailures: consecutiveFailures,
                backoffUntil: backoffUntil,
                requestRejections: requestRejections,
                status: status,
                statusCode: statusCode,
                lastError: lastError,
                clockSkewMs: clockSkewMs,
                appVersion: appVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String userId,
                required String deviceId,
                Value<String?> cursor = const Value.absent(),
                Value<String?> bootstrapCursor = const Value.absent(),
                Value<String?> calendarTimezone = const Value.absent(),
                Value<int> calendarDayStartOffset = const Value.absent(),
                Value<String?> calendarEffectiveAt = const Value.absent(),
                Value<String?> capabilities = const Value.absent(),
                Value<String?> userPayload = const Value.absent(),
                Value<String?> leaseOwner = const Value.absent(),
                Value<int?> leaseUntil = const Value.absent(),
                Value<int?> nextSyncAt = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<int> consecutiveFailures = const Value.absent(),
                Value<int?> backoffUntil = const Value.absent(),
                Value<int> requestRejections = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> statusCode = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> clockSkewMs = const Value.absent(),
                Value<String?> appVersion = const Value.absent(),
              }) => SyncStateCompanion.insert(
                id: id,
                userId: userId,
                deviceId: deviceId,
                cursor: cursor,
                bootstrapCursor: bootstrapCursor,
                calendarTimezone: calendarTimezone,
                calendarDayStartOffset: calendarDayStartOffset,
                calendarEffectiveAt: calendarEffectiveAt,
                capabilities: capabilities,
                userPayload: userPayload,
                leaseOwner: leaseOwner,
                leaseUntil: leaseUntil,
                nextSyncAt: nextSyncAt,
                lastSyncedAt: lastSyncedAt,
                consecutiveFailures: consecutiveFailures,
                backoffUntil: backoffUntil,
                requestRejections: requestRejections,
                status: status,
                statusCode: statusCode,
                lastError: lastError,
                clockSkewMs: clockSkewMs,
                appVersion: appVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStateTable, SyncStateRow>(table),
                  BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateRow,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;
typedef $$DiscardedMutationsTableCreateCompanionBuilder =
    DiscardedMutationsCompanion Function({
      required String mutationId,
      required String entity,
      required String entityId,
      required String operation,
      required String payload,
      Value<String?> localDateHint,
      Value<String?> lastError,
      required int discardedAt,
      Value<int> rowid,
    });
typedef $$DiscardedMutationsTableUpdateCompanionBuilder =
    DiscardedMutationsCompanion Function({
      Value<String> mutationId,
      Value<String> entity,
      Value<String> entityId,
      Value<String> operation,
      Value<String> payload,
      Value<String?> localDateHint,
      Value<String?> lastError,
      Value<int> discardedAt,
      Value<int> rowid,
    });

class $$DiscardedMutationsTableFilterComposer
    extends Composer<_$AppDatabase, $DiscardedMutationsTable> {
  $$DiscardedMutationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDateHint => $composableBuilder(
    column: $table.localDateHint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discardedAt => $composableBuilder(
    column: $table.discardedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiscardedMutationsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiscardedMutationsTable> {
  $$DiscardedMutationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDateHint => $composableBuilder(
    column: $table.localDateHint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discardedAt => $composableBuilder(
    column: $table.discardedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiscardedMutationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiscardedMutationsTable> {
  $$DiscardedMutationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get localDateHint => $composableBuilder(
    column: $table.localDateHint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get discardedAt => $composableBuilder(
    column: $table.discardedAt,
    builder: (column) => column,
  );
}

class $$DiscardedMutationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiscardedMutationsTable,
          DiscardedMutation,
          $$DiscardedMutationsTableFilterComposer,
          $$DiscardedMutationsTableOrderingComposer,
          $$DiscardedMutationsTableAnnotationComposer,
          $$DiscardedMutationsTableCreateCompanionBuilder,
          $$DiscardedMutationsTableUpdateCompanionBuilder,
          (
            DiscardedMutation,
            BaseReferences<
              _$AppDatabase,
              $DiscardedMutationsTable,
              DiscardedMutation
            >,
          ),
          DiscardedMutation,
          PrefetchHooks Function()
        > {
  $$DiscardedMutationsTableTableManager(
    _$AppDatabase db,
    $DiscardedMutationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiscardedMutationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiscardedMutationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiscardedMutationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> mutationId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String?> localDateHint = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> discardedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiscardedMutationsCompanion(
                mutationId: mutationId,
                entity: entity,
                entityId: entityId,
                operation: operation,
                payload: payload,
                localDateHint: localDateHint,
                lastError: lastError,
                discardedAt: discardedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mutationId,
                required String entity,
                required String entityId,
                required String operation,
                required String payload,
                Value<String?> localDateHint = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required int discardedAt,
                Value<int> rowid = const Value.absent(),
              }) => DiscardedMutationsCompanion.insert(
                mutationId: mutationId,
                entity: entity,
                entityId: entityId,
                operation: operation,
                payload: payload,
                localDateHint: localDateHint,
                lastError: lastError,
                discardedAt: discardedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiscardedMutationsTable, DiscardedMutation>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $DiscardedMutationsTable,
                    DiscardedMutation
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiscardedMutationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiscardedMutationsTable,
      DiscardedMutation,
      $$DiscardedMutationsTableFilterComposer,
      $$DiscardedMutationsTableOrderingComposer,
      $$DiscardedMutationsTableAnnotationComposer,
      $$DiscardedMutationsTableCreateCompanionBuilder,
      $$DiscardedMutationsTableUpdateCompanionBuilder,
      (
        DiscardedMutation,
        BaseReferences<
          _$AppDatabase,
          $DiscardedMutationsTable,
          DiscardedMutation
        >,
      ),
      DiscardedMutation,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HabitsTableTableManager get habits =>
      $$HabitsTableTableManager(_db, _db.habits);
  $$HabitLogsTableTableManager get habitLogs =>
      $$HabitLogsTableTableManager(_db, _db.habitLogs);
  $$OpaqueEntitiesTableTableManager get opaqueEntities =>
      $$OpaqueEntitiesTableTableManager(_db, _db.opaqueEntities);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$DiscardedMutationsTableTableManager get discardedMutations =>
      $$DiscardedMutationsTableTableManager(_db, _db.discardedMutations);
}
