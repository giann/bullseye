class NodeAttribute {
  String key;
  String value;

  NodeAttribute({
    required this.key,
    required this.value,
  });

  String render() => '$key="$value" ';
}

NodeAttribute attr(String key, String value) => NodeAttribute(key: key, value: value);

abstract class Node {
  ElementNode? parent;

  String render();
}

class TextNode extends Node {
  String text;

  TextNode(this.text);

  @override
  String render() => text;
}

TextNode text(String text) => TextNode(text);

class ElementNode extends Node {
  String tag;
  Set<NodeAttribute> attributes;

  List<Node> children;

  ElementNode(
    this.tag, {
    ElementNode? parent,
    Set<NodeAttribute>? attributes,
    List<Node>? children,
  })  : attributes = attributes ?? {},
        children = children ?? [] {
    this.parent = parent;

    for (Node child in this.children) {
      child.parent = this;
    }
  }

  @override
  String render() {
    String rendered = "<$tag ";

    for (NodeAttribute attribute in attributes) {
      rendered += attribute.render();
    }

    if (children.isEmpty) {
      rendered = '/>';
    } else {
      rendered = rendered.trimRight() + '>';

      for (Node child in children) {
        rendered += child.render();
      }

      rendered += '</$tag>';
    }

    return rendered;
  }
}

// Valid html tags factories
ElementNode a({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('a', parent: parent, attributes: attributes, children: children);
ElementNode article({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('article', parent: parent, attributes: attributes, children: children);
ElementNode aside({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('aside', parent: parent, attributes: attributes, children: children);
ElementNode audio({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('audio', parent: parent, attributes: attributes, children: children);
ElementNode br({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('br', parent: parent, attributes: attributes, children: children);
ElementNode canvas({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('canvas', parent: parent, attributes: attributes, children: children);
ElementNode div({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('div', parent: parent, attributes: attributes, children: children);
ElementNode footer({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('footer', parent: parent, attributes: attributes, children: children);
ElementNode header({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('header', parent: parent, attributes: attributes, children: children);
ElementNode hr({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('hr', parent: parent, attributes: attributes, children: children);
ElementNode iframe({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('iframe', parent: parent, attributes: attributes, children: children);
ElementNode img({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('img', parent: parent, attributes: attributes, children: children);
ElementNode li({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('li', parent: parent, attributes: attributes, children: children);
ElementNode nav({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('nav', parent: parent, attributes: attributes, children: children);
ElementNode ol({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('ol', parent: parent, attributes: attributes, children: children);
ElementNode option({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('option', parent: parent, attributes: attributes, children: children);
ElementNode p({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('p', parent: parent, attributes: attributes, children: children);
ElementNode pre({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('pre', parent: parent, attributes: attributes, children: children);
ElementNode section({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('section', parent: parent, attributes: attributes, children: children);
ElementNode select({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('select', parent: parent, attributes: attributes, children: children);
ElementNode span({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('span', parent: parent, attributes: attributes, children: children);
ElementNode svg({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('svg', parent: parent, attributes: attributes, children: children);
ElementNode table({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('table', parent: parent, attributes: attributes, children: children);
ElementNode td({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('td', parent: parent, attributes: attributes, children: children);
ElementNode textarea({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('textarea', parent: parent, attributes: attributes, children: children);
ElementNode th({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('th', parent: parent, attributes: attributes, children: children);
ElementNode tr({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('tr', parent: parent, attributes: attributes, children: children);
ElementNode ul({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('ul', parent: parent, attributes: attributes, children: children);
ElementNode video({ElementNode? parent, Set<NodeAttribute>? attributes, List<Node>? children}) =>
    ElementNode('video', parent: parent, attributes: attributes, children: children);
