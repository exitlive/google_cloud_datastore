part of datastore;

/**
 * An annotation which marks a class definition as a kind.
 *
 * If [:name:] is provided, used as the name of the datastore kind. Otherwise the name of the
 * annnotated class is used instead.
 *
 * If [:concrete:] is `false`, the kind is stored in the datastore as a subtype of the first
 * concrete parent of the kind. Subkinds will be automatically instantiated as an instance of
 * the annotated class, but inherit properties from the inherited type. Exactly *one* concrete
 * class may exist in any inheritance heirarchy.
 *
 * It is an error if a `kind` annotated class does not define an unnamed, two-argument constructor which
 * redirects to `Entity(Datastore datastore, Key key)`.
 */
class Kind {
  final String name;
  final bool concrete;
  const Kind({String this.name, this.concrete: true});
}




/**
 * An annotation which marks a getter method on a [:kind:] annotated class as an entity property
 * Must be applied to a getter method on the annotated class.
 *
 * Calling `getProperty(<property_name>)` and `setProperty(<property_name>, <value>)` will
 * get/set the appropriate property as required.
 *
 * If [name] is provided, it is used as the datastore name for the property, otherwise the
 * name of the annotated method is used.
 *
 * [:indexed:] determines whether the datastore property should be indexed (default is `false`)
 *
 * if [:type:] is provided, it is used as the schema type of the property.
 *
 * The type of the schema property is inferred from the type of the dart property's return type.
 * Only a limited set of property types are supported by the library, these are:
 * - [dynamic]
 * - [bool]
 * - [int]
 * - [double]/[num] (both interpreted as a schema `double` property)
 * - [String]
 * - [Uint8List] (interpreted as a schema `blob` property)
 * - [Key]
 * or a [List] of values of any of these types.
 */
class Property {
  final String name;
  final PropertyType type;
  final bool indexed;

  const Property({this.name, PropertyType this.type, bool this.indexed: false});
}




/**
 * An annotation which indicates that the annotated constructor
 * method should be used instead of the unnamed constructor on the class.
 *
 * The constructor must still accept two arguments, the [:datastore:] and
 * [:key:] of the created entity and must redirect to the default `Entity`
 * constructor.
 */
const constructKind = const _KindConstructor();

class _KindConstructor {
  const _KindConstructor();
}

