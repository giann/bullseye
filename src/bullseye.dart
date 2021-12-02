import 'dom.dart';
import 'template.dart';

class MyModel {
  String name;

  MyModel(this.name);
}

class MyView extends Template<MyModel> {
  MyView(MyModel context) : super(context);

  @override
  String render() {
    return div(
      attributes: <NodeAttribute>{
        attr('class', 'yolo'),
      },
      children: [
        text('hello my name is: ${context?.name ?? 'Unknown'}'),
      ],
    ).render();
  }
}

void main(List<String> arguments) {
  print(
    MyView(MyModel('Benoit')).render(),
  );
}
