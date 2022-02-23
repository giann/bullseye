import 'dart:mirrors';

Map<String, Object> instanceToMap<T>(
  T instance, [
  Map<String, Object>? values,
  ClassMirror? superclass,
]) {
  values = values ?? {};

  InstanceMirror instanceMirror = reflect(instance);
  ClassMirror classMirror = superclass ?? instanceMirror.type;

  classMirror.declarations.forEach((Symbol key, DeclarationMirror decl) {
    if (decl is VariableMirror && !decl.isPrivate) {
      values![MirrorSystem.getName(decl.simpleName)] = instanceMirror.getField(decl.simpleName).reflectee as Object;
    }
  });

  if (classMirror.superclass != null) {
    return instanceToMap<T>(instance, values, classMirror.superclass);
  }

  return values;
}

List<DeclarationMirror> declarationsOf(
  ClassMirror classMirror, [
  List<DeclarationMirror>? declarations,
]) {
  declarations = declarations ?? [];

  declarations.addAll(classMirror.declarations.values);

  if (classMirror.superclass != null) {
    return declarationsOf(classMirror.superclass!, declarations);
  }

  return declarations;
}
