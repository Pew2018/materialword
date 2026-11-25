// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WordsTable extends Words with TableInfo<$WordsTable, Word> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedMeta = const VerificationMeta(
    'normalized',
  );
  @override
  late final GeneratedColumn<String> normalized = GeneratedColumn<String>(
    'normalized',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneticMeta = const VerificationMeta(
    'phonetic',
  );
  @override
  late final GeneratedColumn<String> phonetic = GeneratedColumn<String>(
    'phonetic',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _partOfSpeechMeta = const VerificationMeta(
    'partOfSpeech',
  );
  @override
  late final GeneratedColumn<String> partOfSpeech = GeneratedColumn<String>(
    'part_of_speech',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _translationMeta = const VerificationMeta(
    'translation',
  );
  @override
  late final GeneratedColumn<String> translation = GeneratedColumn<String>(
    'translation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _definitionMeta = const VerificationMeta(
    'definition',
  );
  @override
  late final GeneratedColumn<String> definition = GeneratedColumn<String>(
    'definition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _exampleMeta = const VerificationMeta(
    'example',
  );
  @override
  late final GeneratedColumn<String> example = GeneratedColumn<String>(
    'example',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _phraseMeta = const VerificationMeta('phrase');
  @override
  late final GeneratedColumn<String> phrase = GeneratedColumn<String>(
    'phrase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _examTagsMeta = const VerificationMeta(
    'examTags',
  );
  @override
  late final GeneratedColumn<String> examTags = GeneratedColumn<String>(
    'exam_tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bncRankMeta = const VerificationMeta(
    'bncRank',
  );
  @override
  late final GeneratedColumn<int> bncRank = GeneratedColumn<int>(
    'bnc_rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _frqRankMeta = const VerificationMeta(
    'frqRank',
  );
  @override
  late final GeneratedColumn<int> frqRank = GeneratedColumn<int>(
    'frq_rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _customizedMeta = const VerificationMeta(
    'customized',
  );
  @override
  late final GeneratedColumn<bool> customized = GeneratedColumn<bool>(
    'customized',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("customized" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    word,
    normalized,
    phonetic,
    partOfSpeech,
    translation,
    definition,
    example,
    phrase,
    note,
    source,
    examTags,
    bncRank,
    frqRank,
    customized,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'words';
  @override
  VerificationContext validateIntegrity(
    Insertable<Word> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('normalized')) {
      context.handle(
        _normalizedMeta,
        normalized.isAcceptableOrUnknown(data['normalized']!, _normalizedMeta),
      );
    } else if (isInserting) {
      context.missing(_normalizedMeta);
    }
    if (data.containsKey('phonetic')) {
      context.handle(
        _phoneticMeta,
        phonetic.isAcceptableOrUnknown(data['phonetic']!, _phoneticMeta),
      );
    }
    if (data.containsKey('part_of_speech')) {
      context.handle(
        _partOfSpeechMeta,
        partOfSpeech.isAcceptableOrUnknown(
          data['part_of_speech']!,
          _partOfSpeechMeta,
        ),
      );
    }
    if (data.containsKey('translation')) {
      context.handle(
        _translationMeta,
        translation.isAcceptableOrUnknown(
          data['translation']!,
          _translationMeta,
        ),
      );
    }
    if (data.containsKey('definition')) {
      context.handle(
        _definitionMeta,
        definition.isAcceptableOrUnknown(data['definition']!, _definitionMeta),
      );
    }
    if (data.containsKey('example')) {
      context.handle(
        _exampleMeta,
        example.isAcceptableOrUnknown(data['example']!, _exampleMeta),
      );
    }
    if (data.containsKey('phrase')) {
      context.handle(
        _phraseMeta,
        phrase.isAcceptableOrUnknown(data['phrase']!, _phraseMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('exam_tags')) {
      context.handle(
        _examTagsMeta,
        examTags.isAcceptableOrUnknown(data['exam_tags']!, _examTagsMeta),
      );
    }
    if (data.containsKey('bnc_rank')) {
      context.handle(
        _bncRankMeta,
        bncRank.isAcceptableOrUnknown(data['bnc_rank']!, _bncRankMeta),
      );
    }
    if (data.containsKey('frq_rank')) {
      context.handle(
        _frqRankMeta,
        frqRank.isAcceptableOrUnknown(data['frq_rank']!, _frqRankMeta),
      );
    }
    if (data.containsKey('customized')) {
      context.handle(
        _customizedMeta,
        customized.isAcceptableOrUnknown(data['customized']!, _customizedMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Word map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Word(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      normalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized'],
      )!,
      phonetic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phonetic'],
      )!,
      partOfSpeech: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_of_speech'],
      )!,
      translation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation'],
      )!,
      definition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition'],
      )!,
      example: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example'],
      )!,
      phrase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phrase'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      examTags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_tags'],
      )!,
      bncRank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bnc_rank'],
      )!,
      frqRank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}frq_rank'],
      )!,
      customized: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}customized'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $WordsTable createAlias(String alias) {
    return $WordsTable(attachedDatabase, alias);
  }
}

