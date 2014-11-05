part of datastore.common;

/**
 * A [_Value] is an instantiated [PropertyDefinition]
 */
class _Value<T> {
  final String propertyName;
  final PropertyType<T> propertyType;
  T _value;

  T get value => _value;
    set value(T value) {
      _value = propertyType.checkType(propertyName, value);
    }

  _Value(String propertyName, PropertyType<T> propertyType, {T initialValue}) :
    this.propertyName = propertyName,
    this.propertyType = propertyType,
    this._value = propertyType.checkType(propertyName, initialValue);

  _Value.fromSchemaProperty(String propertyName, PropertyType propertyType, schema.Property schemaProperty):
    this(propertyName, propertyType, initialValue: propertyType._fromSchemaValue(schemaProperty.value));

  schema.Property _toSchemaProperty(PropertyDefinition definition) {
    schema.Value schemaValue = propertyType._toSchemaValue(new schema.Value(), _value)
      ..indexed = definition.indexed;
    return new schema.Property()
        ..name = definition.name
        ..value = schemaValue;
  }
}

/**
 * A [_ListValue] is an instantiated [ListPropertyDefinition]
 */
class _ListValue<T> extends _Value<List<T>> {

  PropertyType<T> get generic => (propertyType as ListPropertyType).generic;

  List<_Value<T>> get listValue {
    return value.map((e) => new _Value(propertyName, generic).._value = e)
        .toList(growable: false);
  }
  set listValue(List<_Value<T>> elements) {
    this.value
        ..clear()
        ..addAll(elements.map((e) => e._value));
  }

  _ListValue(String propertyName, ListPropertyType<T> propertyType, {List<T> initialValue}):
    super(propertyName, propertyType,
        initialValue: (initialValue != null) ? initialValue: []);

  _ListValue.fromSchemaProperty(String propertyName, PropertyType propertyType, schema.Property schemaProperty):
    super.fromSchemaProperty(propertyName, propertyType, schemaProperty);

  @override
  schema.Property _toSchemaProperty(PropertyDefinition definition) {
    if (definition.indexed) {
      throw new PropertyException("A list property cannot be indexed");
    }
    var schemaValue = propertyType._toSchemaValue(new schema.Value(), _value);
    return new schema.Property()
      ..name = definition.name
      ..value = schemaValue;
  }
}