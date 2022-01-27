/// A tree to hold value with commons path in the same leafs
/// TODO: benchmark: is this faster than a simple map? (i suspect not since we instanciate a bunch of maps...)
class SegmentMap<T> {
  final String separator;
  final String root;
  T? value;
  Map<String, SegmentMap<T>> map = {};
  // TODO
  // final bool canVary = false;

  SegmentMap({
    this.root = '/',
    this.value,
    this.separator = '/',
  });

  void operator []=(String path, T? data) {
    List<String> segments = path.split(separator);

    if (path.startsWith(separator)) {
      segments[0] = separator;
    }

    if (map[segments.first] == null) {
      map[segments.first] = SegmentMap<T>(root: segments.first);
    }

    SegmentMap<T> leaf = map[segments.first]!;

    if (segments.length == 1) {
      leaf.value = data;
    } else {
      leaf[segments.sublist(1).join(separator)] = data;
    }
  }

  T? operator [](String path) {
    List<String> segments = path.split(separator);

    if (path.startsWith(separator)) {
      segments[0] = separator;
    }

    SegmentMap<T>? first = map[segments.first];
    if (first != null) {
      if (segments.length == 1) {
        return first.value;
      } else {
        return first[segments.sublist(1).join(separator)];
      }
    }
  }

  String _toString([int depth = 0]) {
    String result = '';

    print('${'  ' * depth} + $root <${value ?? 'n/a'}>');

    map.forEach((String segment, SegmentMap map) => result += map._toString(depth + 1));

    return result;
  }

  @override
  String toString() => _toString();
}

void main() {
  SegmentMap<String> map = SegmentMap<String>();

  map['GET/hello/world/yolo'] = 'one';
  map['POST/hello/mundo/yolo'] = 'two';
  map['GET/bye/joe'] = 'three';

  print(map);

  print(map['POST/hello/mundo/yolo']);
}
