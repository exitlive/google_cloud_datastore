part of datastore.common;

class Entity {
  /**
   * A property definition which can be used in filters which can be
   * used to specify filters which match on an entity's [:key:].
   *
   * The dastore ordering on keys (when filtering for inequality) is:
   * 1. Ancestor Path
   * 2. Entity Kind
   * 3. Identifier (key name or numeric id)
   */
  static const PropertyDefinition KEY_PROPERTY = const _KeyProperty();

  /**
   * A property definition which can be used to filter for properties
   * of a specific subkind of a concrete kind
   */
  static const PropertyDefinition SUBKIND_PROPERTY = const _SubkindProperty();

  static KindDefinition _initSubkind(String keyKind, String subkind) {
    var keyKindDefn = Datastore.kindByName(keyKind);

    if (subkind == null) {
      //There is no subkind. The concrete key is the leaf kind.
      return null;
    }
    var subkindDefn = Datastore.kindByName(subkind);

    if (subkindDefn.concrete) {
      throw new KindError.concreteSubkind(subkind);
    }

    var parentKind = subkindDefn.extendsKind;
    while (parentKind != keyKindDefn) {
      parentKind = parentKind.extendsKind;
      if (parentKind == null) {
        throw new KindError.notDirectSubkind(subkind, keyKind);
      }
    }

    return subkindDefn;
  }

  final Key key;
  /**
   * The datastore kind of the entity
   */
  KindDefinition get kind => Datastore.kindByName(key.kind);

  /**
   * The specific subkind of the entity. If the kind is [:concrete:], then will
   * be the same as `kind`.
   */
  KindDefinition get subkind {
    if (hasProperty(SUBKIND_PROPERTY.name)) {
      return Datastore.kindByName(getProperty(SUBKIND_PROPERTY.name));
    }
    return kind;
  }
  final PropertyMap _properties;

  /**
   * Create a new [Entity] against the given [datastore]
   * with the given [key] and, optionally, initial values
   * for the entity's properties.
   */
  Entity(Key key, [Map<String,dynamic> propertyInits = const {}, String subkind]) :
    this.key = key,
    _properties = new PropertyMap(
        (subkind != null) ? _initSubkind(key.kind, subkind) : Datastore.kindByName(key.kind),
        propertyInits);

  bool hasProperty(String propertyName) {
    return _properties.containsKey(propertyName);
  }

  dynamic getProperty(String propertyName) {
    var prop = _properties[propertyName];
    return prop.value;
  }

  void setProperty(String propertyName, var value) {
    var prop = _properties[propertyName];
    prop.value = value;
  }

  schema.Entity _toSchemaEntity() {
    schema.Entity schemaEntity = new schema.Entity();
    schemaEntity.key = key._toSchemaKey();
    _properties.forEach((String name, _PropertyInstance prop) {
      var defn = subkind.properties[name];
      assert(defn != null);
      schemaEntity.property.add(prop._toSchemaProperty(defn));
    });
    return schemaEntity;
  }

  bool operator ==(Object other) => other is Entity && other.key == key;
  int get hashCode => key.hashCode;

  String toString() => "Entity($key)";
}

/**
 * The result of a lookup operation for an [Entity].
 */
class EntityResult<T extends Entity> {
  static const KEY_ONLY = 0;
  static const ENTITY_PRESENT = 1;

  /**
   * The looked up key
   */
  final Key key;
  /**
   * The entity found associated with the [:key:] in the datastore,
   * or `null` if no entity corresponding with the given key exists.
   */
  final T entity;

  bool get isKeyOnlyResult => resultType == KEY_ONLY;

  bool get isPresent => resultType == ENTITY_PRESENT;

  final resultType;

  EntityResult._(this.resultType, this.key, this.entity);

  factory EntityResult._fromSchemaEntityResult(
      Datastore datastore,
      schema.EntityResult entityResult,
      schema.EntityResult_ResultType resultType) {
    if (resultType == schema.EntityResult_ResultType.KEY_ONLY) {
      var key = new Key._fromSchemaKey(entityResult.entity.key);
      return new EntityResult._(KEY_ONLY, key, null);
    }
    if (resultType == schema.EntityResult_ResultType.FULL) {
      var key = new Key._fromSchemaKey(entityResult.entity.key);
      var kind = Datastore.kindByName(key.kind);
      var ent = kind._fromSchemaEntity(key, entityResult.entity);
      return new EntityResult._(ENTITY_PRESENT, key, ent);
    }
    //We don't support projections (yet).
    assert(false);
  }
}

class PropertyMap extends UnmodifiableMapMixin<String,_PropertyInstance> {
  final KindDefinition kind;
  Map<String,_PropertyInstance> _entityProperties;

  PropertyMap(KindDefinition this.kind, Map<String,dynamic> propertyInits) :
    _entityProperties = new Map() {
    this.kind.properties.forEach((name, defn) {
      if (name == Entity.SUBKIND_PROPERTY.name) {
        _entityProperties[name] = defn.type.create(initialValue: kind.name);
      } else {
        _entityProperties[name] = defn.type.create(initialValue: propertyInits[name]);
      }
    });
  }

  @override
  _PropertyInstance operator [](String key) {
    if (!containsKey(key))
      throw new NoSuchPropertyError(kind, key);
    return _entityProperties[key];
  }

  @override
  bool containsKey(String key) => _entityProperties.containsKey(key);

  @override
  bool containsValue(_PropertyInstance value) => _entityProperties.containsValue(value);

  @override
  void forEach(void f(String key, _PropertyInstance value)) {
    _entityProperties.forEach(f);
  }

  @override
  bool get isEmpty => _entityProperties.isEmpty;

  @override
  bool get isNotEmpty => _entityProperties.isNotEmpty;

  @override
  Iterable<String> get keys => _entityProperties.keys;

  @override
  int get length => _entityProperties.length;

  @override
  Iterable<_PropertyInstance> get values => _entityProperties.values;
}
