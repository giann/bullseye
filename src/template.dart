abstract class Template<T> {
  T? context;

  Template(this.context);

  String render();
}
