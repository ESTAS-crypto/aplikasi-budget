// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $WheelSlotsTable extends WheelSlots
    with TableInfo<$WheelSlotsTable, WheelSlot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WheelSlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, amount, orderIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wheel_slots';
  @override
  VerificationContext validateIntegrity(
    Insertable<WheelSlot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WheelSlot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WheelSlot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
    );
  }

  @override
  $WheelSlotsTable createAlias(String alias) {
    return $WheelSlotsTable(attachedDatabase, alias);
  }
}

class WheelSlot extends DataClass implements Insertable<WheelSlot> {
  final int id;
  final int amount;
  final int orderIndex;
  const WheelSlot({
    required this.id,
    required this.amount,
    required this.orderIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['amount'] = Variable<int>(amount);
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  WheelSlotsCompanion toCompanion(bool nullToAbsent) {
    return WheelSlotsCompanion(
      id: Value(id),
      amount: Value(amount),
      orderIndex: Value(orderIndex),
    );
  }

  factory WheelSlot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WheelSlot(
      id: serializer.fromJson<int>(json['id']),
      amount: serializer.fromJson<int>(json['amount']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'amount': serializer.toJson<int>(amount),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  WheelSlot copyWith({int? id, int? amount, int? orderIndex}) => WheelSlot(
    id: id ?? this.id,
    amount: amount ?? this.amount,
    orderIndex: orderIndex ?? this.orderIndex,
  );
  WheelSlot copyWithCompanion(WheelSlotsCompanion data) {
    return WheelSlot(
      id: data.id.present ? data.id.value : this.id,
      amount: data.amount.present ? data.amount.value : this.amount,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WheelSlot(')
          ..write('id: $id, ')
          ..write('amount: $amount, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, amount, orderIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WheelSlot &&
          other.id == this.id &&
          other.amount == this.amount &&
          other.orderIndex == this.orderIndex);
}

class WheelSlotsCompanion extends UpdateCompanion<WheelSlot> {
  final Value<int> id;
  final Value<int> amount;
  final Value<int> orderIndex;
  const WheelSlotsCompanion({
    this.id = const Value.absent(),
    this.amount = const Value.absent(),
    this.orderIndex = const Value.absent(),
  });
  WheelSlotsCompanion.insert({
    this.id = const Value.absent(),
    required int amount,
    required int orderIndex,
  }) : amount = Value(amount),
       orderIndex = Value(orderIndex);
  static Insertable<WheelSlot> custom({
    Expression<int>? id,
    Expression<int>? amount,
    Expression<int>? orderIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (amount != null) 'amount': amount,
      if (orderIndex != null) 'order_index': orderIndex,
    });
  }

  WheelSlotsCompanion copyWith({
    Value<int>? id,
    Value<int>? amount,
    Value<int>? orderIndex,
  }) {
    return WheelSlotsCompanion(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WheelSlotsCompanion(')
          ..write('id: $id, ')
          ..write('amount: $amount, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }
}

class $DateRecordsTable extends DateRecords
    with TableInfo<$DateRecordsTable, DateRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DateRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _budgetMeta = const VerificationMeta('budget');
  @override
  late final GeneratedColumn<int> budget = GeneratedColumn<int>(
    'budget',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPassedMeta = const VerificationMeta(
    'isPassed',
  );
  @override
  late final GeneratedColumn<bool> isPassed = GeneratedColumn<bool>(
    'is_passed',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_passed" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    budget,
    status,
    startedAt,
    finishedAt,
    isPassed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'date_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DateRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('budget')) {
      context.handle(
        _budgetMeta,
        budget.isAcceptableOrUnknown(data['budget']!, _budgetMeta),
      );
    } else if (isInserting) {
      context.missing(_budgetMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('is_passed')) {
      context.handle(
        _isPassedMeta,
        isPassed.isAcceptableOrUnknown(data['is_passed']!, _isPassedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DateRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DateRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      budget: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}budget'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      isPassed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_passed'],
      ),
    );
  }

  @override
  $DateRecordsTable createAlias(String alias) {
    return $DateRecordsTable(attachedDatabase, alias);
  }
}

class DateRecord extends DataClass implements Insertable<DateRecord> {
  final int id;
  final int budget;
  final String status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final bool? isPassed;
  const DateRecord({
    required this.id,
    required this.budget,
    required this.status,
    required this.startedAt,
    this.finishedAt,
    this.isPassed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['budget'] = Variable<int>(budget);
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    if (!nullToAbsent || isPassed != null) {
      map['is_passed'] = Variable<bool>(isPassed);
    }
    return map;
  }

  DateRecordsCompanion toCompanion(bool nullToAbsent) {
    return DateRecordsCompanion(
      id: Value(id),
      budget: Value(budget),
      status: Value(status),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      isPassed: isPassed == null && nullToAbsent
          ? const Value.absent()
          : Value(isPassed),
    );
  }

  factory DateRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DateRecord(
      id: serializer.fromJson<int>(json['id']),
      budget: serializer.fromJson<int>(json['budget']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      isPassed: serializer.fromJson<bool?>(json['isPassed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'budget': serializer.toJson<int>(budget),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'isPassed': serializer.toJson<bool?>(isPassed),
    };
  }

  DateRecord copyWith({
    int? id,
    int? budget,
    String? status,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    Value<bool?> isPassed = const Value.absent(),
  }) => DateRecord(
    id: id ?? this.id,
    budget: budget ?? this.budget,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    isPassed: isPassed.present ? isPassed.value : this.isPassed,
  );
  DateRecord copyWithCompanion(DateRecordsCompanion data) {
    return DateRecord(
      id: data.id.present ? data.id.value : this.id,
      budget: data.budget.present ? data.budget.value : this.budget,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      isPassed: data.isPassed.present ? data.isPassed.value : this.isPassed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DateRecord(')
          ..write('id: $id, ')
          ..write('budget: $budget, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('isPassed: $isPassed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, budget, status, startedAt, finishedAt, isPassed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DateRecord &&
          other.id == this.id &&
          other.budget == this.budget &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.isPassed == this.isPassed);
}

class DateRecordsCompanion extends UpdateCompanion<DateRecord> {
  final Value<int> id;
  final Value<int> budget;
  final Value<String> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<bool?> isPassed;
  const DateRecordsCompanion({
    this.id = const Value.absent(),
    this.budget = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.isPassed = const Value.absent(),
  });
  DateRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int budget,
    required String status,
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
    this.isPassed = const Value.absent(),
  }) : budget = Value(budget),
       status = Value(status),
       startedAt = Value(startedAt);
  static Insertable<DateRecord> custom({
    Expression<int>? id,
    Expression<int>? budget,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<bool>? isPassed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (budget != null) 'budget': budget,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (isPassed != null) 'is_passed': isPassed,
    });
  }

  DateRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? budget,
    Value<String>? status,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<bool?>? isPassed,
  }) {
    return DateRecordsCompanion(
      id: id ?? this.id,
      budget: budget ?? this.budget,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      isPassed: isPassed ?? this.isPassed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (budget.present) {
      map['budget'] = Variable<int>(budget.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (isPassed.present) {
      map['is_passed'] = Variable<bool>(isPassed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DateRecordsCompanion(')
          ..write('id: $id, ')
          ..write('budget: $budget, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('isPassed: $isPassed')
          ..write(')'))
        .toString();
  }
}

class $DateItemRecordsTable extends DateItemRecords
    with TableInfo<$DateItemRecordsTable, DateItemRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DateItemRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateIdMeta = const VerificationMeta('dateId');
  @override
  late final GeneratedColumn<int> dateId = GeneratedColumn<int>(
    'date_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, dateId, name, price, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'date_item_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DateItemRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date_id')) {
      context.handle(
        _dateIdMeta,
        dateId.isAcceptableOrUnknown(data['date_id']!, _dateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dateIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DateItemRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DateItemRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dateId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DateItemRecordsTable createAlias(String alias) {
    return $DateItemRecordsTable(attachedDatabase, alias);
  }
}

class DateItemRecord extends DataClass implements Insertable<DateItemRecord> {
  final int id;
  final int dateId;
  final String name;
  final int price;
  final DateTime createdAt;
  const DateItemRecord({
    required this.id,
    required this.dateId,
    required this.name,
    required this.price,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date_id'] = Variable<int>(dateId);
    map['name'] = Variable<String>(name);
    map['price'] = Variable<int>(price);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DateItemRecordsCompanion toCompanion(bool nullToAbsent) {
    return DateItemRecordsCompanion(
      id: Value(id),
      dateId: Value(dateId),
      name: Value(name),
      price: Value(price),
      createdAt: Value(createdAt),
    );
  }

  factory DateItemRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DateItemRecord(
      id: serializer.fromJson<int>(json['id']),
      dateId: serializer.fromJson<int>(json['dateId']),
      name: serializer.fromJson<String>(json['name']),
      price: serializer.fromJson<int>(json['price']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dateId': serializer.toJson<int>(dateId),
      'name': serializer.toJson<String>(name),
      'price': serializer.toJson<int>(price),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DateItemRecord copyWith({
    int? id,
    int? dateId,
    String? name,
    int? price,
    DateTime? createdAt,
  }) => DateItemRecord(
    id: id ?? this.id,
    dateId: dateId ?? this.dateId,
    name: name ?? this.name,
    price: price ?? this.price,
    createdAt: createdAt ?? this.createdAt,
  );
  DateItemRecord copyWithCompanion(DateItemRecordsCompanion data) {
    return DateItemRecord(
      id: data.id.present ? data.id.value : this.id,
      dateId: data.dateId.present ? data.dateId.value : this.dateId,
      name: data.name.present ? data.name.value : this.name,
      price: data.price.present ? data.price.value : this.price,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DateItemRecord(')
          ..write('id: $id, ')
          ..write('dateId: $dateId, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dateId, name, price, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DateItemRecord &&
          other.id == this.id &&
          other.dateId == this.dateId &&
          other.name == this.name &&
          other.price == this.price &&
          other.createdAt == this.createdAt);
}

class DateItemRecordsCompanion extends UpdateCompanion<DateItemRecord> {
  final Value<int> id;
  final Value<int> dateId;
  final Value<String> name;
  final Value<int> price;
  final Value<DateTime> createdAt;
  const DateItemRecordsCompanion({
    this.id = const Value.absent(),
    this.dateId = const Value.absent(),
    this.name = const Value.absent(),
    this.price = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DateItemRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int dateId,
    required String name,
    required int price,
    required DateTime createdAt,
  }) : dateId = Value(dateId),
       name = Value(name),
       price = Value(price),
       createdAt = Value(createdAt);
  static Insertable<DateItemRecord> custom({
    Expression<int>? id,
    Expression<int>? dateId,
    Expression<String>? name,
    Expression<int>? price,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dateId != null) 'date_id': dateId,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DateItemRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? dateId,
    Value<String>? name,
    Value<int>? price,
    Value<DateTime>? createdAt,
  }) {
    return DateItemRecordsCompanion(
      id: id ?? this.id,
      dateId: dateId ?? this.dateId,
      name: name ?? this.name,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dateId.present) {
      map['date_id'] = Variable<int>(dateId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DateItemRecordsCompanion(')
          ..write('id: $id, ')
          ..write('dateId: $dateId, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WheelSlotsTable wheelSlots = $WheelSlotsTable(this);
  late final $DateRecordsTable dateRecords = $DateRecordsTable(this);
  late final $DateItemRecordsTable dateItemRecords = $DateItemRecordsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    wheelSlots,
    dateRecords,
    dateItemRecords,
  ];
}

typedef $$WheelSlotsTableCreateCompanionBuilder =
    WheelSlotsCompanion Function({
      Value<int> id,
      required int amount,
      required int orderIndex,
    });
typedef $$WheelSlotsTableUpdateCompanionBuilder =
    WheelSlotsCompanion Function({
      Value<int> id,
      Value<int> amount,
      Value<int> orderIndex,
    });

class $$WheelSlotsTableFilterComposer
    extends Composer<_$AppDatabase, $WheelSlotsTable> {
  $$WheelSlotsTableFilterComposer({
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

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WheelSlotsTableOrderingComposer
    extends Composer<_$AppDatabase, $WheelSlotsTable> {
  $$WheelSlotsTableOrderingComposer({
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

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WheelSlotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WheelSlotsTable> {
  $$WheelSlotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );
}

class $$WheelSlotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WheelSlotsTable,
          WheelSlot,
          $$WheelSlotsTableFilterComposer,
          $$WheelSlotsTableOrderingComposer,
          $$WheelSlotsTableAnnotationComposer,
          $$WheelSlotsTableCreateCompanionBuilder,
          $$WheelSlotsTableUpdateCompanionBuilder,
          (
            WheelSlot,
            BaseReferences<_$AppDatabase, $WheelSlotsTable, WheelSlot>,
          ),
          WheelSlot,
          PrefetchHooks Function()
        > {
  $$WheelSlotsTableTableManager(_$AppDatabase db, $WheelSlotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WheelSlotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WheelSlotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WheelSlotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
              }) => WheelSlotsCompanion(
                id: id,
                amount: amount,
                orderIndex: orderIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int amount,
                required int orderIndex,
              }) => WheelSlotsCompanion.insert(
                id: id,
                amount: amount,
                orderIndex: orderIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WheelSlotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WheelSlotsTable,
      WheelSlot,
      $$WheelSlotsTableFilterComposer,
      $$WheelSlotsTableOrderingComposer,
      $$WheelSlotsTableAnnotationComposer,
      $$WheelSlotsTableCreateCompanionBuilder,
      $$WheelSlotsTableUpdateCompanionBuilder,
      (WheelSlot, BaseReferences<_$AppDatabase, $WheelSlotsTable, WheelSlot>),
      WheelSlot,
      PrefetchHooks Function()
    >;
typedef $$DateRecordsTableCreateCompanionBuilder =
    DateRecordsCompanion Function({
      Value<int> id,
      required int budget,
      required String status,
      required DateTime startedAt,
      Value<DateTime?> finishedAt,
      Value<bool?> isPassed,
    });
typedef $$DateRecordsTableUpdateCompanionBuilder =
    DateRecordsCompanion Function({
      Value<int> id,
      Value<int> budget,
      Value<String> status,
      Value<DateTime> startedAt,
      Value<DateTime?> finishedAt,
      Value<bool?> isPassed,
    });

class $$DateRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DateRecordsTable> {
  $$DateRecordsTableFilterComposer({
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

  ColumnFilters<int> get budget => $composableBuilder(
    column: $table.budget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPassed => $composableBuilder(
    column: $table.isPassed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DateRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DateRecordsTable> {
  $$DateRecordsTableOrderingComposer({
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

  ColumnOrderings<int> get budget => $composableBuilder(
    column: $table.budget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPassed => $composableBuilder(
    column: $table.isPassed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DateRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DateRecordsTable> {
  $$DateRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get budget =>
      $composableBuilder(column: $table.budget, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPassed =>
      $composableBuilder(column: $table.isPassed, builder: (column) => column);
}

class $$DateRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DateRecordsTable,
          DateRecord,
          $$DateRecordsTableFilterComposer,
          $$DateRecordsTableOrderingComposer,
          $$DateRecordsTableAnnotationComposer,
          $$DateRecordsTableCreateCompanionBuilder,
          $$DateRecordsTableUpdateCompanionBuilder,
          (
            DateRecord,
            BaseReferences<_$AppDatabase, $DateRecordsTable, DateRecord>,
          ),
          DateRecord,
          PrefetchHooks Function()
        > {
  $$DateRecordsTableTableManager(_$AppDatabase db, $DateRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DateRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DateRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DateRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> budget = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<bool?> isPassed = const Value.absent(),
              }) => DateRecordsCompanion(
                id: id,
                budget: budget,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
                isPassed: isPassed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int budget,
                required String status,
                required DateTime startedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<bool?> isPassed = const Value.absent(),
              }) => DateRecordsCompanion.insert(
                id: id,
                budget: budget,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
                isPassed: isPassed,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DateRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DateRecordsTable,
      DateRecord,
      $$DateRecordsTableFilterComposer,
      $$DateRecordsTableOrderingComposer,
      $$DateRecordsTableAnnotationComposer,
      $$DateRecordsTableCreateCompanionBuilder,
      $$DateRecordsTableUpdateCompanionBuilder,
      (
        DateRecord,
        BaseReferences<_$AppDatabase, $DateRecordsTable, DateRecord>,
      ),
      DateRecord,
      PrefetchHooks Function()
    >;
typedef $$DateItemRecordsTableCreateCompanionBuilder =
    DateItemRecordsCompanion Function({
      Value<int> id,
      required int dateId,
      required String name,
      required int price,
      required DateTime createdAt,
    });
typedef $$DateItemRecordsTableUpdateCompanionBuilder =
    DateItemRecordsCompanion Function({
      Value<int> id,
      Value<int> dateId,
      Value<String> name,
      Value<int> price,
      Value<DateTime> createdAt,
    });

class $$DateItemRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DateItemRecordsTable> {
  $$DateItemRecordsTableFilterComposer({
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

  ColumnFilters<int> get dateId => $composableBuilder(
    column: $table.dateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DateItemRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DateItemRecordsTable> {
  $$DateItemRecordsTableOrderingComposer({
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

  ColumnOrderings<int> get dateId => $composableBuilder(
    column: $table.dateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DateItemRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DateItemRecordsTable> {
  $$DateItemRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dateId =>
      $composableBuilder(column: $table.dateId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DateItemRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DateItemRecordsTable,
          DateItemRecord,
          $$DateItemRecordsTableFilterComposer,
          $$DateItemRecordsTableOrderingComposer,
          $$DateItemRecordsTableAnnotationComposer,
          $$DateItemRecordsTableCreateCompanionBuilder,
          $$DateItemRecordsTableUpdateCompanionBuilder,
          (
            DateItemRecord,
            BaseReferences<
              _$AppDatabase,
              $DateItemRecordsTable,
              DateItemRecord
            >,
          ),
          DateItemRecord,
          PrefetchHooks Function()
        > {
  $$DateItemRecordsTableTableManager(
    _$AppDatabase db,
    $DateItemRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DateItemRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DateItemRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DateItemRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dateId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> price = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DateItemRecordsCompanion(
                id: id,
                dateId: dateId,
                name: name,
                price: price,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int dateId,
                required String name,
                required int price,
                required DateTime createdAt,
              }) => DateItemRecordsCompanion.insert(
                id: id,
                dateId: dateId,
                name: name,
                price: price,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DateItemRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DateItemRecordsTable,
      DateItemRecord,
      $$DateItemRecordsTableFilterComposer,
      $$DateItemRecordsTableOrderingComposer,
      $$DateItemRecordsTableAnnotationComposer,
      $$DateItemRecordsTableCreateCompanionBuilder,
      $$DateItemRecordsTableUpdateCompanionBuilder,
      (
        DateItemRecord,
        BaseReferences<_$AppDatabase, $DateItemRecordsTable, DateItemRecord>,
      ),
      DateItemRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WheelSlotsTableTableManager get wheelSlots =>
      $$WheelSlotsTableTableManager(_db, _db.wheelSlots);
  $$DateRecordsTableTableManager get dateRecords =>
      $$DateRecordsTableTableManager(_db, _db.dateRecords);
  $$DateItemRecordsTableTableManager get dateItemRecords =>
      $$DateItemRecordsTableTableManager(_db, _db.dateItemRecords);
}