class Word extends DataClass implements Insertable<Word> {
  final String id;
  final String word;
  final String normalized;
  final String phonetic;
  final String partOfSpeech;
  final String translation;
  final String definition;
  final String example;
  final String phrase;
  final String note;
  final String source;
  final String examTags;
  final int bncRank;
  final int frqRank;
  final bool customized;
  final int revision;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const Word({
    required this.id,
    required this.word,
    required this.normalized,
    required this.phonetic,
    required this.partOfSpeech,
    required this.translation,
    required this.definition,
    required this.example,
    required this.phrase,
    required this.note,
    required this.source,
    required this.examTags,
    required this.bncRank,
    required this.frqRank,
    required this.customized,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['word'] = Variable<String>(word);
    map['normalized'] = Variable<String>(normalized);
    map['phonetic'] = Variable<String>(phonetic);
    map['part_of_speech'] = Variable<String>(partOfSpeech);
    map['translation'] = Variable<String>(translation);
    map['definition'] = Variable<String>(definition);
    map['example'] = Variable<String>(example);
    map['phrase'] = Variable<String>(phrase);
    map['note'] = Variable<String>(note);
    map['source'] = Variable<String>(source);
    map['exam_tags'] = Variable<String>(examTags);
    map['bnc_rank'] = Variable<int>(bncRank);
    map['frq_rank'] = Variable<int>(frqRank);
    map['customized'] = Variable<bool>(customized);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  WordsCompanion toCompanion(bool nullToAbsent) {
    return WordsCompanion(
      id: Value(id),
      word: Value(word),
      normalized: Value(normalized),
      phonetic: Value(phonetic),
      partOfSpeech: Value(partOfSpeech),
      translation: Value(translation),
      definition: Value(definition),
      example: Value(example),
      phrase: Value(phrase),
      note: Value(note),
      source: Value(source),
      examTags: Value(examTags),
      bncRank: Value(bncRank),
      frqRank: Value(frqRank),
      customized: Value(customized),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Word.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Word(
      id: serializer.fromJson<String>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      normalized: serializer.fromJson<String>(json['normalized']),
      phonetic: serializer.fromJson<String>(json['phonetic']),
      partOfSpeech: serializer.fromJson<String>(json['partOfSpeech']),
      translation: serializer.fromJson<String>(json['translation']),
      definition: serializer.fromJson<String>(json['definition']),
      example: serializer.fromJson<String>(json['example']),
      phrase: serializer.fromJson<String>(json['phrase']),
      note: serializer.fromJson<String>(json['note']),
      source: serializer.fromJson<String>(json['source']),
      examTags: serializer.fromJson<String>(json['examTags']),
      bncRank: serializer.fromJson<int>(json['bncRank']),
      frqRank: serializer.fromJson<int>(json['frqRank']),
      customized: serializer.fromJson<bool>(json['customized']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'word': serializer.toJson<String>(word),
      'normalized': serializer.toJson<String>(normalized),
      'phonetic': serializer.toJson<String>(phonetic),
      'partOfSpeech': serializer.toJson<String>(partOfSpeech),
      'translation': serializer.toJson<String>(translation),
      'definition': serializer.toJson<String>(definition),
      'example': serializer.toJson<String>(example),
      'phrase': serializer.toJson<String>(phrase),
      'note': serializer.toJson<String>(note),
      'source': serializer.toJson<String>(source),
      'examTags': serializer.toJson<String>(examTags),
      'bncRank': serializer.toJson<int>(bncRank),
      'frqRank': serializer.toJson<int>(frqRank),
      'customized': serializer.toJson<bool>(customized),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  Word copyWith({
    String? id,
    String? word,
    String? normalized,
    String? phonetic,
    String? partOfSpeech,
    String? translation,
    String? definition,
    String? example,
    String? phrase,
    String? note,
    String? source,
    String? examTags,
    int? bncRank,
    int? frqRank,
    bool? customized,
    int? revision,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => Word(
    id: id ?? this.id,
    word: word ?? this.word,
    normalized: normalized ?? this.normalized,
    phonetic: phonetic ?? this.phonetic,
    partOfSpeech: partOfSpeech ?? this.partOfSpeech,
    translation: translation ?? this.translation,
    definition: definition ?? this.definition,
    example: example ?? this.example,
    phrase: phrase ?? this.phrase,
    note: note ?? this.note,
    source: source ?? this.source,
    examTags: examTags ?? this.examTags,
    bncRank: bncRank ?? this.bncRank,
    frqRank: frqRank ?? this.frqRank,
    customized: customized ?? this.customized,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Word copyWithCompanion(WordsCompanion data) {
    return Word(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      normalized: data.normalized.present
          ? data.normalized.value
          : this.normalized,
      phonetic: data.phonetic.present ? data.phonetic.value : this.phonetic,
      partOfSpeech: data.partOfSpeech.present
          ? data.partOfSpeech.value
          : this.partOfSpeech,
      translation: data.translation.present
          ? data.translation.value
          : this.translation,
      definition: data.definition.present
          ? data.definition.value
          : this.definition,
      example: data.example.present ? data.example.value : this.example,
      phrase: data.phrase.present ? data.phrase.value : this.phrase,
      note: data.note.present ? data.note.value : this.note,
      source: data.source.present ? data.source.value : this.source,
      examTags: data.examTags.present ? data.examTags.value : this.examTags,
      bncRank: data.bncRank.present ? data.bncRank.value : this.bncRank,
      frqRank: data.frqRank.present ? data.frqRank.value : this.frqRank,
      customized: data.customized.present
          ? data.customized.value
          : this.customized,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Word(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('normalized: $normalized, ')
          ..write('phonetic: $phonetic, ')
          ..write('partOfSpeech: $partOfSpeech, ')
          ..write('translation: $translation, ')
          ..write('definition: $definition, ')
          ..write('example: $example, ')
          ..write('phrase: $phrase, ')
          ..write('note: $note, ')
          ..write('source: $source, ')
          ..write('examTags: $examTags, ')
          ..write('bncRank: $bncRank, ')
          ..write('frqRank: $frqRank, ')
          ..write('customized: $customized, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    word,
    normalized,
    phonetic,
    partOfSpeech,
    translation,
    definition,
    example,
    phrase,
    note,
    source,
    examTags,
    bncRank,
    frqRank,
    customized,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Word &&
          other.id == this.id &&
          other.word == this.word &&
          other.normalized == this.normalized &&
          other.phonetic == this.phonetic &&
          other.partOfSpeech == this.partOfSpeech &&
          other.translation == this.translation &&
          other.definition == this.definition &&
          other.example == this.example &&
          other.phrase == this.phrase &&
          other.note == this.note &&
          other.source == this.source &&
          other.examTags == this.examTags &&
          other.bncRank == this.bncRank &&
          other.frqRank == this.frqRank &&
          other.customized == this.customized &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class WordsCompanion extends UpdateCompanion<Word> {
  final Value<String> id;
  final Value<String> word;
  final Value<String> normalized;
  final Value<String> phonetic;
  final Value<String> partOfSpeech;
  final Value<String> translation;
  final Value<String> definition;
  final Value<String> example;
  final Value<String> phrase;
  final Value<String> note;
  final Value<String> source;
  final Value<String> examTags;
  final Value<int> bncRank;
  final Value<int> frqRank;
  final Value<bool> customized;
  final Value<int> revision;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const WordsCompanion({
    this.id = const Value.absent(),
    this.word = const Value.absent(),
    this.normalized = const Value.absent(),
    this.phonetic = const Value.absent(),
    this.partOfSpeech = const Value.absent(),
    this.translation = const Value.absent(),
    this.definition = const Value.absent(),
    this.example = const Value.absent(),
    this.phrase = const Value.absent(),
    this.note = const Value.absent(),
    this.source = const Value.absent(),
    this.examTags = const Value.absent(),
    this.bncRank = const Value.absent(),
    this.frqRank = const Value.absent(),
    this.customized = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordsCompanion.insert({
    required String id,
    required String word,
    required String normalized,
    this.phonetic = const Value.absent(),
    this.partOfSpeech = const Value.absent(),
    this.translation = const Value.absent(),
    this.definition = const Value.absent(),
    this.example = const Value.absent(),
    this.phrase = const Value.absent(),
    this.note = const Value.absent(),
    this.source = const Value.absent(),
    this.examTags = const Value.absent(),
    this.bncRank = const Value.absent(),
    this.frqRank = const Value.absent(),
    this.customized = const Value.absent(),
    this.revision = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       word = Value(word),
       normalized = Value(normalized),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Word> custom({
    Expression<String>? id,
    Expression<String>? word,
    Expression<String>? normalized,
    Expression<String>? phonetic,
    Expression<String>? partOfSpeech,
    Expression<String>? translation,
    Expression<String>? definition,
    Expression<String>? example,
    Expression<String>? phrase,
    Expression<String>? note,
    Expression<String>? source,
    Expression<String>? examTags,
    Expression<int>? bncRank,
    Expression<int>? frqRank,
    Expression<bool>? customized,
    Expression<int>? revision,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (normalized != null) 'normalized': normalized,
      if (phonetic != null) 'phonetic': phonetic,
      if (partOfSpeech != null) 'part_of_speech': partOfSpeech,
      if (translation != null) 'translation': translation,
      if (definition != null) 'definition': definition,
      if (example != null) 'example': example,
      if (phrase != null) 'phrase': phrase,
      if (note != null) 'note': note,
      if (source != null) 'source': source,
      if (examTags != null) 'exam_tags': examTags,
      if (bncRank != null) 'bnc_rank': bncRank,
      if (frqRank != null) 'frq_rank': frqRank,
      if (customized != null) 'customized': customized,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordsCompanion copyWith({
    Value<String>? id,
    Value<String>? word,
    Value<String>? normalized,
    Value<String>? phonetic,
    Value<String>? partOfSpeech,
    Value<String>? translation,
    Value<String>? definition,
    Value<String>? example,
    Value<String>? phrase,
    Value<String>? note,
    Value<String>? source,
    Value<String>? examTags,
    Value<int>? bncRank,
    Value<int>? frqRank,
    Value<bool>? customized,
    Value<int>? revision,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return WordsCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      normalized: normalized ?? this.normalized,
      phonetic: phonetic ?? this.phonetic,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      translation: translation ?? this.translation,
      definition: definition ?? this.definition,
      example: example ?? this.example,
      phrase: phrase ?? this.phrase,
      note: note ?? this.note,
      source: source ?? this.source,
      examTags: examTags ?? this.examTags,
      bncRank: bncRank ?? this.bncRank,
      frqRank: frqRank ?? this.frqRank,
      customized: customized ?? this.customized,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (normalized.present) {
      map['normalized'] = Variable<String>(normalized.value);
    }
    if (phonetic.present) {
      map['phonetic'] = Variable<String>(phonetic.value);
    }
    if (partOfSpeech.present) {
      map['part_of_speech'] = Variable<String>(partOfSpeech.value);
    }
    if (translation.present) {
      map['translation'] = Variable<String>(translation.value);
    }
    if (definition.present) {
      map['definition'] = Variable<String>(definition.value);
    }
    if (example.present) {
      map['example'] = Variable<String>(example.value);
    }
    if (phrase.present) {
      map['phrase'] = Variable<String>(phrase.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (examTags.present) {
      map['exam_tags'] = Variable<String>(examTags.value);
    }
    if (bncRank.present) {
      map['bnc_rank'] = Variable<int>(bncRank.value);
    }
    if (frqRank.present) {
      map['frq_rank'] = Variable<int>(frqRank.value);
    }
    if (customized.present) {
      map['customized'] = Variable<bool>(customized.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordsCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('normalized: $normalized, ')
          ..write('phonetic: $phonetic, ')
          ..write('partOfSpeech: $partOfSpeech, ')
          ..write('translation: $translation, ')
          ..write('definition: $definition, ')
          ..write('example: $example, ')
          ..write('phrase: $phrase, ')
          ..write('note: $note, ')
          ..write('source: $source, ')
          ..write('examTags: $examTags, ')
          ..write('bncRank: $bncRank, ')
          ..write('frqRank: $frqRank, ')
          ..write('customized: $customized, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WordBooksTable extends WordBooks
    with TableInfo<$WordBooksTable, WordBook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordBooksTable(this.attachedDatabase, [this._alias]);
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    sourceType,
    sourceUrl,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_books';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordBook> instance, {
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
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WordBook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordBook(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $WordBooksTable createAlias(String alias) {
    return $WordBooksTable(attachedDatabase, alias);
  }
}

class WordBook extends DataClass implements Insertable<WordBook> {
  final String id;
  final String name;
  final String description;
  final String sourceType;
  final String sourceUrl;
  final int revision;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const WordBook({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceType,
    required this.sourceUrl,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['source_type'] = Variable<String>(sourceType);
    map['source_url'] = Variable<String>(sourceUrl);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  WordBooksCompanion toCompanion(bool nullToAbsent) {
    return WordBooksCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      sourceType: Value(sourceType),
      sourceUrl: Value(sourceUrl),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory WordBook.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordBook(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'sourceType': serializer.toJson<String>(sourceType),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  WordBook copyWith({
    String? id,
    String? name,
    String? description,
    String? sourceType,
    String? sourceUrl,
    int? revision,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => WordBook(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    sourceType: sourceType ?? this.sourceType,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  WordBook copyWithCompanion(WordBooksCompanion data) {
    return WordBook(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordBook(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    sourceType,
    sourceUrl,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordBook &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.sourceType == this.sourceType &&
          other.sourceUrl == this.sourceUrl &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class WordBooksCompanion extends UpdateCompanion<WordBook> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<String> sourceType;
  final Value<String> sourceUrl;
  final Value<int> revision;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const WordBooksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordBooksCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.revision = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WordBook> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? sourceType,
    Expression<String>? sourceUrl,
    Expression<int>? revision,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordBooksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? description,
    Value<String>? sourceType,
    Value<String>? sourceUrl,
    Value<int>? revision,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return WordBooksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sourceType: sourceType ?? this.sourceType,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordBooksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WordBookEntriesTable extends WordBookEntries
    with TableInfo<$WordBookEntriesTable, WordBookEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordBookEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordBookIdMeta = const VerificationMeta(
    'wordBookId',
  );
  @override
  late final GeneratedColumn<String> wordBookId = GeneratedColumn<String>(
    'word_book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES word_books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES words (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    wordBookId,
    wordId,
    addedAt,
    version,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_book_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordBookEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_book_id')) {
      context.handle(
        _wordBookIdMeta,
        wordBookId.isAcceptableOrUnknown(
          data['word_book_id']!,
          _wordBookIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wordBookIdMeta);
    }
    if (data.containsKey('word_id')) {
      context.handle(
        _wordIdMeta,
        wordId.isAcceptableOrUnknown(data['word_id']!, _wordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordBookId, wordId};
  @override
  WordBookEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordBookEntry(
      wordBookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_book_id'],
      )!,
      wordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $WordBookEntriesTable createAlias(String alias) {
    return $WordBookEntriesTable(attachedDatabase, alias);
  }
}

class WordBookEntry extends DataClass implements Insertable<WordBookEntry> {
  final String wordBookId;
  final String wordId;
  final int addedAt;
  final int version;
  final int updatedAt;
  final int? deletedAt;
  const WordBookEntry({
    required this.wordBookId,
    required this.wordId,
    required this.addedAt,
    required this.version,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_book_id'] = Variable<String>(wordBookId);
    map['word_id'] = Variable<String>(wordId);
    map['added_at'] = Variable<int>(addedAt);
    map['version'] = Variable<int>(version);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  WordBookEntriesCompanion toCompanion(bool nullToAbsent) {
    return WordBookEntriesCompanion(
      wordBookId: Value(wordBookId),
      wordId: Value(wordId),
      addedAt: Value(addedAt),
      version: Value(version),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory WordBookEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordBookEntry(
      wordBookId: serializer.fromJson<String>(json['wordBookId']),
      wordId: serializer.fromJson<String>(json['wordId']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      version: serializer.fromJson<int>(json['version']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordBookId': serializer.toJson<String>(wordBookId),
      'wordId': serializer.toJson<String>(wordId),
      'addedAt': serializer.toJson<int>(addedAt),
      'version': serializer.toJson<int>(version),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  WordBookEntry copyWith({
    String? wordBookId,
    String? wordId,
    int? addedAt,
    int? version,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => WordBookEntry(
    wordBookId: wordBookId ?? this.wordBookId,
    wordId: wordId ?? this.wordId,
    addedAt: addedAt ?? this.addedAt,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  WordBookEntry copyWithCompanion(WordBookEntriesCompanion data) {
    return WordBookEntry(
      wordBookId: data.wordBookId.present
          ? data.wordBookId.value
          : this.wordBookId,
      wordId: data.wordId.present ? data.wordId.value : this.wordId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      version: data.version.present ? data.version.value : this.version,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordBookEntry(')
          ..write('wordBookId: $wordBookId, ')
          ..write('wordId: $wordId, ')
          ..write('addedAt: $addedAt, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(wordBookId, wordId, addedAt, version, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordBookEntry &&
          other.wordBookId == this.wordBookId &&
          other.wordId == this.wordId &&
          other.addedAt == this.addedAt &&
          other.version == this.version &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class WordBookEntriesCompanion extends UpdateCompanion<WordBookEntry> {
  final Value<String> wordBookId;
  final Value<String> wordId;
  final Value<int> addedAt;
  final Value<int> version;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const WordBookEntriesCompanion({
    this.wordBookId = const Value.absent(),
    this.wordId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordBookEntriesCompanion.insert({
    required String wordBookId,
    required String wordId,
    required int addedAt,
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : wordBookId = Value(wordBookId),
       wordId = Value(wordId),
       addedAt = Value(addedAt);
  static Insertable<WordBookEntry> custom({
    Expression<String>? wordBookId,
    Expression<String>? wordId,
    Expression<int>? addedAt,
    Expression<int>? version,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordBookId != null) 'word_book_id': wordBookId,
      if (wordId != null) 'word_id': wordId,
      if (addedAt != null) 'added_at': addedAt,
      if (version != null) 'version': version,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordBookEntriesCompanion copyWith({
    Value<String>? wordBookId,
    Value<String>? wordId,
    Value<int>? addedAt,
    Value<int>? version,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return WordBookEntriesCompanion(
      wordBookId: wordBookId ?? this.wordBookId,
      wordId: wordId ?? this.wordId,
      addedAt: addedAt ?? this.addedAt,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordBookId.present) {
      map['word_book_id'] = Variable<String>(wordBookId.value);
    }
    if (wordId.present) {
      map['word_id'] = Variable<String>(wordId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordBookEntriesCompanion(')
          ..write('wordBookId: $wordBookId, ')
          ..write('wordId: $wordId, ')
          ..write('addedAt: $addedAt, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningStatesTable extends LearningStates
    with TableInfo<$LearningStatesTable, LearningState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES words (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<int> stage = GeneratedColumn<int>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _correctCountMeta = const VerificationMeta(
    'correctCount',
  );
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
    'correct_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hazyCountMeta = const VerificationMeta(
    'hazyCount',
  );
  @override
  late final GeneratedColumn<int> hazyCount = GeneratedColumn<int>(
    'hazy_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wrongCountMeta = const VerificationMeta(
    'wrongCount',
  );
  @override
  late final GeneratedColumn<int> wrongCount = GeneratedColumn<int>(
    'wrong_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _streakMeta = const VerificationMeta('streak');
  @override
  late final GeneratedColumn<int> streak = GeneratedColumn<int>(
    'streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastStudiedAtMeta = const VerificationMeta(
    'lastStudiedAt',
  );
  @override
  late final GeneratedColumn<int> lastStudiedAt = GeneratedColumn<int>(
    'last_studied_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextReviewAtMeta = const VerificationMeta(
    'nextReviewAt',
  );
  @override
  late final GeneratedColumn<int> nextReviewAt = GeneratedColumn<int>(
    'next_review_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    wordId,
    stage,
    correctCount,
    hazyCount,
    wrongCount,
    streak,
    intervalDays,
    lastStudiedAt,
    nextReviewAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_id')) {
      context.handle(
        _wordIdMeta,
        wordId.isAcceptableOrUnknown(data['word_id']!, _wordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIdMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    }
    if (data.containsKey('correct_count')) {
      context.handle(
        _correctCountMeta,
        correctCount.isAcceptableOrUnknown(
          data['correct_count']!,
          _correctCountMeta,
        ),
      );
    }
    if (data.containsKey('hazy_count')) {
      context.handle(
        _hazyCountMeta,
        hazyCount.isAcceptableOrUnknown(data['hazy_count']!, _hazyCountMeta),
      );
    }
    if (data.containsKey('wrong_count')) {
      context.handle(
        _wrongCountMeta,
        wrongCount.isAcceptableOrUnknown(data['wrong_count']!, _wrongCountMeta),
      );
    }
    if (data.containsKey('streak')) {
      context.handle(
        _streakMeta,
        streak.isAcceptableOrUnknown(data['streak']!, _streakMeta),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('last_studied_at')) {
      context.handle(
        _lastStudiedAtMeta,
        lastStudiedAt.isAcceptableOrUnknown(
          data['last_studied_at']!,
          _lastStudiedAtMeta,
        ),
      );
    }
    if (data.containsKey('next_review_at')) {
      context.handle(
        _nextReviewAtMeta,
        nextReviewAt.isAcceptableOrUnknown(
          data['next_review_at']!,
          _nextReviewAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordId};
  @override
  LearningState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningState(
      wordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_id'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage'],
      )!,
      correctCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_count'],
      )!,
      hazyCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hazy_count'],
      )!,
      wrongCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wrong_count'],
      )!,
      streak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak'],
      )!,
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      lastStudiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_studied_at'],
      ),
      nextReviewAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_review_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LearningStatesTable createAlias(String alias) {
    return $LearningStatesTable(attachedDatabase, alias);
  }
}

class LearningState extends DataClass implements Insertable<LearningState> {
  final String wordId;
  final int stage;
  final int correctCount;
  final int hazyCount;
  final int wrongCount;
  final int streak;
  final int intervalDays;
  final int? lastStudiedAt;
  final int? nextReviewAt;
  final int updatedAt;
  const LearningState({
    required this.wordId,
    required this.stage,
    required this.correctCount,
    required this.hazyCount,
    required this.wrongCount,
    required this.streak,
    required this.intervalDays,
    this.lastStudiedAt,
    this.nextReviewAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_id'] = Variable<String>(wordId);
    map['stage'] = Variable<int>(stage);
    map['correct_count'] = Variable<int>(correctCount);
    map['hazy_count'] = Variable<int>(hazyCount);
    map['wrong_count'] = Variable<int>(wrongCount);
    map['streak'] = Variable<int>(streak);
    map['interval_days'] = Variable<int>(intervalDays);
    if (!nullToAbsent || lastStudiedAt != null) {
      map['last_studied_at'] = Variable<int>(lastStudiedAt);
    }
    if (!nullToAbsent || nextReviewAt != null) {
      map['next_review_at'] = Variable<int>(nextReviewAt);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  LearningStatesCompanion toCompanion(bool nullToAbsent) {
    return LearningStatesCompanion(
      wordId: Value(wordId),
      stage: Value(stage),
      correctCount: Value(correctCount),
      hazyCount: Value(hazyCount),
      wrongCount: Value(wrongCount),
      streak: Value(streak),
      intervalDays: Value(intervalDays),
      lastStudiedAt: lastStudiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStudiedAt),
      nextReviewAt: nextReviewAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextReviewAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LearningState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningState(
      wordId: serializer.fromJson<String>(json['wordId']),
      stage: serializer.fromJson<int>(json['stage']),
      correctCount: serializer.fromJson<int>(json['correctCount']),
      hazyCount: serializer.fromJson<int>(json['hazyCount']),
      wrongCount: serializer.fromJson<int>(json['wrongCount']),
      streak: serializer.fromJson<int>(json['streak']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      lastStudiedAt: serializer.fromJson<int?>(json['lastStudiedAt']),
      nextReviewAt: serializer.fromJson<int?>(json['nextReviewAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordId': serializer.toJson<String>(wordId),
      'stage': serializer.toJson<int>(stage),
      'correctCount': serializer.toJson<int>(correctCount),
      'hazyCount': serializer.toJson<int>(hazyCount),
      'wrongCount': serializer.toJson<int>(wrongCount),
      'streak': serializer.toJson<int>(streak),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'lastStudiedAt': serializer.toJson<int?>(lastStudiedAt),
      'nextReviewAt': serializer.toJson<int?>(nextReviewAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  LearningState copyWith({
    String? wordId,
    int? stage,
    int? correctCount,
    int? hazyCount,
    int? wrongCount,
    int? streak,
    int? intervalDays,
    Value<int?> lastStudiedAt = const Value.absent(),
    Value<int?> nextReviewAt = const Value.absent(),
    int? updatedAt,
  }) => LearningState(
    wordId: wordId ?? this.wordId,
    stage: stage ?? this.stage,
    correctCount: correctCount ?? this.correctCount,
    hazyCount: hazyCount ?? this.hazyCount,
    wrongCount: wrongCount ?? this.wrongCount,
    streak: streak ?? this.streak,
    intervalDays: intervalDays ?? this.intervalDays,
    lastStudiedAt: lastStudiedAt.present
        ? lastStudiedAt.value
        : this.lastStudiedAt,
    nextReviewAt: nextReviewAt.present ? nextReviewAt.value : this.nextReviewAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LearningState copyWithCompanion(LearningStatesCompanion data) {
    return LearningState(
      wordId: data.wordId.present ? data.wordId.value : this.wordId,
      stage: data.stage.present ? data.stage.value : this.stage,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
      hazyCount: data.hazyCount.present ? data.hazyCount.value : this.hazyCount,
      wrongCount: data.wrongCount.present
          ? data.wrongCount.value
          : this.wrongCount,
      streak: data.streak.present ? data.streak.value : this.streak,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      lastStudiedAt: data.lastStudiedAt.present
          ? data.lastStudiedAt.value
          : this.lastStudiedAt,
      nextReviewAt: data.nextReviewAt.present
          ? data.nextReviewAt.value
          : this.nextReviewAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningState(')
          ..write('wordId: $wordId, ')
          ..write('stage: $stage, ')
          ..write('correctCount: $correctCount, ')
          ..write('hazyCount: $hazyCount, ')
          ..write('wrongCount: $wrongCount, ')
          ..write('streak: $streak, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('lastStudiedAt: $lastStudiedAt, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    wordId,
    stage,
    correctCount,
    hazyCount,
    wrongCount,
    streak,
    intervalDays,
    lastStudiedAt,
    nextReviewAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningState &&
          other.wordId == this.wordId &&
          other.stage == this.stage &&
          other.correctCount == this.correctCount &&
          other.hazyCount == this.hazyCount &&
          other.wrongCount == this.wrongCount &&
          other.streak == this.streak &&
          other.intervalDays == this.intervalDays &&
          other.lastStudiedAt == this.lastStudiedAt &&
          other.nextReviewAt == this.nextReviewAt &&
          other.updatedAt == this.updatedAt);
}

class LearningStatesCompanion extends UpdateCompanion<LearningState> {
  final Value<String> wordId;
  final Value<int> stage;
  final Value<int> correctCount;
  final Value<int> hazyCount;
  final Value<int> wrongCount;
  final Value<int> streak;
  final Value<int> intervalDays;
  final Value<int?> lastStudiedAt;
  final Value<int?> nextReviewAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const LearningStatesCompanion({
    this.wordId = const Value.absent(),
    this.stage = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.hazyCount = const Value.absent(),
    this.wrongCount = const Value.absent(),
    this.streak = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.lastStudiedAt = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningStatesCompanion.insert({
    required String wordId,
    this.stage = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.hazyCount = const Value.absent(),
    this.wrongCount = const Value.absent(),
    this.streak = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.lastStudiedAt = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : wordId = Value(wordId),
       updatedAt = Value(updatedAt);
  static Insertable<LearningState> custom({
    Expression<String>? wordId,
    Expression<int>? stage,
    Expression<int>? correctCount,
    Expression<int>? hazyCount,
    Expression<int>? wrongCount,
    Expression<int>? streak,
    Expression<int>? intervalDays,
    Expression<int>? lastStudiedAt,
    Expression<int>? nextReviewAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordId != null) 'word_id': wordId,
      if (stage != null) 'stage': stage,
      if (correctCount != null) 'correct_count': correctCount,
      if (hazyCount != null) 'hazy_count': hazyCount,
      if (wrongCount != null) 'wrong_count': wrongCount,
      if (streak != null) 'streak': streak,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (lastStudiedAt != null) 'last_studied_at': lastStudiedAt,
      if (nextReviewAt != null) 'next_review_at': nextReviewAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningStatesCompanion copyWith({
    Value<String>? wordId,
    Value<int>? stage,
    Value<int>? correctCount,
    Value<int>? hazyCount,
    Value<int>? wrongCount,
    Value<int>? streak,
    Value<int>? intervalDays,
    Value<int?>? lastStudiedAt,
    Value<int?>? nextReviewAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return LearningStatesCompanion(
      wordId: wordId ?? this.wordId,
      stage: stage ?? this.stage,
      correctCount: correctCount ?? this.correctCount,
      hazyCount: hazyCount ?? this.hazyCount,
      wrongCount: wrongCount ?? this.wrongCount,
      streak: streak ?? this.streak,
      intervalDays: intervalDays ?? this.intervalDays,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordId.present) {
      map['word_id'] = Variable<String>(wordId.value);
    }
    if (stage.present) {
      map['stage'] = Variable<int>(stage.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (hazyCount.present) {
      map['hazy_count'] = Variable<int>(hazyCount.value);
    }
    if (wrongCount.present) {
      map['wrong_count'] = Variable<int>(wrongCount.value);
    }
    if (streak.present) {
      map['streak'] = Variable<int>(streak.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (lastStudiedAt.present) {
      map['last_studied_at'] = Variable<int>(lastStudiedAt.value);
    }
    if (nextReviewAt.present) {
      map['next_review_at'] = Variable<int>(nextReviewAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningStatesCompanion(')
          ..write('wordId: $wordId, ')
          ..write('stage: $stage, ')
          ..write('correctCount: $correctCount, ')
          ..write('hazyCount: $hazyCount, ')
          ..write('wrongCount: $wrongCount, ')
          ..write('streak: $streak, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('lastStudiedAt: $lastStudiedAt, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewEventsTable extends ReviewEvents
    with TableInfo<$ReviewEventsTable, ReviewEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES words (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _answeredAtMeta = const VerificationMeta(
    'answeredAt',
  );
  @override
  late final GeneratedColumn<int> answeredAt = GeneratedColumn<int>(
    'answered_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<int> result = GeneratedColumn<int>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageBeforeMeta = const VerificationMeta(
    'stageBefore',
  );
  @override
  late final GeneratedColumn<int> stageBefore = GeneratedColumn<int>(
    'stage_before',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _intervalDaysAfterMeta = const VerificationMeta(
    'intervalDaysAfter',
  );
  @override
  late final GeneratedColumn<int> intervalDaysAfter = GeneratedColumn<int>(
    'interval_days_after',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _algoVersionMeta = const VerificationMeta(
    'algoVersion',
  );
  @override
  late final GeneratedColumn<int> algoVersion = GeneratedColumn<int>(
    'algo_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('normal'),
  );
  static const VerificationMeta _causalOrderMeta = const VerificationMeta(
    'causalOrder',
  );
  @override
  late final GeneratedColumn<int> causalOrder = GeneratedColumn<int>(
    'causal_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dayStartUtcMeta = const VerificationMeta(
    'dayStartUtc',
  );
  @override
  late final GeneratedColumn<int> dayStartUtc = GeneratedColumn<int>(
    'day_start_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayStartSourceMeta = const VerificationMeta(
    'dayStartSource',
  );
  @override
  late final GeneratedColumn<String> dayStartSource = GeneratedColumn<String>(
    'day_start_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('legacy-utc'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    wordId,
    deviceId,
    answeredAt,
    localDay,
    result,
    type,
    stageBefore,
    intervalDaysAfter,
    algoVersion,
    mode,
    causalOrder,
    dayStartUtc,
    dayStartSource,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('word_id')) {
      context.handle(
        _wordIdMeta,
        wordId.isAcceptableOrUnknown(data['word_id']!, _wordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('answered_at')) {
      context.handle(
        _answeredAtMeta,
        answeredAt.isAcceptableOrUnknown(data['answered_at']!, _answeredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_answeredAtMeta);
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('stage_before')) {
      context.handle(
        _stageBeforeMeta,
        stageBefore.isAcceptableOrUnknown(
          data['stage_before']!,
          _stageBeforeMeta,
        ),
      );
    }
    if (data.containsKey('interval_days_after')) {
      context.handle(
        _intervalDaysAfterMeta,
        intervalDaysAfter.isAcceptableOrUnknown(
          data['interval_days_after']!,
          _intervalDaysAfterMeta,
        ),
      );
    }
    if (data.containsKey('algo_version')) {
      context.handle(
        _algoVersionMeta,
        algoVersion.isAcceptableOrUnknown(
          data['algo_version']!,
          _algoVersionMeta,
        ),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('causal_order')) {
      context.handle(
        _causalOrderMeta,
        causalOrder.isAcceptableOrUnknown(
          data['causal_order']!,
          _causalOrderMeta,
        ),
      );
    }
    if (data.containsKey('day_start_utc')) {
      context.handle(
        _dayStartUtcMeta,
        dayStartUtc.isAcceptableOrUnknown(
          data['day_start_utc']!,
          _dayStartUtcMeta,
        ),
      );
    }
    if (data.containsKey('day_start_source')) {
      context.handle(
        _dayStartSourceMeta,
        dayStartSource.isAcceptableOrUnknown(
          data['day_start_source']!,
          _dayStartSourceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      wordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      answeredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}answered_at'],
      )!,
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}result'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      stageBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage_before'],
      )!,
      intervalDaysAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days_after'],
      )!,
      algoVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}algo_version'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      causalOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}causal_order'],
      )!,
      dayStartUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_start_utc'],
      ),
      dayStartSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_start_source'],
      )!,
    );
  }

  @override
  $ReviewEventsTable createAlias(String alias) {
    return $ReviewEventsTable(attachedDatabase, alias);
  }
}

class ReviewEvent extends DataClass implements Insertable<ReviewEvent> {
  final String id;
  final String wordId;
  final String deviceId;
  final int answeredAt;
  final String localDay;
  final int result;
  final String type;
  final int stageBefore;
  final int intervalDaysAfter;
  final int algoVersion;
  final String mode;

  /// Lamport order per word. Zero is reserved for legacy events.
  final int causalOrder;
  final int? dayStartUtc;
  final String dayStartSource;
  const ReviewEvent({
    required this.id,
    required this.wordId,
    required this.deviceId,
    required this.answeredAt,
    required this.localDay,
    required this.result,
    required this.type,
    required this.stageBefore,
    required this.intervalDaysAfter,
    required this.algoVersion,
    required this.mode,
    required this.causalOrder,
    this.dayStartUtc,
    required this.dayStartSource,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['word_id'] = Variable<String>(wordId);
    map['device_id'] = Variable<String>(deviceId);
    map['answered_at'] = Variable<int>(answeredAt);
    map['local_day'] = Variable<String>(localDay);
    map['result'] = Variable<int>(result);
    map['type'] = Variable<String>(type);
    map['stage_before'] = Variable<int>(stageBefore);
    map['interval_days_after'] = Variable<int>(intervalDaysAfter);
    map['algo_version'] = Variable<int>(algoVersion);
    map['mode'] = Variable<String>(mode);
    map['causal_order'] = Variable<int>(causalOrder);
    if (!nullToAbsent || dayStartUtc != null) {
      map['day_start_utc'] = Variable<int>(dayStartUtc);
    }
    map['day_start_source'] = Variable<String>(dayStartSource);
    return map;
  }

  ReviewEventsCompanion toCompanion(bool nullToAbsent) {
    return ReviewEventsCompanion(
      id: Value(id),
      wordId: Value(wordId),
      deviceId: Value(deviceId),
      answeredAt: Value(answeredAt),
      localDay: Value(localDay),
      result: Value(result),
      type: Value(type),
      stageBefore: Value(stageBefore),
      intervalDaysAfter: Value(intervalDaysAfter),
      algoVersion: Value(algoVersion),
      mode: Value(mode),
      causalOrder: Value(causalOrder),
      dayStartUtc: dayStartUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(dayStartUtc),
      dayStartSource: Value(dayStartSource),
    );
  }

  factory ReviewEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewEvent(
      id: serializer.fromJson<String>(json['id']),
      wordId: serializer.fromJson<String>(json['wordId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      answeredAt: serializer.fromJson<int>(json['answeredAt']),
      localDay: serializer.fromJson<String>(json['localDay']),
      result: serializer.fromJson<int>(json['result']),
      type: serializer.fromJson<String>(json['type']),
      stageBefore: serializer.fromJson<int>(json['stageBefore']),
      intervalDaysAfter: serializer.fromJson<int>(json['intervalDaysAfter']),
      algoVersion: serializer.fromJson<int>(json['algoVersion']),
      mode: serializer.fromJson<String>(json['mode']),
      causalOrder: serializer.fromJson<int>(json['causalOrder']),
      dayStartUtc: serializer.fromJson<int?>(json['dayStartUtc']),
      dayStartSource: serializer.fromJson<String>(json['dayStartSource']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'wordId': serializer.toJson<String>(wordId),
      'deviceId': serializer.toJson<String>(deviceId),
      'answeredAt': serializer.toJson<int>(answeredAt),
      'localDay': serializer.toJson<String>(localDay),
      'result': serializer.toJson<int>(result),
      'type': serializer.toJson<String>(type),
      'stageBefore': serializer.toJson<int>(stageBefore),
      'intervalDaysAfter': serializer.toJson<int>(intervalDaysAfter),
      'algoVersion': serializer.toJson<int>(algoVersion),
      'mode': serializer.toJson<String>(mode),
      'causalOrder': serializer.toJson<int>(causalOrder),
      'dayStartUtc': serializer.toJson<int?>(dayStartUtc),
      'dayStartSource': serializer.toJson<String>(dayStartSource),
    };
  }

  ReviewEvent copyWith({
    String? id,
    String? wordId,
    String? deviceId,
    int? answeredAt,
    String? localDay,
    int? result,
    String? type,
    int? stageBefore,
    int? intervalDaysAfter,
    int? algoVersion,
    String? mode,
    int? causalOrder,
    Value<int?> dayStartUtc = const Value.absent(),
    String? dayStartSource,
  }) => ReviewEvent(
    id: id ?? this.id,
    wordId: wordId ?? this.wordId,
    deviceId: deviceId ?? this.deviceId,
    answeredAt: answeredAt ?? this.answeredAt,
    localDay: localDay ?? this.localDay,
    result: result ?? this.result,
    type: type ?? this.type,
    stageBefore: stageBefore ?? this.stageBefore,
    intervalDaysAfter: intervalDaysAfter ?? this.intervalDaysAfter,
    algoVersion: algoVersion ?? this.algoVersion,
    mode: mode ?? this.mode,
    causalOrder: causalOrder ?? this.causalOrder,
    dayStartUtc: dayStartUtc.present ? dayStartUtc.value : this.dayStartUtc,
    dayStartSource: dayStartSource ?? this.dayStartSource,
  );
  ReviewEvent copyWithCompanion(ReviewEventsCompanion data) {
    return ReviewEvent(
      id: data.id.present ? data.id.value : this.id,
      wordId: data.wordId.present ? data.wordId.value : this.wordId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      answeredAt: data.answeredAt.present
          ? data.answeredAt.value
          : this.answeredAt,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      result: data.result.present ? data.result.value : this.result,
      type: data.type.present ? data.type.value : this.type,
      stageBefore: data.stageBefore.present
          ? data.stageBefore.value
          : this.stageBefore,
      intervalDaysAfter: data.intervalDaysAfter.present
          ? data.intervalDaysAfter.value
          : this.intervalDaysAfter,
      algoVersion: data.algoVersion.present
          ? data.algoVersion.value
          : this.algoVersion,
      mode: data.mode.present ? data.mode.value : this.mode,
      causalOrder: data.causalOrder.present
          ? data.causalOrder.value
          : this.causalOrder,
      dayStartUtc: data.dayStartUtc.present
          ? data.dayStartUtc.value
          : this.dayStartUtc,
      dayStartSource: data.dayStartSource.present
          ? data.dayStartSource.value
          : this.dayStartSource,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewEvent(')
          ..write('id: $id, ')
          ..write('wordId: $wordId, ')
          ..write('deviceId: $deviceId, ')
          ..write('answeredAt: $answeredAt, ')
          ..write('localDay: $localDay, ')
          ..write('result: $result, ')
          ..write('type: $type, ')
          ..write('stageBefore: $stageBefore, ')
          ..write('intervalDaysAfter: $intervalDaysAfter, ')
          ..write('algoVersion: $algoVersion, ')
          ..write('mode: $mode, ')
          ..write('causalOrder: $causalOrder, ')
          ..write('dayStartUtc: $dayStartUtc, ')
          ..write('dayStartSource: $dayStartSource')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    wordId,
    deviceId,
    answeredAt,
    localDay,
    result,
    type,
    stageBefore,
    intervalDaysAfter,
    algoVersion,
    mode,
    causalOrder,
    dayStartUtc,
    dayStartSource,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewEvent &&
          other.id == this.id &&
          other.wordId == this.wordId &&
          other.deviceId == this.deviceId &&
          other.answeredAt == this.answeredAt &&
          other.localDay == this.localDay &&
          other.result == this.result &&
          other.type == this.type &&
          other.stageBefore == this.stageBefore &&
          other.intervalDaysAfter == this.intervalDaysAfter &&
          other.algoVersion == this.algoVersion &&
          other.mode == this.mode &&
          other.causalOrder == this.causalOrder &&
          other.dayStartUtc == this.dayStartUtc &&
          other.dayStartSource == this.dayStartSource);
}

class ReviewEventsCompanion extends UpdateCompanion<ReviewEvent> {
  final Value<String> id;
  final Value<String> wordId;
  final Value<String> deviceId;
  final Value<int> answeredAt;
  final Value<String> localDay;
  final Value<int> result;
  final Value<String> type;
  final Value<int> stageBefore;
  final Value<int> intervalDaysAfter;
  final Value<int> algoVersion;
  final Value<String> mode;
  final Value<int> causalOrder;
  final Value<int?> dayStartUtc;
  final Value<String> dayStartSource;
  final Value<int> rowid;
  const ReviewEventsCompanion({
    this.id = const Value.absent(),
    this.wordId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.answeredAt = const Value.absent(),
    this.localDay = const Value.absent(),
    this.result = const Value.absent(),
    this.type = const Value.absent(),
    this.stageBefore = const Value.absent(),
    this.intervalDaysAfter = const Value.absent(),
    this.algoVersion = const Value.absent(),
    this.mode = const Value.absent(),
    this.causalOrder = const Value.absent(),
    this.dayStartUtc = const Value.absent(),
    this.dayStartSource = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewEventsCompanion.insert({
    required String id,
    required String wordId,
    required String deviceId,
    required int answeredAt,
    required String localDay,
    required int result,
    required String type,
    this.stageBefore = const Value.absent(),
    this.intervalDaysAfter = const Value.absent(),
    this.algoVersion = const Value.absent(),
    this.mode = const Value.absent(),
    this.causalOrder = const Value.absent(),
    this.dayStartUtc = const Value.absent(),
    this.dayStartSource = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       wordId = Value(wordId),
       deviceId = Value(deviceId),
       answeredAt = Value(answeredAt),
       localDay = Value(localDay),
       result = Value(result),
       type = Value(type);
  static Insertable<ReviewEvent> custom({
    Expression<String>? id,
    Expression<String>? wordId,
    Expression<String>? deviceId,
    Expression<int>? answeredAt,
    Expression<String>? localDay,
    Expression<int>? result,
    Expression<String>? type,
    Expression<int>? stageBefore,
    Expression<int>? intervalDaysAfter,
    Expression<int>? algoVersion,
    Expression<String>? mode,
    Expression<int>? causalOrder,
    Expression<int>? dayStartUtc,
    Expression<String>? dayStartSource,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wordId != null) 'word_id': wordId,
      if (deviceId != null) 'device_id': deviceId,
      if (answeredAt != null) 'answered_at': answeredAt,
      if (localDay != null) 'local_day': localDay,
      if (result != null) 'result': result,
      if (type != null) 'type': type,
      if (stageBefore != null) 'stage_before': stageBefore,
      if (intervalDaysAfter != null) 'interval_days_after': intervalDaysAfter,
      if (algoVersion != null) 'algo_version': algoVersion,
      if (mode != null) 'mode': mode,
      if (causalOrder != null) 'causal_order': causalOrder,
      if (dayStartUtc != null) 'day_start_utc': dayStartUtc,
      if (dayStartSource != null) 'day_start_source': dayStartSource,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? wordId,
    Value<String>? deviceId,
    Value<int>? answeredAt,
    Value<String>? localDay,
    Value<int>? result,
    Value<String>? type,
    Value<int>? stageBefore,
    Value<int>? intervalDaysAfter,
    Value<int>? algoVersion,
    Value<String>? mode,
    Value<int>? causalOrder,
    Value<int?>? dayStartUtc,
    Value<String>? dayStartSource,
    Value<int>? rowid,
  }) {
    return ReviewEventsCompanion(
      id: id ?? this.id,
      wordId: wordId ?? this.wordId,
      deviceId: deviceId ?? this.deviceId,
      answeredAt: answeredAt ?? this.answeredAt,
      localDay: localDay ?? this.localDay,
      result: result ?? this.result,
      type: type ?? this.type,
      stageBefore: stageBefore ?? this.stageBefore,
      intervalDaysAfter: intervalDaysAfter ?? this.intervalDaysAfter,
      algoVersion: algoVersion ?? this.algoVersion,
      mode: mode ?? this.mode,
      causalOrder: causalOrder ?? this.causalOrder,
      dayStartUtc: dayStartUtc ?? this.dayStartUtc,
      dayStartSource: dayStartSource ?? this.dayStartSource,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (wordId.present) {
      map['word_id'] = Variable<String>(wordId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (answeredAt.present) {
      map['answered_at'] = Variable<int>(answeredAt.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (result.present) {
      map['result'] = Variable<int>(result.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (stageBefore.present) {
      map['stage_before'] = Variable<int>(stageBefore.value);
    }
    if (intervalDaysAfter.present) {
      map['interval_days_after'] = Variable<int>(intervalDaysAfter.value);
    }
    if (algoVersion.present) {
      map['algo_version'] = Variable<int>(algoVersion.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (causalOrder.present) {
      map['causal_order'] = Variable<int>(causalOrder.value);
    }
    if (dayStartUtc.present) {
      map['day_start_utc'] = Variable<int>(dayStartUtc.value);
    }
    if (dayStartSource.present) {
      map['day_start_source'] = Variable<String>(dayStartSource.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewEventsCompanion(')
          ..write('id: $id, ')
          ..write('wordId: $wordId, ')
          ..write('deviceId: $deviceId, ')
          ..write('answeredAt: $answeredAt, ')
          ..write('localDay: $localDay, ')
          ..write('result: $result, ')
          ..write('type: $type, ')
          ..write('stageBefore: $stageBefore, ')
          ..write('intervalDaysAfter: $intervalDaysAfter, ')
          ..write('algoVersion: $algoVersion, ')
          ..write('mode: $mode, ')
          ..write('causalOrder: $causalOrder, ')
          ..write('dayStartUtc: $dayStartUtc, ')
          ..write('dayStartSource: $dayStartSource, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudySettingsTable extends StudySettings
    with TableInfo<$StudySettingsTable, StudySettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudySettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _dailyNewTargetMeta = const VerificationMeta(
    'dailyNewTarget',
  );
  @override
  late final GeneratedColumn<int> dailyNewTarget = GeneratedColumn<int>(
    'daily_new_target',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(30),
  );
  static const VerificationMeta _dailyReviewLimitMeta = const VerificationMeta(
    'dailyReviewLimit',
  );
  @override
  late final GeneratedColumn<int> dailyReviewLimit = GeneratedColumn<int>(
    'daily_review_limit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _currentWordBookIdMeta = const VerificationMeta(
    'currentWordBookId',
  );
  @override
  late final GeneratedColumn<String> currentWordBookId =
      GeneratedColumn<String>(
        'current_word_book_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _studyModeMeta = const VerificationMeta(
    'studyMode',
  );
  @override
  late final GeneratedColumn<String> studyMode = GeneratedColumn<String>(
    'study_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('mixed'),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _accentColorMeta = const VerificationMeta(
    'accentColor',
  );
  @override
  late final GeneratedColumn<String> accentColor = GeneratedColumn<String>(
    'accent_color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#1565C0'),
  );
  static const VerificationMeta _ttsVoiceMeta = const VerificationMeta(
    'ttsVoice',
  );
  @override
  late final GeneratedColumn<String> ttsVoice = GeneratedColumn<String>(
    'tts_voice',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _ttsLocaleMeta = const VerificationMeta(
    'ttsLocale',
  );
  @override
  late final GeneratedColumn<String> ttsLocale = GeneratedColumn<String>(
    'tts_locale',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en-US'),
  );
  static const VerificationMeta _ttsRateMeta = const VerificationMeta(
    'ttsRate',
  );
  @override
  late final GeneratedColumn<int> ttsRate = GeneratedColumn<int>(
    'tts_rate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(50),
  );
  static const VerificationMeta _ttsAutoSpeakMeta = const VerificationMeta(
    'ttsAutoSpeak',
  );
  @override
  late final GeneratedColumn<bool> ttsAutoSpeak = GeneratedColumn<bool>(
    'tts_auto_speak',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tts_auto_speak" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dailyNewTarget,
    dailyReviewLimit,
    currentWordBookId,
    studyMode,
    themeMode,
    accentColor,
    ttsVoice,
    ttsLocale,
    ttsRate,
    ttsAutoSpeak,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudySettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('daily_new_target')) {
      context.handle(
        _dailyNewTargetMeta,
        dailyNewTarget.isAcceptableOrUnknown(
          data['daily_new_target']!,
          _dailyNewTargetMeta,
        ),
      );
    }
    if (data.containsKey('daily_review_limit')) {
      context.handle(
        _dailyReviewLimitMeta,
        dailyReviewLimit.isAcceptableOrUnknown(
          data['daily_review_limit']!,
          _dailyReviewLimitMeta,
        ),
      );
    }
    if (data.containsKey('current_word_book_id')) {
      context.handle(
        _currentWordBookIdMeta,
        currentWordBookId.isAcceptableOrUnknown(
          data['current_word_book_id']!,
          _currentWordBookIdMeta,
        ),
      );
    }
    if (data.containsKey('study_mode')) {
      context.handle(
        _studyModeMeta,
        studyMode.isAcceptableOrUnknown(data['study_mode']!, _studyModeMeta),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('accent_color')) {
      context.handle(
        _accentColorMeta,
        accentColor.isAcceptableOrUnknown(
          data['accent_color']!,
          _accentColorMeta,
        ),
      );
    }
    if (data.containsKey('tts_voice')) {
      context.handle(
        _ttsVoiceMeta,
        ttsVoice.isAcceptableOrUnknown(data['tts_voice']!, _ttsVoiceMeta),
      );
    }
    if (data.containsKey('tts_locale')) {
      context.handle(
        _ttsLocaleMeta,
        ttsLocale.isAcceptableOrUnknown(data['tts_locale']!, _ttsLocaleMeta),
      );
    }
    if (data.containsKey('tts_rate')) {
      context.handle(
        _ttsRateMeta,
        ttsRate.isAcceptableOrUnknown(data['tts_rate']!, _ttsRateMeta),
      );
    }
    if (data.containsKey('tts_auto_speak')) {
      context.handle(
        _ttsAutoSpeakMeta,
        ttsAutoSpeak.isAcceptableOrUnknown(
          data['tts_auto_speak']!,
          _ttsAutoSpeakMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudySettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudySettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dailyNewTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_new_target'],
      )!,
      dailyReviewLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_review_limit'],
      )!,
      currentWordBookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_word_book_id'],
      ),
      studyMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}study_mode'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      accentColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accent_color'],
      )!,
      ttsVoice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tts_voice'],
      )!,
      ttsLocale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tts_locale'],
      )!,
      ttsRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tts_rate'],
      )!,
      ttsAutoSpeak: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tts_auto_speak'],
      )!,
    );
  }

  @override
  $StudySettingsTable createAlias(String alias) {
    return $StudySettingsTable(attachedDatabase, alias);
  }
}

class StudySettingsRow extends DataClass
    implements Insertable<StudySettingsRow> {
  final int id;
  final int dailyNewTarget;
  final int dailyReviewLimit;
  final String? currentWordBookId;
  final String studyMode;
  final String themeMode;
  final String accentColor;
  final String ttsVoice;
  final String ttsLocale;
  final int ttsRate;
  final bool ttsAutoSpeak;
  const StudySettingsRow({
    required this.id,
    required this.dailyNewTarget,
    required this.dailyReviewLimit,
    this.currentWordBookId,
    required this.studyMode,
    required this.themeMode,
    required this.accentColor,
    required this.ttsVoice,
    required this.ttsLocale,
    required this.ttsRate,
    required this.ttsAutoSpeak,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['daily_new_target'] = Variable<int>(dailyNewTarget);
    map['daily_review_limit'] = Variable<int>(dailyReviewLimit);
    if (!nullToAbsent || currentWordBookId != null) {
      map['current_word_book_id'] = Variable<String>(currentWordBookId);
    }
    map['study_mode'] = Variable<String>(studyMode);
    map['theme_mode'] = Variable<String>(themeMode);
    map['accent_color'] = Variable<String>(accentColor);
    map['tts_voice'] = Variable<String>(ttsVoice);
    map['tts_locale'] = Variable<String>(ttsLocale);
    map['tts_rate'] = Variable<int>(ttsRate);
    map['tts_auto_speak'] = Variable<bool>(ttsAutoSpeak);
    return map;
  }

  StudySettingsCompanion toCompanion(bool nullToAbsent) {
    return StudySettingsCompanion(
      id: Value(id),
      dailyNewTarget: Value(dailyNewTarget),
      dailyReviewLimit: Value(dailyReviewLimit),
      currentWordBookId: currentWordBookId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentWordBookId),
      studyMode: Value(studyMode),
      themeMode: Value(themeMode),
      accentColor: Value(accentColor),
      ttsVoice: Value(ttsVoice),
      ttsLocale: Value(ttsLocale),
      ttsRate: Value(ttsRate),
      ttsAutoSpeak: Value(ttsAutoSpeak),
    );
  }

  factory StudySettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudySettingsRow(
      id: serializer.fromJson<int>(json['id']),
      dailyNewTarget: serializer.fromJson<int>(json['dailyNewTarget']),
      dailyReviewLimit: serializer.fromJson<int>(json['dailyReviewLimit']),
      currentWordBookId: serializer.fromJson<String?>(
        json['currentWordBookId'],
      ),
      studyMode: serializer.fromJson<String>(json['studyMode']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      accentColor: serializer.fromJson<String>(json['accentColor']),
      ttsVoice: serializer.fromJson<String>(json['ttsVoice']),
      ttsLocale: serializer.fromJson<String>(json['ttsLocale']),
      ttsRate: serializer.fromJson<int>(json['ttsRate']),
      ttsAutoSpeak: serializer.fromJson<bool>(json['ttsAutoSpeak']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dailyNewTarget': serializer.toJson<int>(dailyNewTarget),
      'dailyReviewLimit': serializer.toJson<int>(dailyReviewLimit),
      'currentWordBookId': serializer.toJson<String?>(currentWordBookId),
      'studyMode': serializer.toJson<String>(studyMode),
      'themeMode': serializer.toJson<String>(themeMode),
      'accentColor': serializer.toJson<String>(accentColor),
      'ttsVoice': serializer.toJson<String>(ttsVoice),
      'ttsLocale': serializer.toJson<String>(ttsLocale),
      'ttsRate': serializer.toJson<int>(ttsRate),
      'ttsAutoSpeak': serializer.toJson<bool>(ttsAutoSpeak),
    };
  }

  StudySettingsRow copyWith({
    int? id,
    int? dailyNewTarget,
    int? dailyReviewLimit,
    Value<String?> currentWordBookId = const Value.absent(),
    String? studyMode,
    String? themeMode,
    String? accentColor,
    String? ttsVoice,
    String? ttsLocale,
    int? ttsRate,
    bool? ttsAutoSpeak,
  }) => StudySettingsRow(
    id: id ?? this.id,
    dailyNewTarget: dailyNewTarget ?? this.dailyNewTarget,
    dailyReviewLimit: dailyReviewLimit ?? this.dailyReviewLimit,
    currentWordBookId: currentWordBookId.present
        ? currentWordBookId.value
        : this.currentWordBookId,
    studyMode: studyMode ?? this.studyMode,
    themeMode: themeMode ?? this.themeMode,
    accentColor: accentColor ?? this.accentColor,
    ttsVoice: ttsVoice ?? this.ttsVoice,
    ttsLocale: ttsLocale ?? this.ttsLocale,
    ttsRate: ttsRate ?? this.ttsRate,
    ttsAutoSpeak: ttsAutoSpeak ?? this.ttsAutoSpeak,
  );
  StudySettingsRow copyWithCompanion(StudySettingsCompanion data) {
    return StudySettingsRow(
      id: data.id.present ? data.id.value : this.id,
      dailyNewTarget: data.dailyNewTarget.present
          ? data.dailyNewTarget.value
          : this.dailyNewTarget,
      dailyReviewLimit: data.dailyReviewLimit.present
          ? data.dailyReviewLimit.value
          : this.dailyReviewLimit,
      currentWordBookId: data.currentWordBookId.present
          ? data.currentWordBookId.value
          : this.currentWordBookId,
      studyMode: data.studyMode.present ? data.studyMode.value : this.studyMode,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      accentColor: data.accentColor.present
          ? data.accentColor.value
          : this.accentColor,
      ttsVoice: data.ttsVoice.present ? data.ttsVoice.value : this.ttsVoice,
      ttsLocale: data.ttsLocale.present ? data.ttsLocale.value : this.ttsLocale,
      ttsRate: data.ttsRate.present ? data.ttsRate.value : this.ttsRate,
      ttsAutoSpeak: data.ttsAutoSpeak.present
          ? data.ttsAutoSpeak.value
          : this.ttsAutoSpeak,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudySettingsRow(')
          ..write('id: $id, ')
          ..write('dailyNewTarget: $dailyNewTarget, ')
          ..write('dailyReviewLimit: $dailyReviewLimit, ')
          ..write('currentWordBookId: $currentWordBookId, ')
          ..write('studyMode: $studyMode, ')
          ..write('themeMode: $themeMode, ')
          ..write('accentColor: $accentColor, ')
          ..write('ttsVoice: $ttsVoice, ')
          ..write('ttsLocale: $ttsLocale, ')
          ..write('ttsRate: $ttsRate, ')
          ..write('ttsAutoSpeak: $ttsAutoSpeak')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    dailyNewTarget,
    dailyReviewLimit,
    currentWordBookId,
    studyMode,
    themeMode,
    accentColor,
    ttsVoice,
    ttsLocale,
    ttsRate,
    ttsAutoSpeak,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudySettingsRow &&
          other.id == this.id &&
          other.dailyNewTarget == this.dailyNewTarget &&
          other.dailyReviewLimit == this.dailyReviewLimit &&
          other.currentWordBookId == this.currentWordBookId &&
          other.studyMode == this.studyMode &&
          other.themeMode == this.themeMode &&
          other.accentColor == this.accentColor &&
          other.ttsVoice == this.ttsVoice &&
          other.ttsLocale == this.ttsLocale &&
          other.ttsRate == this.ttsRate &&
          other.ttsAutoSpeak == this.ttsAutoSpeak);
}

class StudySettingsCompanion extends UpdateCompanion<StudySettingsRow> {
  final Value<int> id;
  final Value<int> dailyNewTarget;
  final Value<int> dailyReviewLimit;
  final Value<String?> currentWordBookId;
  final Value<String> studyMode;
  final Value<String> themeMode;
  final Value<String> accentColor;
  final Value<String> ttsVoice;
  final Value<String> ttsLocale;
  final Value<int> ttsRate;
  final Value<bool> ttsAutoSpeak;
  const StudySettingsCompanion({
    this.id = const Value.absent(),
    this.dailyNewTarget = const Value.absent(),
    this.dailyReviewLimit = const Value.absent(),
    this.currentWordBookId = const Value.absent(),
    this.studyMode = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.accentColor = const Value.absent(),
    this.ttsVoice = const Value.absent(),
    this.ttsLocale = const Value.absent(),
    this.ttsRate = const Value.absent(),
    this.ttsAutoSpeak = const Value.absent(),
  });
  StudySettingsCompanion.insert({
    this.id = const Value.absent(),
    this.dailyNewTarget = const Value.absent(),
    this.dailyReviewLimit = const Value.absent(),
    this.currentWordBookId = const Value.absent(),
    this.studyMode = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.accentColor = const Value.absent(),
    this.ttsVoice = const Value.absent(),
    this.ttsLocale = const Value.absent(),
    this.ttsRate = const Value.absent(),
    this.ttsAutoSpeak = const Value.absent(),
  });
  static Insertable<StudySettingsRow> custom({
    Expression<int>? id,
    Expression<int>? dailyNewTarget,
    Expression<int>? dailyReviewLimit,
    Expression<String>? currentWordBookId,
    Expression<String>? studyMode,
    Expression<String>? themeMode,
    Expression<String>? accentColor,
    Expression<String>? ttsVoice,
    Expression<String>? ttsLocale,
    Expression<int>? ttsRate,
    Expression<bool>? ttsAutoSpeak,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dailyNewTarget != null) 'daily_new_target': dailyNewTarget,
      if (dailyReviewLimit != null) 'daily_review_limit': dailyReviewLimit,
      if (currentWordBookId != null) 'current_word_book_id': currentWordBookId,
      if (studyMode != null) 'study_mode': studyMode,
      if (themeMode != null) 'theme_mode': themeMode,
      if (accentColor != null) 'accent_color': accentColor,
      if (ttsVoice != null) 'tts_voice': ttsVoice,
      if (ttsLocale != null) 'tts_locale': ttsLocale,
      if (ttsRate != null) 'tts_rate': ttsRate,
      if (ttsAutoSpeak != null) 'tts_auto_speak': ttsAutoSpeak,
    });
  }

  StudySettingsCompanion copyWith({
    Value<int>? id,
    Value<int>? dailyNewTarget,
    Value<int>? dailyReviewLimit,
    Value<String?>? currentWordBookId,
    Value<String>? studyMode,
    Value<String>? themeMode,
    Value<String>? accentColor,
    Value<String>? ttsVoice,
    Value<String>? ttsLocale,
    Value<int>? ttsRate,
    Value<bool>? ttsAutoSpeak,
  }) {
    return StudySettingsCompanion(
      id: id ?? this.id,
      dailyNewTarget: dailyNewTarget ?? this.dailyNewTarget,
      dailyReviewLimit: dailyReviewLimit ?? this.dailyReviewLimit,
      currentWordBookId: currentWordBookId ?? this.currentWordBookId,
      studyMode: studyMode ?? this.studyMode,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      ttsLocale: ttsLocale ?? this.ttsLocale,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsAutoSpeak: ttsAutoSpeak ?? this.ttsAutoSpeak,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dailyNewTarget.present) {
      map['daily_new_target'] = Variable<int>(dailyNewTarget.value);
    }
    if (dailyReviewLimit.present) {
      map['daily_review_limit'] = Variable<int>(dailyReviewLimit.value);
    }
    if (currentWordBookId.present) {
      map['current_word_book_id'] = Variable<String>(currentWordBookId.value);
    }
    if (studyMode.present) {
      map['study_mode'] = Variable<String>(studyMode.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (accentColor.present) {
      map['accent_color'] = Variable<String>(accentColor.value);
    }
    if (ttsVoice.present) {
      map['tts_voice'] = Variable<String>(ttsVoice.value);
    }
    if (ttsLocale.present) {
      map['tts_locale'] = Variable<String>(ttsLocale.value);
    }
    if (ttsRate.present) {
      map['tts_rate'] = Variable<int>(ttsRate.value);
    }
    if (ttsAutoSpeak.present) {
      map['tts_auto_speak'] = Variable<bool>(ttsAutoSpeak.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudySettingsCompanion(')
          ..write('id: $id, ')
          ..write('dailyNewTarget: $dailyNewTarget, ')
          ..write('dailyReviewLimit: $dailyReviewLimit, ')
          ..write('currentWordBookId: $currentWordBookId, ')
          ..write('studyMode: $studyMode, ')
          ..write('themeMode: $themeMode, ')
          ..write('accentColor: $accentColor, ')
          ..write('ttsVoice: $ttsVoice, ')
          ..write('ttsLocale: $ttsLocale, ')
          ..write('ttsRate: $ttsRate, ')
          ..write('ttsAutoSpeak: $ttsAutoSpeak')
          ..write(')'))
        .toString();
  }
}

class $AppMetaTable extends AppMeta with TableInfo<$AppMetaTable, AppMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppMetaTable createAlias(String alias) {
    return $AppMetaTable(attachedDatabase, alias);
  }
}

class AppMetaRow extends DataClass implements Insertable<AppMetaRow> {
  final String key;
  final String value;
  const AppMetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetaCompanion toCompanion(bool nullToAbsent) {
    return AppMetaCompanion(key: Value(key), value: Value(value));
  }

  factory AppMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppMetaRow copyWith({String? key, String? value}) =>
      AppMetaRow(key: key ?? this.key, value: value ?? this.value);
  AppMetaRow copyWithCompanion(AppMetaCompanion data) {
    return AppMetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetaRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppMetaCompanion extends UpdateCompanion<AppMetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppMetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WordFavoritesTable extends WordFavorites
    with TableInfo<$WordFavoritesTable, FavoriteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordFavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES words (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<bool> value = GeneratedColumn<bool>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("value" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [
    wordId,
    value,
    version,
    updatedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_id')) {
      context.handle(
        _wordIdMeta,
        wordId.isAcceptableOrUnknown(data['word_id']!, _wordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIdMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordId};
  @override
  FavoriteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteRow(
      wordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}value'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $WordFavoritesTable createAlias(String alias) {
    return $WordFavoritesTable(attachedDatabase, alias);
  }
}

class FavoriteRow extends DataClass implements Insertable<FavoriteRow> {
  final String wordId;
  final bool value;
  final int version;
  final int updatedAt;
  final String deviceId;
  const FavoriteRow({
    required this.wordId,
    required this.value,
    required this.version,
    required this.updatedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_id'] = Variable<String>(wordId);
    map['value'] = Variable<bool>(value);
    map['version'] = Variable<int>(version);
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  WordFavoritesCompanion toCompanion(bool nullToAbsent) {
    return WordFavoritesCompanion(
      wordId: Value(wordId),
      value: Value(value),
      version: Value(version),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
    );
  }

  factory FavoriteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteRow(
      wordId: serializer.fromJson<String>(json['wordId']),
      value: serializer.fromJson<bool>(json['value']),
      version: serializer.fromJson<int>(json['version']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordId': serializer.toJson<String>(wordId),
      'value': serializer.toJson<bool>(value),
      'version': serializer.toJson<int>(version),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  FavoriteRow copyWith({
    String? wordId,
    bool? value,
    int? version,
    int? updatedAt,
    String? deviceId,
  }) => FavoriteRow(
    wordId: wordId ?? this.wordId,
    value: value ?? this.value,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  FavoriteRow copyWithCompanion(WordFavoritesCompanion data) {
    return FavoriteRow(
      wordId: data.wordId.present ? data.wordId.value : this.wordId,
      value: data.value.present ? data.value.value : this.value,
      version: data.version.present ? data.version.value : this.version,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteRow(')
          ..write('wordId: $wordId, ')
          ..write('value: $value, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(wordId, value, version, updatedAt, deviceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteRow &&
          other.wordId == this.wordId &&
          other.value == this.value &&
          other.version == this.version &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId);
}

class WordFavoritesCompanion extends UpdateCompanion<FavoriteRow> {
  final Value<String> wordId;
  final Value<bool> value;
  final Value<int> version;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const WordFavoritesCompanion({
    this.wordId = const Value.absent(),
    this.value = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordFavoritesCompanion.insert({
    required String wordId,
    this.value = const Value.absent(),
    this.version = const Value.absent(),
    required int updatedAt,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : wordId = Value(wordId),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<FavoriteRow> custom({
    Expression<String>? wordId,
    Expression<bool>? value,
    Expression<int>? version,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordId != null) 'word_id': wordId,
      if (value != null) 'value': value,
      if (version != null) 'version': version,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordFavoritesCompanion copyWith({
    Value<String>? wordId,
    Value<bool>? value,
    Value<int>? version,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return WordFavoritesCompanion(
      wordId: wordId ?? this.wordId,
      value: value ?? this.value,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordId.present) {
      map['word_id'] = Variable<String>(wordId.value);
    }
    if (value.present) {
      map['value'] = Variable<bool>(value.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordFavoritesCompanion(')
          ..write('wordId: $wordId, ')
          ..write('value: $value, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserTagsTable extends UserTags with TableInfo<$UserTagsTable, UserTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserTagsTable(this.attachedDatabase, [this._alias]);
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedMeta = const VerificationMeta(
    'normalized',
  );
  @override
  late final GeneratedColumn<String> normalized = GeneratedColumn<String>(
    'normalized',
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
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    normalized,
    version,
    updatedAt,
    deviceId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserTag> instance, {
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
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized')) {
      context.handle(
        _normalizedMeta,
        normalized.isAcceptableOrUnknown(data['normalized']!, _normalizedMeta),
      );
    } else if (isInserting) {
      context.missing(_normalizedMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserTag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $UserTagsTable createAlias(String alias) {
    return $UserTagsTable(attachedDatabase, alias);
  }
}

class UserTag extends DataClass implements Insertable<UserTag> {
  final String id;
  final String name;
  final String normalized;
  final int version;
  final int updatedAt;
  final String deviceId;
  final int? deletedAt;
  const UserTag({
    required this.id,
    required this.name,
    required this.normalized,
    required this.version,
    required this.updatedAt,
    required this.deviceId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['normalized'] = Variable<String>(normalized);
    map['version'] = Variable<int>(version);
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  UserTagsCompanion toCompanion(bool nullToAbsent) {
    return UserTagsCompanion(
      id: Value(id),
      name: Value(name),
      normalized: Value(normalized),
      version: Value(version),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory UserTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserTag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalized: serializer.fromJson<String>(json['normalized']),
      version: serializer.fromJson<int>(json['version']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'normalized': serializer.toJson<String>(normalized),
      'version': serializer.toJson<int>(version),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  UserTag copyWith({
    String? id,
    String? name,
    String? normalized,
    int? version,
    int? updatedAt,
    String? deviceId,
    Value<int?> deletedAt = const Value.absent(),
  }) => UserTag(
    id: id ?? this.id,
    name: name ?? this.name,
    normalized: normalized ?? this.normalized,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  UserTag copyWithCompanion(UserTagsCompanion data) {
    return UserTag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalized: data.normalized.present
          ? data.normalized.value
          : this.normalized,
      version: data.version.present ? data.version.value : this.version,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserTag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalized: $normalized, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    normalized,
    version,
    updatedAt,
    deviceId,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserTag &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalized == this.normalized &&
          other.version == this.version &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deletedAt == this.deletedAt);
}

class UserTagsCompanion extends UpdateCompanion<UserTag> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> normalized;
  final Value<int> version;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const UserTagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalized = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserTagsCompanion.insert({
    required String id,
    required String name,
    required String normalized,
    this.version = const Value.absent(),
    required int updatedAt,
    required String deviceId,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       normalized = Value(normalized),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<UserTag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? normalized,
    Expression<int>? version,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalized != null) 'normalized': normalized,
      if (version != null) 'version': version,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserTagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? normalized,
    Value<int>? version,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return UserTagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalized: normalized ?? this.normalized,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (normalized.present) {
      map['normalized'] = Variable<String>(normalized.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserTagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalized: $normalized, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WordTagsTable extends WordTags with TableInfo<$WordTagsTable, WordTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES words (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_tags (id) ON DELETE CASCADE',
    ),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    wordId,
    tagId,
    version,
    updatedAt,
    deviceId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_id')) {
      context.handle(
        _wordIdMeta,
        wordId.isAcceptableOrUnknown(data['word_id']!, _wordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordId, tagId};
  @override
  WordTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordTag(
      wordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $WordTagsTable createAlias(String alias) {
    return $WordTagsTable(attachedDatabase, alias);
  }
}

class WordTag extends DataClass implements Insertable<WordTag> {
  final String wordId;
  final String tagId;
  final int version;
  final int updatedAt;
  final String deviceId;
  final int? deletedAt;
  const WordTag({
    required this.wordId,
    required this.tagId,
    required this.version,
    required this.updatedAt,
    required this.deviceId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_id'] = Variable<String>(wordId);
    map['tag_id'] = Variable<String>(tagId);
    map['version'] = Variable<int>(version);
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  WordTagsCompanion toCompanion(bool nullToAbsent) {
    return WordTagsCompanion(
      wordId: Value(wordId),
      tagId: Value(tagId),
      version: Value(version),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory WordTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordTag(
      wordId: serializer.fromJson<String>(json['wordId']),
      tagId: serializer.fromJson<String>(json['tagId']),
      version: serializer.fromJson<int>(json['version']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordId': serializer.toJson<String>(wordId),
      'tagId': serializer.toJson<String>(tagId),
      'version': serializer.toJson<int>(version),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  WordTag copyWith({
    String? wordId,
    String? tagId,
    int? version,
    int? updatedAt,
    String? deviceId,
    Value<int?> deletedAt = const Value.absent(),
  }) => WordTag(
    wordId: wordId ?? this.wordId,
    tagId: tagId ?? this.tagId,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  WordTag copyWithCompanion(WordTagsCompanion data) {
    return WordTag(
      wordId: data.wordId.present ? data.wordId.value : this.wordId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      version: data.version.present ? data.version.value : this.version,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordTag(')
          ..write('wordId: $wordId, ')
          ..write('tagId: $tagId, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(wordId, tagId, version, updatedAt, deviceId, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordTag &&
          other.wordId == this.wordId &&
          other.tagId == this.tagId &&
          other.version == this.version &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deletedAt == this.deletedAt);
}

class WordTagsCompanion extends UpdateCompanion<WordTag> {
  final Value<String> wordId;
  final Value<String> tagId;
  final Value<int> version;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const WordTagsCompanion({
    this.wordId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordTagsCompanion.insert({
    required String wordId,
    required String tagId,
    this.version = const Value.absent(),
    required int updatedAt,
    required String deviceId,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : wordId = Value(wordId),
       tagId = Value(tagId),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<WordTag> custom({
    Expression<String>? wordId,
    Expression<String>? tagId,
    Expression<int>? version,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordId != null) 'word_id': wordId,
      if (tagId != null) 'tag_id': tagId,
      if (version != null) 'version': version,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordTagsCompanion copyWith({
    Value<String>? wordId,
    Value<String>? tagId,
    Value<int>? version,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return WordTagsCompanion(
      wordId: wordId ?? this.wordId,
      tagId: tagId ?? this.tagId,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordId.present) {
      map['word_id'] = Variable<String>(wordId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordTagsCompanion(')
          ..write('wordId: $wordId, ')
          ..write('tagId: $tagId, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncAliasesTable extends SyncAliases
    with TableInfo<$SyncAliasesTable, SyncAliasRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncAliasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aliasIdMeta = const VerificationMeta(
    'aliasId',
  );
  @override
  late final GeneratedColumn<String> aliasId = GeneratedColumn<String>(
    'alias_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [kind, aliasId, localId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_aliases';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncAliasRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('alias_id')) {
      context.handle(
        _aliasIdMeta,
        aliasId.isAcceptableOrUnknown(data['alias_id']!, _aliasIdMeta),
      );
    } else if (isInserting) {
      context.missing(_aliasIdMeta);
    }
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, aliasId};
  @override
  SyncAliasRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncAliasRow(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      aliasId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias_id'],
      )!,
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
    );
  }

  @override
  $SyncAliasesTable createAlias(String alias) {
    return $SyncAliasesTable(attachedDatabase, alias);
  }
}

class SyncAliasRow extends DataClass implements Insertable<SyncAliasRow> {
  final String kind;
  final String aliasId;
  final String localId;
  const SyncAliasRow({
    required this.kind,
    required this.aliasId,
    required this.localId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['alias_id'] = Variable<String>(aliasId);
    map['local_id'] = Variable<String>(localId);
    return map;
  }

  SyncAliasesCompanion toCompanion(bool nullToAbsent) {
    return SyncAliasesCompanion(
      kind: Value(kind),
      aliasId: Value(aliasId),
      localId: Value(localId),
    );
  }

  factory SyncAliasRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncAliasRow(
      kind: serializer.fromJson<String>(json['kind']),
      aliasId: serializer.fromJson<String>(json['aliasId']),
      localId: serializer.fromJson<String>(json['localId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'aliasId': serializer.toJson<String>(aliasId),
      'localId': serializer.toJson<String>(localId),
    };
  }

  SyncAliasRow copyWith({String? kind, String? aliasId, String? localId}) =>
      SyncAliasRow(
        kind: kind ?? this.kind,
        aliasId: aliasId ?? this.aliasId,
        localId: localId ?? this.localId,
      );
  SyncAliasRow copyWithCompanion(SyncAliasesCompanion data) {
    return SyncAliasRow(
      kind: data.kind.present ? data.kind.value : this.kind,
      aliasId: data.aliasId.present ? data.aliasId.value : this.aliasId,
      localId: data.localId.present ? data.localId.value : this.localId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncAliasRow(')
          ..write('kind: $kind, ')
          ..write('aliasId: $aliasId, ')
          ..write('localId: $localId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, aliasId, localId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncAliasRow &&
          other.kind == this.kind &&
          other.aliasId == this.aliasId &&
          other.localId == this.localId);
}

class SyncAliasesCompanion extends UpdateCompanion<SyncAliasRow> {
  final Value<String> kind;
  final Value<String> aliasId;
  final Value<String> localId;
  final Value<int> rowid;
  const SyncAliasesCompanion({
    this.kind = const Value.absent(),
    this.aliasId = const Value.absent(),
    this.localId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncAliasesCompanion.insert({
    required String kind,
    required String aliasId,
    required String localId,
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       aliasId = Value(aliasId),
       localId = Value(localId);
  static Insertable<SyncAliasRow> custom({
    Expression<String>? kind,
    Expression<String>? aliasId,
    Expression<String>? localId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (aliasId != null) 'alias_id': aliasId,
      if (localId != null) 'local_id': localId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncAliasesCompanion copyWith({
    Value<String>? kind,
    Value<String>? aliasId,
    Value<String>? localId,
    Value<int>? rowid,
  }) {
    return SyncAliasesCompanion(
      kind: kind ?? this.kind,
      aliasId: aliasId ?? this.aliasId,
      localId: localId ?? this.localId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (aliasId.present) {
      map['alias_id'] = Variable<String>(aliasId.value);
    }
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncAliasesCompanion(')
          ..write('kind: $kind, ')
          ..write('aliasId: $aliasId, ')
          ..write('localId: $localId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentVersionsTable extends ContentVersions
    with TableInfo<$ContentVersionsTable, ContentVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
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
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [
    kind,
    entityId,
    field,
    version,
    updatedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentVersionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('field')) {
      context.handle(
        _fieldMeta,
        field.isAcceptableOrUnknown(data['field']!, _fieldMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, entityId, field};
  @override
  ContentVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentVersionRow(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      field: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $ContentVersionsTable createAlias(String alias) {
    return $ContentVersionsTable(attachedDatabase, alias);
  }
}

class ContentVersionRow extends DataClass
    implements Insertable<ContentVersionRow> {
  final String kind;
  final String entityId;
  final String field;
  final int version;
  final int updatedAt;
  final String deviceId;
  const ContentVersionRow({
    required this.kind,
    required this.entityId,
    required this.field,
    required this.version,
    required this.updatedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['entity_id'] = Variable<String>(entityId);
    map['field'] = Variable<String>(field);
    map['version'] = Variable<int>(version);
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  ContentVersionsCompanion toCompanion(bool nullToAbsent) {
    return ContentVersionsCompanion(
      kind: Value(kind),
      entityId: Value(entityId),
      field: Value(field),
      version: Value(version),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
    );
  }

  factory ContentVersionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentVersionRow(
      kind: serializer.fromJson<String>(json['kind']),
      entityId: serializer.fromJson<String>(json['entityId']),
      field: serializer.fromJson<String>(json['field']),
      version: serializer.fromJson<int>(json['version']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'entityId': serializer.toJson<String>(entityId),
      'field': serializer.toJson<String>(field),
      'version': serializer.toJson<int>(version),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  ContentVersionRow copyWith({
    String? kind,
    String? entityId,
    String? field,
    int? version,
    int? updatedAt,
    String? deviceId,
  }) => ContentVersionRow(
    kind: kind ?? this.kind,
    entityId: entityId ?? this.entityId,
    field: field ?? this.field,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  ContentVersionRow copyWithCompanion(ContentVersionsCompanion data) {
    return ContentVersionRow(
      kind: data.kind.present ? data.kind.value : this.kind,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      field: data.field.present ? data.field.value : this.field,
      version: data.version.present ? data.version.value : this.version,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentVersionRow(')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('field: $field, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(kind, entityId, field, version, updatedAt, deviceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentVersionRow &&
          other.kind == this.kind &&
          other.entityId == this.entityId &&
          other.field == this.field &&
          other.version == this.version &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId);
}

class ContentVersionsCompanion extends UpdateCompanion<ContentVersionRow> {
  final Value<String> kind;
  final Value<String> entityId;
  final Value<String> field;
  final Value<int> version;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const ContentVersionsCompanion({
    this.kind = const Value.absent(),
    this.entityId = const Value.absent(),
    this.field = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentVersionsCompanion.insert({
    required String kind,
    required String entityId,
    required String field,
    required int version,
    required int updatedAt,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       entityId = Value(entityId),
       field = Value(field),
       version = Value(version),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<ContentVersionRow> custom({
    Expression<String>? kind,
    Expression<String>? entityId,
    Expression<String>? field,
    Expression<int>? version,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (entityId != null) 'entity_id': entityId,
      if (field != null) 'field': field,
      if (version != null) 'version': version,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentVersionsCompanion copyWith({
    Value<String>? kind,
    Value<String>? entityId,
    Value<String>? field,
    Value<int>? version,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return ContentVersionsCompanion(
      kind: kind ?? this.kind,
      entityId: entityId ?? this.entityId,
      field: field ?? this.field,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentVersionsCompanion(')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('field: $field, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WordsTable words = $WordsTable(this);
  late final $WordBooksTable wordBooks = $WordBooksTable(this);
  late final $WordBookEntriesTable wordBookEntries = $WordBookEntriesTable(
    this,
  );
  late final $LearningStatesTable learningStates = $LearningStatesTable(this);
  late final $ReviewEventsTable reviewEvents = $ReviewEventsTable(this);
  late final $StudySettingsTable studySettings = $StudySettingsTable(this);
  late final $AppMetaTable appMeta = $AppMetaTable(this);
  late final $WordFavoritesTable wordFavorites = $WordFavoritesTable(this);
  late final $UserTagsTable userTags = $UserTagsTable(this);
  late final $WordTagsTable wordTags = $WordTagsTable(this);
  late final $SyncAliasesTable syncAliases = $SyncAliasesTable(this);
  late final $ContentVersionsTable contentVersions = $ContentVersionsTable(
    this,
  );
  late final Index idxWordsNormalized = Index(
    'idx_words_normalized',
    'CREATE UNIQUE INDEX idx_words_normalized ON words (normalized)',
  );
  late final Index idxWordbooksDeleted = Index(
    'idx_wordbooks_deleted',
    'CREATE INDEX idx_wordbooks_deleted ON word_books (deleted_at)',
  );
  late final Index idxEntriesWord = Index(
    'idx_entries_word',
    'CREATE INDEX idx_entries_word ON word_book_entries (word_id)',
  );
  late final Index idxEntriesBook = Index(
    'idx_entries_book',
    'CREATE INDEX idx_entries_book ON word_book_entries (word_book_id, deleted_at)',
  );
  late final Index idxLearningDue = Index(
    'idx_learning_due',
    'CREATE INDEX idx_learning_due ON learning_states (next_review_at)',
  );
  late final Index idxLearningStage = Index(
    'idx_learning_stage',
    'CREATE INDEX idx_learning_stage ON learning_states (stage)',
  );
  late final Index idxEventsWordTime = Index(
    'idx_events_word_time',
    'CREATE INDEX idx_events_word_time ON review_events (word_id, answered_at)',
  );
  late final Index idxEventsDay = Index(
    'idx_events_day',
    'CREATE INDEX idx_events_day ON review_events (local_day, type)',
  );
  late final Index idxSettingsId = Index(
    'idx_settings_id',
    'CREATE INDEX idx_settings_id ON study_settings (id)',
  );
  late final Index idxTagsName = Index(
    'idx_tags_name',
    'CREATE INDEX idx_tags_name ON user_tags (normalized)',
  );
  late final Index idxWordTagsWord = Index(
    'idx_word_tags_word',
    'CREATE INDEX idx_word_tags_word ON word_tags (word_id, deleted_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    words,
    wordBooks,
    wordBookEntries,
    learningStates,
    reviewEvents,
    studySettings,
    appMeta,
    wordFavorites,
    userTags,
    wordTags,
    syncAliases,
    contentVersions,
    idxWordsNormalized,
    idxWordbooksDeleted,
    idxEntriesWord,
    idxEntriesBook,
    idxLearningDue,
    idxLearningStage,
    idxEventsWordTime,
    idxEventsDay,
    idxSettingsId,
    idxTagsName,
    idxWordTagsWord,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'word_books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('word_book_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'words',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('word_book_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'words',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('learning_states', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'words',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('review_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'words',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('word_favorites', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'words',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('word_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'user_tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('word_tags', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$WordsTableCreateCompanionBuilder = WordsCompanion Function({
  required String id,
  required String word,
  required String normalized,
  Value<String> phonetic,
  Value<String> partOfSpeech,
  Value<String> translation,
  Value<String> definition,
  Value<String> example,
  Value<String> phrase,
  Value<String> note,
  Value<String> source,
  Value<String> examTags,
  Value<int> bncRank,
  Value<int> frqRank,
  Value<bool> customized,
  Value<int> revision,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$WordsTableUpdateCompanionBuilder = WordsCompanion Function({
  Value<String> id,
  Value<String> word,
  Value<String> normalized,
  Value<String> phonetic,
  Value<String> partOfSpeech,
  Value<String> translation,
  Value<String> definition,
  Value<String> example,
  Value<String> phrase,
  Value<String> note,
  Value<String> source,
  Value<String> examTags,
  Value<int> bncRank,
  Value<int> frqRank,
  Value<bool> customized,
  Value<int> revision,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});

final class $$WordsTableReferences
    extends BaseReferences<_$AppDatabase, $WordsTable, Word> {
  $$WordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WordBookEntriesTable, List<WordBookEntry>>
  _wordBookEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.wordBookEntries,
    aliasName: 'words__id__word_book_entries__word_id',
  );

  $$WordBookEntriesTableProcessedTableManager get wordBookEntriesRefs {
    final manager = $$WordBookEntriesTableTableManager(
      $_db,
      $_db.wordBookEntries,
    ).filter((f) => f.wordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _wordBookEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LearningStatesTable, List<LearningState>>
  _learningStatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.learningStates,
    aliasName: 'words__id__learning_states__word_id',
  );

  $$LearningStatesTableProcessedTableManager get learningStatesRefs {
    final manager = $$LearningStatesTableTableManager(
      $_db,
      $_db.learningStates,
    ).filter((f) => f.wordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_learningStatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReviewEventsTable, List<ReviewEvent>>
  _reviewEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reviewEvents,
    aliasName: 'words__id__review_events__word_id',
  );

  $$ReviewEventsTableProcessedTableManager get reviewEventsRefs {
    final manager = $$ReviewEventsTableTableManager(
      $_db,
      $_db.reviewEvents,
    ).filter((f) => f.wordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_reviewEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WordFavoritesTable, List<FavoriteRow>>
  _wordFavoritesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.wordFavorites,
    aliasName: 'words__id__word_favorites__word_id',
  );

  $$WordFavoritesTableProcessedTableManager get wordFavoritesRefs {
    final manager = $$WordFavoritesTableTableManager(
      $_db,
      $_db.wordFavorites,
    ).filter((f) => f.wordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_wordFavoritesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WordTagsTable, List<WordTag>> _wordTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.wordTags,
    aliasName: 'words__id__word_tags__word_id',
  );

  $$WordTagsTableProcessedTableManager get wordTagsRefs {
    final manager = $$WordTagsTableTableManager(
      $_db,
      $_db.wordTags,
    ).filter((f) => f.wordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_wordTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WordsTableFilterComposer extends Composer<_$AppDatabase, $WordsTable> {
  $$WordsTableFilterComposer({
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

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phonetic => $composableBuilder(
    column: $table.phonetic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partOfSpeech => $composableBuilder(
    column: $table.partOfSpeech,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get example => $composableBuilder(
    column: $table.example,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phrase => $composableBuilder(
    column: $table.phrase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examTags => $composableBuilder(
    column: $table.examTags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bncRank => $composableBuilder(
    column: $table.bncRank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get frqRank => $composableBuilder(
    column: $table.frqRank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get customized => $composableBuilder(
    column: $table.customized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> wordBookEntriesRefs(
    Expression<bool> Function($$WordBookEntriesTableFilterComposer f) f,
  ) {
    final $$WordBookEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wordBookEntries,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordBookEntriesTableFilterComposer(
            $db: $db,
            $table: $db.wordBookEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learningStatesRefs(
    Expression<bool> Function($$LearningStatesTableFilterComposer f) f,
  ) {
    final $$LearningStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningStates,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningStatesTableFilterComposer(
            $db: $db,
            $table: $db.learningStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> reviewEventsRefs(
    Expression<bool> Function($$ReviewEventsTableFilterComposer f) f,
  ) {
    final $$ReviewEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewEvents,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewEventsTableFilterComposer(
            $db: $db,
            $table: $db.reviewEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> wordFavoritesRefs(
    Expression<bool> Function($$WordFavoritesTableFilterComposer f) f,
  ) {
    final $$WordFavoritesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wordFavorites,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordFavoritesTableFilterComposer(
            $db: $db,
            $table: $db.wordFavorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> wordTagsRefs(
    Expression<bool> Function($$WordTagsTableFilterComposer f) f,
  ) {
    final $$WordTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wordTags,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordTagsTableFilterComposer(
            $db: $db,
            $table: $db.wordTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WordsTableOrderingComposer
    extends Composer<_$AppDatabase, $WordsTable> {
  $$WordsTableOrderingComposer({
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

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phonetic => $composableBuilder(
    column: $table.phonetic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partOfSpeech => $composableBuilder(
    column: $table.partOfSpeech,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get example => $composableBuilder(
    column: $table.example,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phrase => $composableBuilder(
    column: $table.phrase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examTags => $composableBuilder(
    column: $table.examTags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bncRank => $composableBuilder(
    column: $table.bncRank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get frqRank => $composableBuilder(
    column: $table.frqRank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get customized => $composableBuilder(
    column: $table.customized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordsTable> {
  $$WordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phonetic =>
      $composableBuilder(column: $table.phonetic, builder: (column) => column);

  GeneratedColumn<String> get partOfSpeech => $composableBuilder(
    column: $table.partOfSpeech,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => column,
  );

  GeneratedColumn<String> get example =>
      $composableBuilder(column: $table.example, builder: (column) => column);

  GeneratedColumn<String> get phrase =>
      $composableBuilder(column: $table.phrase, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get examTags =>
      $composableBuilder(column: $table.examTags, builder: (column) => column);

  GeneratedColumn<int> get bncRank =>
      $composableBuilder(column: $table.bncRank, builder: (column) => column);

  GeneratedColumn<int> get frqRank =>
      $composableBuilder(column: $table.frqRank, builder: (column) => column);

  GeneratedColumn<bool> get customized => $composableBuilder(
    column: $table.customized,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> wordBookEntriesRefs<T extends Object>(
    Expression<T> Function($$WordBookEntriesTableAnnotationComposer a) f,
  ) {
    final $$WordBookEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wordBookEntries,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordBookEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.wordBookEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> learningStatesRefs<T extends Object>(
    Expression<T> Function($$LearningStatesTableAnnotationComposer a) f,
  ) {
    final $$LearningStatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningStates,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningStatesTableAnnotationComposer(
            $db: $db,
            $table: $db.learningStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> reviewEventsRefs<T extends Object>(
    Expression<T> Function($$ReviewEventsTableAnnotationComposer a) f,
  ) {
    final $$ReviewEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewEvents,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> wordFavoritesRefs<T extends Object>(
    Expression<T> Function($$WordFavoritesTableAnnotationComposer a) f,
  ) {
    final $$WordFavoritesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wordFavorites,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordFavoritesTableAnnotationComposer(
            $db: $db,
            $table: $db.wordFavorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> wordTagsRefs<T extends Object>(
    Expression<T> Function($$WordTagsTableAnnotationComposer a) f,
  ) {
    final $$WordTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wordTags,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.wordTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordsTable,
          Word,
          $$WordsTableFilterComposer,
          $$WordsTableOrderingComposer,
          $$WordsTableAnnotationComposer,
          $$WordsTableCreateCompanionBuilder,
          $$WordsTableUpdateCompanionBuilder,
          (Word, $$WordsTableReferences),
          Word,
          PrefetchHooks Function({
            bool wordBookEntriesRefs,
            bool learningStatesRefs,
            bool reviewEventsRefs,
            bool wordFavoritesRefs,
            bool wordTagsRefs,
          })
        > {
  $$WordsTableTableManager(_$AppDatabase db, $WordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<String> normalized = const Value.absent(),
                Value<String> phonetic = const Value.absent(),
                Value<String> partOfSpeech = const Value.absent(),
                Value<String> translation = const Value.absent(),
                Value<String> definition = const Value.absent(),
                Value<String> example = const Value.absent(),
                Value<String> phrase = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> examTags = const Value.absent(),
                Value<int> bncRank = const Value.absent(),
                Value<int> frqRank = const Value.absent(),
                Value<bool> customized = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordsCompanion(
                id: id,
                word: word,
                normalized: normalized,
                phonetic: phonetic,
                partOfSpeech: partOfSpeech,
                translation: translation,
                definition: definition,
                example: example,
                phrase: phrase,
                note: note,
                source: source,
                examTags: examTags,
                bncRank: bncRank,
                frqRank: frqRank,
                customized: customized,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String word,
                required String normalized,
                Value<String> phonetic = const Value.absent(),
                Value<String> partOfSpeech = const Value.absent(),
                Value<String> translation = const Value.absent(),
                Value<String> definition = const Value.absent(),
                Value<String> example = const Value.absent(),
                Value<String> phrase = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> examTags = const Value.absent(),
                Value<int> bncRank = const Value.absent(),
                Value<int> frqRank = const Value.absent(),
                Value<bool> customized = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordsCompanion.insert(
                id: id,
                word: word,
                normalized: normalized,
                phonetic: phonetic,
                partOfSpeech: partOfSpeech,
                translation: translation,
                definition: definition,
                example: example,
                phrase: phrase,
                note: note,
                source: source,
                examTags: examTags,
                bncRank: bncRank,
                frqRank: frqRank,
                customized: customized,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordsTable, Word>(table),
                  $$WordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                wordBookEntriesRefs = false,
                learningStatesRefs = false,
                reviewEventsRefs = false,
                wordFavoritesRefs = false,
                wordTagsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (wordBookEntriesRefs) db.wordBookEntries,
                    if (learningStatesRefs) db.learningStates,
                    if (reviewEventsRefs) db.reviewEvents,
                    if (wordFavoritesRefs) db.wordFavorites,
                    if (wordTagsRefs) db.wordTags,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (wordBookEntriesRefs)
                        await $_getPrefetchedDataByColumns<
                          Word,
                          $WordsTable,
                          WordBookEntry,
                          $WordBookEntriesTable
                        >(
                          currentTable: table,
                          referencedTable: $$WordsTableReferences
                              ._wordBookEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WordsTableReferences(
                                db,
                                table,
                                p0,
                              ).wordBookEntriesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'word_id',
                          typedResults: items,
                        ),
                      if (learningStatesRefs)
                        await $_getPrefetchedDataByColumns<
                          Word,
                          $WordsTable,
                          LearningState,
                          $LearningStatesTable
                        >(
                          currentTable: table,
                          referencedTable: $$WordsTableReferences
                              ._learningStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WordsTableReferences(
                                db,
                                table,
                                p0,
                              ).learningStatesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'word_id',
                          typedResults: items,
                        ),
                      if (reviewEventsRefs)
                        await $_getPrefetchedDataByColumns<
                          Word,
                          $WordsTable,
                          ReviewEvent,
                          $ReviewEventsTable
                        >(
                          currentTable: table,
                          referencedTable: $$WordsTableReferences
                              ._reviewEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WordsTableReferences(
                                db,
                                table,
                                p0,
                              ).reviewEventsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'word_id',
                          typedResults: items,
                        ),
                      if (wordFavoritesRefs)
                        await $_getPrefetchedDataByColumns<
                          Word,
                          $WordsTable,
                          FavoriteRow,
                          $WordFavoritesTable
                        >(
                          currentTable: table,
                          referencedTable: $$WordsTableReferences
                              ._wordFavoritesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WordsTableReferences(
                                db,
                                table,
                                p0,
                              ).wordFavoritesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'word_id',
                          typedResults: items,
                        ),
                      if (wordTagsRefs)
                        await $_getPrefetchedDataByColumns<
                          Word,
                          $WordsTable,
                          WordTag,
                          $WordTagsTable
                        >(
                          currentTable: table,
                          referencedTable: $$WordsTableReferences
                              ._wordTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WordsTableReferences(
                                db,
                                table,
                                p0,
                              ).wordTagsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'word_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordsTable,
      Word,
      $$WordsTableFilterComposer,
      $$WordsTableOrderingComposer,
      $$WordsTableAnnotationComposer,
      $$WordsTableCreateCompanionBuilder,
      $$WordsTableUpdateCompanionBuilder,
      (Word, $$WordsTableReferences),
      Word,
      PrefetchHooks Function({
        bool wordBookEntriesRefs,
        bool learningStatesRefs,
        bool reviewEventsRefs,
        bool wordFavoritesRefs,
        bool wordTagsRefs,
      })
    >;
typedef $$WordBooksTableCreateCompanionBuilder = WordBooksCompanion Function({
  required String id,
  required String name,
  Value<String> description,
  Value<String> sourceType,
  Value<String> sourceUrl,
  Value<int> revision,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$WordBooksTableUpdateCompanionBuilder = WordBooksCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> description,
  Value<String> sourceType,
  Value<String> sourceUrl,
  Value<int> revision,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});

final class $$WordBooksTableReferences
    extends BaseReferences<_$AppDatabase, $WordBooksTable, WordBook> {
  $$WordBooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WordBookEntriesTable, List<WordBookEntry>>
  _wordBookEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.wordBookEntries,
    aliasName: 'word_books__id__word_book_entries__word_book_id',
  );

  $$WordBookEntriesTableProcessedTableManager get wordBookEntriesRefs {
    final manager = $$WordBookEntriesTableTableManager(
      $_db,
      $_db.wordBookEntries,
    ).filter((f) => f.wordBookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _wordBookEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WordBooksTableFilterComposer
    extends Composer<_$AppDatabase, $WordBooksTable> {
  $$WordBooksTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> wordBookEntriesRefs(
    Expression<bool> Function($$WordBookEntriesTableFilterComposer f) f,
  ) {
    final $$WordBookEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wordBookEntries,
      getReferencedColumn: (t) => t.wordBookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordBookEntriesTableFilterComposer(
            $db: $db,
            $table: $db.wordBookEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WordBooksTableOrderingComposer
    extends Composer<_$AppDatabase, $WordBooksTable> {
  $$WordBooksTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordBooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordBooksTable> {
  $$WordBooksTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> wordBookEntriesRefs<T extends Object>(
    Expression<T> Function($$WordBookEntriesTableAnnotationComposer a) f,
  ) {
    final $$WordBookEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wordBookEntries,
      getReferencedColumn: (t) => t.wordBookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordBookEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.wordBookEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WordBooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordBooksTable,
          WordBook,
          $$WordBooksTableFilterComposer,
          $$WordBooksTableOrderingComposer,
          $$WordBooksTableAnnotationComposer,
          $$WordBooksTableCreateCompanionBuilder,
          $$WordBooksTableUpdateCompanionBuilder,
          (WordBook, $$WordBooksTableReferences),
          WordBook,
          PrefetchHooks Function({bool wordBookEntriesRefs})
        > {
  $$WordBooksTableTableManager(_$AppDatabase db, $WordBooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordBooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordBooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordBooksCompanion(
                id: id,
                name: name,
                description: description,
                sourceType: sourceType,
                sourceUrl: sourceUrl,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> description = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordBooksCompanion.insert(
                id: id,
                name: name,
                description: description,
                sourceType: sourceType,
                sourceUrl: sourceUrl,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordBooksTable, WordBook>(table),
                  $$WordBooksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wordBookEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (wordBookEntriesRefs) db.wordBookEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (wordBookEntriesRefs)
                    await $_getPrefetchedDataByColumns<
                      WordBook,
                      $WordBooksTable,
                      WordBookEntry,
                      $WordBookEntriesTable
                    >(
                      currentTable: table,
                      referencedTable: $$WordBooksTableReferences
                          ._wordBookEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WordBooksTableReferences(
                            db,
                            table,
                            p0,
                          ).wordBookEntriesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'word_book_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WordBooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordBooksTable,
      WordBook,
      $$WordBooksTableFilterComposer,
      $$WordBooksTableOrderingComposer,
      $$WordBooksTableAnnotationComposer,
      $$WordBooksTableCreateCompanionBuilder,
      $$WordBooksTableUpdateCompanionBuilder,
      (WordBook, $$WordBooksTableReferences),
      WordBook,
      PrefetchHooks Function({bool wordBookEntriesRefs})
    >;
typedef $$WordBookEntriesTableCreateCompanionBuilder =
    WordBookEntriesCompanion Function({
      required String wordBookId,
      required String wordId,
      required int addedAt,
      Value<int> version,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$WordBookEntriesTableUpdateCompanionBuilder =
    WordBookEntriesCompanion Function({
      Value<String> wordBookId,
      Value<String> wordId,
      Value<int> addedAt,
      Value<int> version,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

final class $$WordBookEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $WordBookEntriesTable, WordBookEntry> {
  $$WordBookEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WordBooksTable _wordBookIdTable(_$AppDatabase db) => db.wordBooks
      .createAlias('word_book_entries__word_book_id__word_books__id');

  $$WordBooksTableProcessedTableManager get wordBookId {
    final $_column = $_itemColumn<String>('word_book_id')!;

    final manager = $$WordBooksTableTableManager(
      $_db,
      $_db.wordBooks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wordBookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WordsTable _wordIdTable(_$AppDatabase db) =>
      db.words.createAlias('word_book_entries__word_id__words__id');

  $$WordsTableProcessedTableManager get wordId {
    final $_column = $_itemColumn<String>('word_id')!;

    final manager = $$WordsTableTableManager(
      $_db,
      $_db.words,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WordBookEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $WordBookEntriesTable> {
  $$WordBookEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WordBooksTableFilterComposer get wordBookId {
    final $$WordBooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordBookId,
      referencedTable: $db.wordBooks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordBooksTableFilterComposer(
            $db: $db,
            $table: $db.wordBooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WordsTableFilterComposer get wordId {
    final $$WordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableFilterComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WordBookEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $WordBookEntriesTable> {
  $$WordBookEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WordBooksTableOrderingComposer get wordBookId {
    final $$WordBooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordBookId,
      referencedTable: $db.wordBooks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordBooksTableOrderingComposer(
            $db: $db,
            $table: $db.wordBooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WordsTableOrderingComposer get wordId {
    final $$WordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableOrderingComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WordBookEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordBookEntriesTable> {
  $$WordBookEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$WordBooksTableAnnotationComposer get wordBookId {
    final $$WordBooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordBookId,
      referencedTable: $db.wordBooks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordBooksTableAnnotationComposer(
            $db: $db,
            $table: $db.wordBooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WordsTableAnnotationComposer get wordId {
    final $$WordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableAnnotationComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WordBookEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordBookEntriesTable,
          WordBookEntry,
          $$WordBookEntriesTableFilterComposer,
          $$WordBookEntriesTableOrderingComposer,
          $$WordBookEntriesTableAnnotationComposer,
          $$WordBookEntriesTableCreateCompanionBuilder,
          $$WordBookEntriesTableUpdateCompanionBuilder,
          (WordBookEntry, $$WordBookEntriesTableReferences),
          WordBookEntry,
          PrefetchHooks Function({bool wordBookId, bool wordId})
        > {
  $$WordBookEntriesTableTableManager(
    _$AppDatabase db,
    $WordBookEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordBookEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordBookEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordBookEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> wordBookId = const Value.absent(),
                Value<String> wordId = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordBookEntriesCompanion(
                wordBookId: wordBookId,
                wordId: wordId,
                addedAt: addedAt,
                version: version,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordBookId,
                required String wordId,
                required int addedAt,
                Value<int> version = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordBookEntriesCompanion.insert(
                wordBookId: wordBookId,
                wordId: wordId,
                addedAt: addedAt,
                version: version,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordBookEntriesTable, WordBookEntry>(table),
                  $$WordBookEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wordBookId = false, wordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (wordBookId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.wordBookId,
                        referencedTable: $$WordBookEntriesTableReferences
                            ._wordBookIdTable(db),
                        referencedColumn: $$WordBookEntriesTableReferences
                            ._wordBookIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (wordId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.wordId,
                        referencedTable: $$WordBookEntriesTableReferences
                            ._wordIdTable(db),
                        referencedColumn: $$WordBookEntriesTableReferences
                            ._wordIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WordBookEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordBookEntriesTable,
      WordBookEntry,
      $$WordBookEntriesTableFilterComposer,
      $$WordBookEntriesTableOrderingComposer,
      $$WordBookEntriesTableAnnotationComposer,
      $$WordBookEntriesTableCreateCompanionBuilder,
      $$WordBookEntriesTableUpdateCompanionBuilder,
      (WordBookEntry, $$WordBookEntriesTableReferences),
      WordBookEntry,
      PrefetchHooks Function({bool wordBookId, bool wordId})
    >;
typedef $$LearningStatesTableCreateCompanionBuilder =
    LearningStatesCompanion Function({
      required String wordId,
      Value<int> stage,
      Value<int> correctCount,
      Value<int> hazyCount,
      Value<int> wrongCount,
      Value<int> streak,
      Value<int> intervalDays,
      Value<int?> lastStudiedAt,
      Value<int?> nextReviewAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$LearningStatesTableUpdateCompanionBuilder =
    LearningStatesCompanion Function({
      Value<String> wordId,
      Value<int> stage,
      Value<int> correctCount,
      Value<int> hazyCount,
      Value<int> wrongCount,
      Value<int> streak,
      Value<int> intervalDays,
      Value<int?> lastStudiedAt,
      Value<int?> nextReviewAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$LearningStatesTableReferences
    extends BaseReferences<_$AppDatabase, $LearningStatesTable, LearningState> {
  $$LearningStatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WordsTable _wordIdTable(_$AppDatabase db) =>
      db.words.createAlias('learning_states__word_id__words__id');

  $$WordsTableProcessedTableManager get wordId {
    final $_column = $_itemColumn<String>('word_id')!;

    final manager = $$WordsTableTableManager(
      $_db,
      $_db.words,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningStatesTableFilterComposer
    extends Composer<_$AppDatabase, $LearningStatesTable> {
  $$LearningStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hazyCount => $composableBuilder(
    column: $table.hazyCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastStudiedAt => $composableBuilder(
    column: $table.lastStudiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WordsTableFilterComposer get wordId {
    final $$WordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableFilterComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $LearningStatesTable> {
  $$LearningStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hazyCount => $composableBuilder(
    column: $table.hazyCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastStudiedAt => $composableBuilder(
    column: $table.lastStudiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WordsTableOrderingComposer get wordId {
    final $$WordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableOrderingComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearningStatesTable> {
  $$LearningStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hazyCount =>
      $composableBuilder(column: $table.hazyCount, builder: (column) => column);

  GeneratedColumn<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get streak =>
      $composableBuilder(column: $table.streak, builder: (column) => column);

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastStudiedAt => $composableBuilder(
    column: $table.lastStudiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$WordsTableAnnotationComposer get wordId {
    final $$WordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableAnnotationComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearningStatesTable,
          LearningState,
          $$LearningStatesTableFilterComposer,
          $$LearningStatesTableOrderingComposer,
          $$LearningStatesTableAnnotationComposer,
          $$LearningStatesTableCreateCompanionBuilder,
          $$LearningStatesTableUpdateCompanionBuilder,
          (LearningState, $$LearningStatesTableReferences),
          LearningState,
          PrefetchHooks Function({bool wordId})
        > {
  $$LearningStatesTableTableManager(
    _$AppDatabase db,
    $LearningStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> wordId = const Value.absent(),
                Value<int> stage = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
                Value<int> hazyCount = const Value.absent(),
                Value<int> wrongCount = const Value.absent(),
                Value<int> streak = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int?> lastStudiedAt = const Value.absent(),
                Value<int?> nextReviewAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningStatesCompanion(
                wordId: wordId,
                stage: stage,
                correctCount: correctCount,
                hazyCount: hazyCount,
                wrongCount: wrongCount,
                streak: streak,
                intervalDays: intervalDays,
                lastStudiedAt: lastStudiedAt,
                nextReviewAt: nextReviewAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordId,
                Value<int> stage = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
                Value<int> hazyCount = const Value.absent(),
                Value<int> wrongCount = const Value.absent(),
                Value<int> streak = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int?> lastStudiedAt = const Value.absent(),
                Value<int?> nextReviewAt = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LearningStatesCompanion.insert(
                wordId: wordId,
                stage: stage,
                correctCount: correctCount,
                hazyCount: hazyCount,
                wrongCount: wrongCount,
                streak: streak,
                intervalDays: intervalDays,
                lastStudiedAt: lastStudiedAt,
                nextReviewAt: nextReviewAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LearningStatesTable, LearningState>(table),
                  $$LearningStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (wordId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.wordId,
                        referencedTable: $$LearningStatesTableReferences
                            ._wordIdTable(db),
                        referencedColumn: $$LearningStatesTableReferences
                            ._wordIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearningStatesTable,
      LearningState,
      $$LearningStatesTableFilterComposer,
      $$LearningStatesTableOrderingComposer,
      $$LearningStatesTableAnnotationComposer,
      $$LearningStatesTableCreateCompanionBuilder,
      $$LearningStatesTableUpdateCompanionBuilder,
      (LearningState, $$LearningStatesTableReferences),
      LearningState,
      PrefetchHooks Function({bool wordId})
    >;
typedef $$ReviewEventsTableCreateCompanionBuilder =
    ReviewEventsCompanion Function({
      required String id,
      required String wordId,
      required String deviceId,
      required int answeredAt,
      required String localDay,
      required int result,
      required String type,
      Value<int> stageBefore,
      Value<int> intervalDaysAfter,
      Value<int> algoVersion,
      Value<String> mode,
      Value<int> causalOrder,
      Value<int?> dayStartUtc,
      Value<String> dayStartSource,
      Value<int> rowid,
    });
typedef $$ReviewEventsTableUpdateCompanionBuilder =
    ReviewEventsCompanion Function({
      Value<String> id,
      Value<String> wordId,
      Value<String> deviceId,
      Value<int> answeredAt,
      Value<String> localDay,
      Value<int> result,
      Value<String> type,
      Value<int> stageBefore,
      Value<int> intervalDaysAfter,
      Value<int> algoVersion,
      Value<String> mode,
      Value<int> causalOrder,
      Value<int?> dayStartUtc,
      Value<String> dayStartSource,
      Value<int> rowid,
    });

final class $$ReviewEventsTableReferences
    extends BaseReferences<_$AppDatabase, $ReviewEventsTable, ReviewEvent> {
  $$ReviewEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WordsTable _wordIdTable(_$AppDatabase db) =>
      db.words.createAlias('review_events__word_id__words__id');

  $$WordsTableProcessedTableManager get wordId {
    final $_column = $_itemColumn<String>('word_id')!;

    final manager = $$WordsTableTableManager(
      $_db,
      $_db.words,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReviewEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewEventsTable> {
  $$ReviewEventsTableFilterComposer({
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

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stageBefore => $composableBuilder(
    column: $table.stageBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDaysAfter => $composableBuilder(
    column: $table.intervalDaysAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get algoVersion => $composableBuilder(
    column: $table.algoVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get causalOrder => $composableBuilder(
    column: $table.causalOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayStartUtc => $composableBuilder(
    column: $table.dayStartUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayStartSource => $composableBuilder(
    column: $table.dayStartSource,
    builder: (column) => ColumnFilters(column),
  );

  $$WordsTableFilterComposer get wordId {
    final $$WordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableFilterComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewEventsTable> {
  $$ReviewEventsTableOrderingComposer({
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

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stageBefore => $composableBuilder(
    column: $table.stageBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDaysAfter => $composableBuilder(
    column: $table.intervalDaysAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get algoVersion => $composableBuilder(
    column: $table.algoVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get causalOrder => $composableBuilder(
    column: $table.causalOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayStartUtc => $composableBuilder(
    column: $table.dayStartUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayStartSource => $composableBuilder(
    column: $table.dayStartSource,
    builder: (column) => ColumnOrderings(column),
  );

  $$WordsTableOrderingComposer get wordId {
    final $$WordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableOrderingComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewEventsTable> {
  $$ReviewEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<int> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get stageBefore => $composableBuilder(
    column: $table.stageBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intervalDaysAfter => $composableBuilder(
    column: $table.intervalDaysAfter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get algoVersion => $composableBuilder(
    column: $table.algoVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get causalOrder => $composableBuilder(
    column: $table.causalOrder,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayStartUtc => $composableBuilder(
    column: $table.dayStartUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dayStartSource => $composableBuilder(
    column: $table.dayStartSource,
    builder: (column) => column,
  );

  $$WordsTableAnnotationComposer get wordId {
    final $$WordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableAnnotationComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewEventsTable,
          ReviewEvent,
          $$ReviewEventsTableFilterComposer,
          $$ReviewEventsTableOrderingComposer,
          $$ReviewEventsTableAnnotationComposer,
          $$ReviewEventsTableCreateCompanionBuilder,
          $$ReviewEventsTableUpdateCompanionBuilder,
          (ReviewEvent, $$ReviewEventsTableReferences),
          ReviewEvent,
          PrefetchHooks Function({bool wordId})
        > {
  $$ReviewEventsTableTableManager(_$AppDatabase db, $ReviewEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> wordId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> answeredAt = const Value.absent(),
                Value<String> localDay = const Value.absent(),
                Value<int> result = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> stageBefore = const Value.absent(),
                Value<int> intervalDaysAfter = const Value.absent(),
                Value<int> algoVersion = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> causalOrder = const Value.absent(),
                Value<int?> dayStartUtc = const Value.absent(),
                Value<String> dayStartSource = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewEventsCompanion(
                id: id,
                wordId: wordId,
                deviceId: deviceId,
                answeredAt: answeredAt,
                localDay: localDay,
                result: result,
                type: type,
                stageBefore: stageBefore,
                intervalDaysAfter: intervalDaysAfter,
                algoVersion: algoVersion,
                mode: mode,
                causalOrder: causalOrder,
                dayStartUtc: dayStartUtc,
                dayStartSource: dayStartSource,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String wordId,
                required String deviceId,
                required int answeredAt,
                required String localDay,
                required int result,
                required String type,
                Value<int> stageBefore = const Value.absent(),
                Value<int> intervalDaysAfter = const Value.absent(),
                Value<int> algoVersion = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> causalOrder = const Value.absent(),
                Value<int?> dayStartUtc = const Value.absent(),
                Value<String> dayStartSource = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewEventsCompanion.insert(
                id: id,
                wordId: wordId,
                deviceId: deviceId,
                answeredAt: answeredAt,
                localDay: localDay,
                result: result,
                type: type,
                stageBefore: stageBefore,
                intervalDaysAfter: intervalDaysAfter,
                algoVersion: algoVersion,
                mode: mode,
                causalOrder: causalOrder,
                dayStartUtc: dayStartUtc,
                dayStartSource: dayStartSource,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReviewEventsTable, ReviewEvent>(table),
                  $$ReviewEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (wordId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.wordId,
                        referencedTable: $$ReviewEventsTableReferences
                            ._wordIdTable(db),
                        referencedColumn: $$ReviewEventsTableReferences
                            ._wordIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReviewEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewEventsTable,
      ReviewEvent,
      $$ReviewEventsTableFilterComposer,
      $$ReviewEventsTableOrderingComposer,
      $$ReviewEventsTableAnnotationComposer,
      $$ReviewEventsTableCreateCompanionBuilder,
      $$ReviewEventsTableUpdateCompanionBuilder,
      (ReviewEvent, $$ReviewEventsTableReferences),
      ReviewEvent,
      PrefetchHooks Function({bool wordId})
    >;
typedef $$StudySettingsTableCreateCompanionBuilder =
    StudySettingsCompanion Function({
      Value<int> id,
      Value<int> dailyNewTarget,
      Value<int> dailyReviewLimit,
      Value<String?> currentWordBookId,
      Value<String> studyMode,
      Value<String> themeMode,
      Value<String> accentColor,
      Value<String> ttsVoice,
      Value<String> ttsLocale,
      Value<int> ttsRate,
      Value<bool> ttsAutoSpeak,
    });
typedef $$StudySettingsTableUpdateCompanionBuilder =
    StudySettingsCompanion Function({
      Value<int> id,
      Value<int> dailyNewTarget,
      Value<int> dailyReviewLimit,
      Value<String?> currentWordBookId,
      Value<String> studyMode,
      Value<String> themeMode,
      Value<String> accentColor,
      Value<String> ttsVoice,
      Value<String> ttsLocale,
      Value<int> ttsRate,
      Value<bool> ttsAutoSpeak,
    });

class $$StudySettingsTableFilterComposer
    extends Composer<_$AppDatabase, $StudySettingsTable> {
  $$StudySettingsTableFilterComposer({
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

  ColumnFilters<int> get dailyNewTarget => $composableBuilder(
    column: $table.dailyNewTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyReviewLimit => $composableBuilder(
    column: $table.dailyReviewLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentWordBookId => $composableBuilder(
    column: $table.currentWordBookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get studyMode => $composableBuilder(
    column: $table.studyMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accentColor => $composableBuilder(
    column: $table.accentColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ttsVoice => $composableBuilder(
    column: $table.ttsVoice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ttsLocale => $composableBuilder(
    column: $table.ttsLocale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ttsRate => $composableBuilder(
    column: $table.ttsRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ttsAutoSpeak => $composableBuilder(
    column: $table.ttsAutoSpeak,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudySettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudySettingsTable> {
  $$StudySettingsTableOrderingComposer({
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

  ColumnOrderings<int> get dailyNewTarget => $composableBuilder(
    column: $table.dailyNewTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyReviewLimit => $composableBuilder(
    column: $table.dailyReviewLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentWordBookId => $composableBuilder(
    column: $table.currentWordBookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studyMode => $composableBuilder(
    column: $table.studyMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accentColor => $composableBuilder(
    column: $table.accentColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ttsVoice => $composableBuilder(
    column: $table.ttsVoice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ttsLocale => $composableBuilder(
    column: $table.ttsLocale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ttsRate => $composableBuilder(
    column: $table.ttsRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ttsAutoSpeak => $composableBuilder(
    column: $table.ttsAutoSpeak,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudySettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudySettingsTable> {
  $$StudySettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dailyNewTarget => $composableBuilder(
    column: $table.dailyNewTarget,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dailyReviewLimit => $composableBuilder(
    column: $table.dailyReviewLimit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentWordBookId => $composableBuilder(
    column: $table.currentWordBookId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get studyMode =>
      $composableBuilder(column: $table.studyMode, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<String> get accentColor => $composableBuilder(
    column: $table.accentColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ttsVoice =>
      $composableBuilder(column: $table.ttsVoice, builder: (column) => column);

  GeneratedColumn<String> get ttsLocale =>
      $composableBuilder(column: $table.ttsLocale, builder: (column) => column);

  GeneratedColumn<int> get ttsRate =>
      $composableBuilder(column: $table.ttsRate, builder: (column) => column);

  GeneratedColumn<bool> get ttsAutoSpeak => $composableBuilder(
    column: $table.ttsAutoSpeak,
    builder: (column) => column,
  );
}

class $$StudySettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudySettingsTable,
          StudySettingsRow,
          $$StudySettingsTableFilterComposer,
          $$StudySettingsTableOrderingComposer,
          $$StudySettingsTableAnnotationComposer,
          $$StudySettingsTableCreateCompanionBuilder,
          $$StudySettingsTableUpdateCompanionBuilder,
          (
            StudySettingsRow,
            BaseReferences<
              _$AppDatabase,
              $StudySettingsTable,
              StudySettingsRow
            >,
          ),
          StudySettingsRow,
          PrefetchHooks Function()
        > {
  $$StudySettingsTableTableManager(_$AppDatabase db, $StudySettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudySettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudySettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudySettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dailyNewTarget = const Value.absent(),
                Value<int> dailyReviewLimit = const Value.absent(),
                Value<String?> currentWordBookId = const Value.absent(),
                Value<String> studyMode = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> accentColor = const Value.absent(),
                Value<String> ttsVoice = const Value.absent(),
                Value<String> ttsLocale = const Value.absent(),
                Value<int> ttsRate = const Value.absent(),
                Value<bool> ttsAutoSpeak = const Value.absent(),
              }) => StudySettingsCompanion(
                id: id,
                dailyNewTarget: dailyNewTarget,
                dailyReviewLimit: dailyReviewLimit,
                currentWordBookId: currentWordBookId,
                studyMode: studyMode,
                themeMode: themeMode,
                accentColor: accentColor,
                ttsVoice: ttsVoice,
                ttsLocale: ttsLocale,
                ttsRate: ttsRate,
                ttsAutoSpeak: ttsAutoSpeak,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dailyNewTarget = const Value.absent(),
                Value<int> dailyReviewLimit = const Value.absent(),
                Value<String?> currentWordBookId = const Value.absent(),
                Value<String> studyMode = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> accentColor = const Value.absent(),
                Value<String> ttsVoice = const Value.absent(),
                Value<String> ttsLocale = const Value.absent(),
                Value<int> ttsRate = const Value.absent(),
                Value<bool> ttsAutoSpeak = const Value.absent(),
              }) => StudySettingsCompanion.insert(
                id: id,
                dailyNewTarget: dailyNewTarget,
                dailyReviewLimit: dailyReviewLimit,
                currentWordBookId: currentWordBookId,
                studyMode: studyMode,
                themeMode: themeMode,
                accentColor: accentColor,
                ttsVoice: ttsVoice,
                ttsLocale: ttsLocale,
                ttsRate: ttsRate,
                ttsAutoSpeak: ttsAutoSpeak,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StudySettingsTable, StudySettingsRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $StudySettingsTable,
                    StudySettingsRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudySettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudySettingsTable,
      StudySettingsRow,
      $$StudySettingsTableFilterComposer,
      $$StudySettingsTableOrderingComposer,
      $$StudySettingsTableAnnotationComposer,
      $$StudySettingsTableCreateCompanionBuilder,
      $$StudySettingsTableUpdateCompanionBuilder,
      (
        StudySettingsRow,
        BaseReferences<_$AppDatabase, $StudySettingsTable, StudySettingsRow>,
      ),
      StudySettingsRow,
      PrefetchHooks Function()
    >;
typedef $$AppMetaTableCreateCompanionBuilder = AppMetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppMetaTableUpdateCompanionBuilder = AppMetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppMetaTableFilterComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppMetaTable,
          AppMetaRow,
          $$AppMetaTableFilterComposer,
          $$AppMetaTableOrderingComposer,
          $$AppMetaTableAnnotationComposer,
          $$AppMetaTableCreateCompanionBuilder,
          $$AppMetaTableUpdateCompanionBuilder,
          (
            AppMetaRow,
            BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaRow>,
          ),
          AppMetaRow,
          PrefetchHooks Function()
        > {
  $$AppMetaTableTableManager(_$AppDatabase db, $AppMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => AppMetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppMetaTable, AppMetaRow>(table),
                  BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaRow>(
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

typedef $$AppMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppMetaTable,
      AppMetaRow,
      $$AppMetaTableFilterComposer,
      $$AppMetaTableOrderingComposer,
      $$AppMetaTableAnnotationComposer,
      $$AppMetaTableCreateCompanionBuilder,
      $$AppMetaTableUpdateCompanionBuilder,
      (AppMetaRow, BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaRow>),
      AppMetaRow,
      PrefetchHooks Function()
    >;
typedef $$WordFavoritesTableCreateCompanionBuilder =
    WordFavoritesCompanion Function({
      required String wordId,
      Value<bool> value,
      Value<int> version,
      required int updatedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$WordFavoritesTableUpdateCompanionBuilder =
    WordFavoritesCompanion Function({
      Value<String> wordId,
      Value<bool> value,
      Value<int> version,
      Value<int> updatedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

final class $$WordFavoritesTableReferences
    extends BaseReferences<_$AppDatabase, $WordFavoritesTable, FavoriteRow> {
  $$WordFavoritesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WordsTable _wordIdTable(_$AppDatabase db) =>
      db.words.createAlias('word_favorites__word_id__words__id');

  $$WordsTableProcessedTableManager get wordId {
    final $_column = $_itemColumn<String>('word_id')!;

    final manager = $$WordsTableTableManager(
      $_db,
      $_db.words,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WordFavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $WordFavoritesTable> {
  $$WordFavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<bool> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  $$WordsTableFilterComposer get wordId {
    final $$WordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableFilterComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WordFavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $WordFavoritesTable> {
  $$WordFavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<bool> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  $$WordsTableOrderingComposer get wordId {
    final $$WordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableOrderingComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WordFavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordFavoritesTable> {
  $$WordFavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<bool> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  $$WordsTableAnnotationComposer get wordId {
    final $$WordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableAnnotationComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WordFavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordFavoritesTable,
          FavoriteRow,
          $$WordFavoritesTableFilterComposer,
          $$WordFavoritesTableOrderingComposer,
          $$WordFavoritesTableAnnotationComposer,
          $$WordFavoritesTableCreateCompanionBuilder,
          $$WordFavoritesTableUpdateCompanionBuilder,
          (FavoriteRow, $$WordFavoritesTableReferences),
          FavoriteRow,
          PrefetchHooks Function({bool wordId})
        > {
  $$WordFavoritesTableTableManager(_$AppDatabase db, $WordFavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordFavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordFavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordFavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> wordId = const Value.absent(),
                Value<bool> value = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordFavoritesCompanion(
                wordId: wordId,
                value: value,
                version: version,
                updatedAt: updatedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordId,
                Value<bool> value = const Value.absent(),
                Value<int> version = const Value.absent(),
                required int updatedAt,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => WordFavoritesCompanion.insert(
                wordId: wordId,
                value: value,
                version: version,
                updatedAt: updatedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordFavoritesTable, FavoriteRow>(table),
                  $$WordFavoritesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (wordId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.wordId,
                        referencedTable: $$WordFavoritesTableReferences
                            ._wordIdTable(db),
                        referencedColumn: $$WordFavoritesTableReferences
                            ._wordIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WordFavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordFavoritesTable,
      FavoriteRow,
      $$WordFavoritesTableFilterComposer,
      $$WordFavoritesTableOrderingComposer,
      $$WordFavoritesTableAnnotationComposer,
      $$WordFavoritesTableCreateCompanionBuilder,
      $$WordFavoritesTableUpdateCompanionBuilder,
      (FavoriteRow, $$WordFavoritesTableReferences),
      FavoriteRow,
      PrefetchHooks Function({bool wordId})
    >;
typedef $$UserTagsTableCreateCompanionBuilder = UserTagsCompanion Function({
  required String id,
  required String name,
  required String normalized,
  Value<int> version,
  required int updatedAt,
  required String deviceId,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$UserTagsTableUpdateCompanionBuilder = UserTagsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> normalized,
  Value<int> version,
  Value<int> updatedAt,
  Value<String> deviceId,
  Value<int?> deletedAt,
  Value<int> rowid,
});

final class $$UserTagsTableReferences
    extends BaseReferences<_$AppDatabase, $UserTagsTable, UserTag> {
  $$UserTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WordTagsTable, List<WordTag>> _wordTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.wordTags,
    aliasName: 'user_tags__id__word_tags__tag_id',
  );

  $$WordTagsTableProcessedTableManager get wordTagsRefs {
    final manager = $$WordTagsTableTableManager(
      $_db,
      $_db.wordTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_wordTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UserTagsTableFilterComposer
    extends Composer<_$AppDatabase, $UserTagsTable> {
  $$UserTagsTableFilterComposer({
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

  ColumnFilters<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> wordTagsRefs(
    Expression<bool> Function($$WordTagsTableFilterComposer f) f,
  ) {
    final $$WordTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wordTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordTagsTableFilterComposer(
            $db: $db,
            $table: $db.wordTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UserTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserTagsTable> {
  $$UserTagsTableOrderingComposer({
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

  ColumnOrderings<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserTagsTable> {
  $$UserTagsTableAnnotationComposer({
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

  GeneratedColumn<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> wordTagsRefs<T extends Object>(
    Expression<T> Function($$WordTagsTableAnnotationComposer a) f,
  ) {
    final $$WordTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wordTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.wordTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UserTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserTagsTable,
          UserTag,
          $$UserTagsTableFilterComposer,
          $$UserTagsTableOrderingComposer,
          $$UserTagsTableAnnotationComposer,
          $$UserTagsTableCreateCompanionBuilder,
          $$UserTagsTableUpdateCompanionBuilder,
          (UserTag, $$UserTagsTableReferences),
          UserTag,
          PrefetchHooks Function({bool wordTagsRefs})
        > {
  $$UserTagsTableTableManager(_$AppDatabase db, $UserTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalized = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserTagsCompanion(
                id: id,
                name: name,
                normalized: normalized,
                version: version,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String normalized,
                Value<int> version = const Value.absent(),
                required int updatedAt,
                required String deviceId,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserTagsCompanion.insert(
                id: id,
                name: name,
                normalized: normalized,
                version: version,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserTagsTable, UserTag>(table),
                  $$UserTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wordTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (wordTagsRefs) db.wordTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (wordTagsRefs)
                    await $_getPrefetchedDataByColumns<
                      UserTag,
                      $UserTagsTable,
                      WordTag,
                      $WordTagsTable
                    >(
                      currentTable: table,
                      referencedTable: $$UserTagsTableReferences
                          ._wordTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$UserTagsTableReferences(db, table, p0).wordTagsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'tag_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$UserTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserTagsTable,
      UserTag,
      $$UserTagsTableFilterComposer,
      $$UserTagsTableOrderingComposer,
      $$UserTagsTableAnnotationComposer,
      $$UserTagsTableCreateCompanionBuilder,
      $$UserTagsTableUpdateCompanionBuilder,
      (UserTag, $$UserTagsTableReferences),
      UserTag,
      PrefetchHooks Function({bool wordTagsRefs})
    >;
typedef $$WordTagsTableCreateCompanionBuilder = WordTagsCompanion Function({
  required String wordId,
  required String tagId,
  Value<int> version,
  required int updatedAt,
  required String deviceId,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$WordTagsTableUpdateCompanionBuilder = WordTagsCompanion Function({
  Value<String> wordId,
  Value<String> tagId,
  Value<int> version,
  Value<int> updatedAt,
  Value<String> deviceId,
  Value<int?> deletedAt,
  Value<int> rowid,
});

final class $$WordTagsTableReferences
    extends BaseReferences<_$AppDatabase, $WordTagsTable, WordTag> {
  $$WordTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WordsTable _wordIdTable(_$AppDatabase db) =>
      db.words.createAlias('word_tags__word_id__words__id');

  $$WordsTableProcessedTableManager get wordId {
    final $_column = $_itemColumn<String>('word_id')!;

    final manager = $$WordsTableTableManager(
      $_db,
      $_db.words,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UserTagsTable _tagIdTable(_$AppDatabase db) =>
      db.userTags.createAlias('word_tags__tag_id__user_tags__id');

  $$UserTagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$UserTagsTableTableManager(
      $_db,
      $_db.userTags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WordTagsTableFilterComposer
    extends Composer<_$AppDatabase, $WordTagsTable> {
  $$WordTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WordsTableFilterComposer get wordId {
    final $$WordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableFilterComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserTagsTableFilterComposer get tagId {
    final $$UserTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.userTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserTagsTableFilterComposer(
            $db: $db,
            $table: $db.userTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WordTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $WordTagsTable> {
  $$WordTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WordsTableOrderingComposer get wordId {
    final $$WordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableOrderingComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserTagsTableOrderingComposer get tagId {
    final $$UserTagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.userTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserTagsTableOrderingComposer(
            $db: $db,
            $table: $db.userTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WordTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordTagsTable> {
  $$WordTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$WordsTableAnnotationComposer get wordId {
    final $$WordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.words,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordsTableAnnotationComposer(
            $db: $db,
            $table: $db.words,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserTagsTableAnnotationComposer get tagId {
    final $$UserTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.userTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.userTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WordTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordTagsTable,
          WordTag,
          $$WordTagsTableFilterComposer,
          $$WordTagsTableOrderingComposer,
          $$WordTagsTableAnnotationComposer,
          $$WordTagsTableCreateCompanionBuilder,
          $$WordTagsTableUpdateCompanionBuilder,
          (WordTag, $$WordTagsTableReferences),
          WordTag,
          PrefetchHooks Function({bool wordId, bool tagId})
        > {
  $$WordTagsTableTableManager(_$AppDatabase db, $WordTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> wordId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordTagsCompanion(
                wordId: wordId,
                tagId: tagId,
                version: version,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordId,
                required String tagId,
                Value<int> version = const Value.absent(),
                required int updatedAt,
                required String deviceId,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordTagsCompanion.insert(
                wordId: wordId,
                tagId: tagId,
                version: version,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordTagsTable, WordTag>(table),
                  $$WordTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wordId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (wordId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.wordId,
                        referencedTable: $$WordTagsTableReferences._wordIdTable(
                          db,
                        ),
                        referencedColumn: $$WordTagsTableReferences
                            ._wordIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (tagId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tagId,
                        referencedTable: $$WordTagsTableReferences._tagIdTable(
                          db,
                        ),
                        referencedColumn: $$WordTagsTableReferences
                            ._tagIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WordTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordTagsTable,
      WordTag,
      $$WordTagsTableFilterComposer,
      $$WordTagsTableOrderingComposer,
      $$WordTagsTableAnnotationComposer,
      $$WordTagsTableCreateCompanionBuilder,
      $$WordTagsTableUpdateCompanionBuilder,
      (WordTag, $$WordTagsTableReferences),
      WordTag,
      PrefetchHooks Function({bool wordId, bool tagId})
    >;
typedef $$SyncAliasesTableCreateCompanionBuilder =
    SyncAliasesCompanion Function({
      required String kind,
      required String aliasId,
      required String localId,
      Value<int> rowid,
    });
typedef $$SyncAliasesTableUpdateCompanionBuilder =
    SyncAliasesCompanion Function({
      Value<String> kind,
      Value<String> aliasId,
      Value<String> localId,
      Value<int> rowid,
    });

class $$SyncAliasesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncAliasesTable> {
  $$SyncAliasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliasId => $composableBuilder(
    column: $table.aliasId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncAliasesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncAliasesTable> {
  $$SyncAliasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliasId => $composableBuilder(
    column: $table.aliasId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncAliasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncAliasesTable> {
  $$SyncAliasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get aliasId =>
      $composableBuilder(column: $table.aliasId, builder: (column) => column);

  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);
}

class $$SyncAliasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncAliasesTable,
          SyncAliasRow,
          $$SyncAliasesTableFilterComposer,
          $$SyncAliasesTableOrderingComposer,
          $$SyncAliasesTableAnnotationComposer,
          $$SyncAliasesTableCreateCompanionBuilder,
          $$SyncAliasesTableUpdateCompanionBuilder,
          (
            SyncAliasRow,
            BaseReferences<_$AppDatabase, $SyncAliasesTable, SyncAliasRow>,
          ),
          SyncAliasRow,
          PrefetchHooks Function()
        > {
  $$SyncAliasesTableTableManager(_$AppDatabase db, $SyncAliasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncAliasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncAliasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncAliasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> aliasId = const Value.absent(),
                Value<String> localId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncAliasesCompanion(
                kind: kind,
                aliasId: aliasId,
                localId: localId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String aliasId,
                required String localId,
                Value<int> rowid = const Value.absent(),
              }) => SyncAliasesCompanion.insert(
                kind: kind,
                aliasId: aliasId,
                localId: localId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncAliasesTable, SyncAliasRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncAliasesTable,
                    SyncAliasRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncAliasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncAliasesTable,
      SyncAliasRow,
      $$SyncAliasesTableFilterComposer,
      $$SyncAliasesTableOrderingComposer,
      $$SyncAliasesTableAnnotationComposer,
      $$SyncAliasesTableCreateCompanionBuilder,
      $$SyncAliasesTableUpdateCompanionBuilder,
      (
        SyncAliasRow,
        BaseReferences<_$AppDatabase, $SyncAliasesTable, SyncAliasRow>,
      ),
      SyncAliasRow,
      PrefetchHooks Function()
    >;
typedef $$ContentVersionsTableCreateCompanionBuilder =
    ContentVersionsCompanion Function({
      required String kind,
      required String entityId,
      required String field,
      required int version,
      required int updatedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$ContentVersionsTableUpdateCompanionBuilder =
    ContentVersionsCompanion Function({
      Value<String> kind,
      Value<String> entityId,
      Value<String> field,
      Value<int> version,
      Value<int> updatedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$ContentVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $ContentVersionsTable> {
  $$ContentVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentVersionsTable> {
  $$ContentVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentVersionsTable> {
  $$ContentVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$ContentVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContentVersionsTable,
          ContentVersionRow,
          $$ContentVersionsTableFilterComposer,
          $$ContentVersionsTableOrderingComposer,
          $$ContentVersionsTableAnnotationComposer,
          $$ContentVersionsTableCreateCompanionBuilder,
          $$ContentVersionsTableUpdateCompanionBuilder,
          (
            ContentVersionRow,
            BaseReferences<
              _$AppDatabase,
              $ContentVersionsTable,
              ContentVersionRow
            >,
          ),
          ContentVersionRow,
          PrefetchHooks Function()
        > {
  $$ContentVersionsTableTableManager(
    _$AppDatabase db,
    $ContentVersionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> field = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentVersionsCompanion(
                kind: kind,
                entityId: entityId,
                field: field,
                version: version,
                updatedAt: updatedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String entityId,
                required String field,
                required int version,
                required int updatedAt,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => ContentVersionsCompanion.insert(
                kind: kind,
                entityId: entityId,
                field: field,
                version: version,
                updatedAt: updatedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContentVersionsTable, ContentVersionRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ContentVersionsTable,
                    ContentVersionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContentVersionsTable,
      ContentVersionRow,
      $$ContentVersionsTableFilterComposer,
      $$ContentVersionsTableOrderingComposer,
      $$ContentVersionsTableAnnotationComposer,
      $$ContentVersionsTableCreateCompanionBuilder,
      $$ContentVersionsTableUpdateCompanionBuilder,
      (
        ContentVersionRow,
        BaseReferences<_$AppDatabase, $ContentVersionsTable, ContentVersionRow>,
      ),
      ContentVersionRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WordsTableTableManager get words =>
      $$WordsTableTableManager(_db, _db.words);
  $$WordBooksTableTableManager get wordBooks =>
      $$WordBooksTableTableManager(_db, _db.wordBooks);
  $$WordBookEntriesTableTableManager get wordBookEntries =>
      $$WordBookEntriesTableTableManager(_db, _db.wordBookEntries);
  $$LearningStatesTableTableManager get learningStates =>
      $$LearningStatesTableTableManager(_db, _db.learningStates);
  $$ReviewEventsTableTableManager get reviewEvents =>
      $$ReviewEventsTableTableManager(_db, _db.reviewEvents);
  $$StudySettingsTableTableManager get studySettings =>
      $$StudySettingsTableTableManager(_db, _db.studySettings);
  $$AppMetaTableTableManager get appMeta =>
      $$AppMetaTableTableManager(_db, _db.appMeta);
  $$WordFavoritesTableTableManager get wordFavorites =>
      $$WordFavoritesTableTableManager(_db, _db.wordFavorites);
  $$UserTagsTableTableManager get userTags =>
      $$UserTagsTableTableManager(_db, _db.userTags);
  $$WordTagsTableTableManager get wordTags =>
      $$WordTagsTableTableManager(_db, _db.wordTags);
  $$SyncAliasesTableTableManager get syncAliases =>
      $$SyncAliasesTableTableManager(_db, _db.syncAliases);
  $$ContentVersionsTableTableManager get contentVersions =>
      $$ContentVersionsTableTableManager(_db, _db.contentVersions);
}
