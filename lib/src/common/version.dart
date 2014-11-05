part of common;

/**
 * Generate a default model version UID for the entity.
 *
 * By default, the model version is a hash which is dependent on
 * - The key, including the parent key.
 * - All the properties types, names and `indexed` status.
 *
 * The model version UID is created to protect against the possibility of
 * having a incompatible kind stored in the datastore which doesn't match
 * the entity schema.
 *
 * Users should override the model version UID to gain more control over
 * whether a datastore stored entity is compatible for deserialization with
 * the given entity definition.
 */
int defaultModelVersionUID(KindDefinition kind) {

  int _hashPropertyType(PropertyType type) {
    if (type is ListPropertyType) {
      return 0x00000001 ^ _hashPropertyType(type.generic);
    }
    if (type == PropertyType.DYNAMIC)
      return 0x0;
    if (type == PropertyType.BOOLEAN)
      return 0x1;
    if (type == PropertyType.INTEGER)
      return 0x2;
    if (type == PropertyType.DOUBLE)
      return 0x4;
    if (type == PropertyType.STRING)
      return 0x8;
    if (type == PropertyType.KEY)
      return 0x10;
    if (type == PropertyType.DATE_TIME)
      return 0x20;
    if (type == PropertyType.BLOB)
      return 0x40;
    throw new UnsupportedError('Unrecognised property type: ${type}');
  }

  _hashProperty(PropertyDefinition prop) {
    return qcore.hashObjects([
        _hashPropertyType(prop.type),
        prop.name,
        prop.indexed
    ]);
  }

  return qcore.hashObjects(
      kind.properties.values.map(_hashProperty)
  );

}