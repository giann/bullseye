class NodeAttribute {
  final String key;
  final String value;

  const NodeAttribute({
    required this.key,
    required this.value,
  });

  String render() => '$key="$value" ';
}

NodeAttribute attr(String key, String value) => NodeAttribute(key: key, value: value);

abstract class Node {
  const Node();

  String render();
}

class TextNode extends Node {
  final String text;

  const TextNode(this.text, {ElementNode? parent}) : super();

  @override
  String render() => text;
}

TextNode text(String text) => TextNode(text);

class ElementNode extends Node {
  final String tag;
  final Set<NodeAttribute> attributes;

  final List<Node> children;

  const ElementNode(
    this.tag, {
    this.attributes = const {},
    this.children = const [],
  }) : super();

  @override
  String render() {
    String rendered = "<$tag ";

    for (NodeAttribute attribute in attributes) {
      rendered += attribute.render();
    }

    if (children.isEmpty) {
      rendered += '/>';
    } else {
      rendered += rendered.trimRight() + '>';

      for (Node child in children) {
        rendered += child.render();
      }

      rendered += '</$tag>';
    }

    return rendered;
  }
}

ElementNode form({
  String? action,
  String? method,
  Set<NodeAttribute> attributes = const {},
  List<Node> children = const [],
}) {
  if (action != null) {
    attributes = <NodeAttribute>{}
      ..addAll(attributes)
      ..add(NodeAttribute(key: 'action', value: action));
  }

  if (method != null) {
    attributes = <NodeAttribute>{}
      ..addAll(attributes)
      ..add(NodeAttribute(key: 'method', value: method));
  }

  return ElementNode('form', attributes: attributes, children: children);
}

ElementNode label({
  String? $for,
  Set<NodeAttribute> attributes = const {},
  List<Node> children = const [],
}) {
  if ($for != null) {
    attributes = <NodeAttribute>{}
      ..addAll(attributes)
      ..add(NodeAttribute(key: 'for', value: $for));
  }

  return ElementNode('label', attributes: attributes, children: children);
}

ElementNode input({
  String? type,
  String? id,
  String? name,
  Set<NodeAttribute> attributes = const {},
  List<Node> children = const [],
}) {
  if (type != null) {
    attributes = <NodeAttribute>{}
      ..addAll(attributes)
      ..add(NodeAttribute(key: 'type', value: type));
  }
  if (id != null) {
    attributes = <NodeAttribute>{}
      ..addAll(attributes)
      ..add(NodeAttribute(key: 'id', value: id));
  }
  if (name != null) {
    attributes = <NodeAttribute>{}
      ..addAll(attributes)
      ..add(NodeAttribute(key: 'name', value: name));
  }

  return ElementNode('input', attributes: attributes, children: children);
}

// Valid html tags factories
ElementNode a({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('a', attributes: attributes, children: children);
ElementNode article({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('article', attributes: attributes, children: children);
ElementNode aside({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('aside', attributes: attributes, children: children);
ElementNode audio({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('audio', attributes: attributes, children: children);
ElementNode br({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('br', attributes: attributes, children: children);
ElementNode canvas({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('canvas', attributes: attributes, children: children);
ElementNode div({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('div', attributes: attributes, children: children);
ElementNode footer({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('footer', attributes: attributes, children: children);
ElementNode header({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('header', attributes: attributes, children: children);
ElementNode hr({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('hr', attributes: attributes, children: children);
ElementNode iframe({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('iframe', attributes: attributes, children: children);
ElementNode img({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('img', attributes: attributes, children: children);
ElementNode li({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('li', attributes: attributes, children: children);
ElementNode nav({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('nav', attributes: attributes, children: children);
ElementNode ol({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('ol', attributes: attributes, children: children);
ElementNode option({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('option', attributes: attributes, children: children);
ElementNode p({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('p', attributes: attributes, children: children);
ElementNode pre({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('pre', attributes: attributes, children: children);
ElementNode section({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('section', attributes: attributes, children: children);
ElementNode select({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('select', attributes: attributes, children: children);
ElementNode span({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('span', attributes: attributes, children: children);
ElementNode svg({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('svg', attributes: attributes, children: children);
ElementNode table({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('table', attributes: attributes, children: children);
ElementNode td({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('td', attributes: attributes, children: children);
ElementNode textarea({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('textarea', attributes: attributes, children: children);
ElementNode th({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('th', attributes: attributes, children: children);
ElementNode tr({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('tr', attributes: attributes, children: children);
ElementNode ul({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('ul', attributes: attributes, children: children);
ElementNode video({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('video', attributes: attributes, children: children);
ElementNode h1({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('h1', attributes: attributes, children: children);
ElementNode h2({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('h2', attributes: attributes, children: children);
ElementNode h3({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('h3', attributes: attributes, children: children);
ElementNode h4({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('h4', attributes: attributes, children: children);
ElementNode h5({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('h5', attributes: attributes, children: children);
ElementNode h6({Set<NodeAttribute> attributes = const {}, List<Node> children = const []}) =>
    ElementNode('h6', attributes: attributes, children: children);
