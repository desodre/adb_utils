import 'package:xml/xml.dart';

class UiHierarchy {
  final int rotation;
  final List<UiNode> nodes;

  UiHierarchy({required this.rotation, required this.nodes});

  factory UiHierarchy.fromXmlString(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final hierarchyElement = document.findAllElements('hierarchy').first;

    return UiHierarchy(
      rotation:
          int.tryParse(hierarchyElement.getAttribute('rotation') ?? '0') ?? 0,
      nodes: hierarchyElement.childElements
          .where((e) => e.name.local == 'node')
          .map((e) => UiNode.fromXmlElement(e))
          .toList(),
    );
  }
}

class UiNode {
  final int index;
  final String text;
  final String resourceId;
  final String className;
  final String packageName;
  final String contentDesc;
  final bool checkable;
  final bool checked;
  final bool clickable;
  final bool enabled;
  final bool focusable;
  final bool focused;
  final bool scrollable;
  final bool longClickable;
  final bool password;
  final bool selected;
  final bool visibleToUser;
  final Bounds bounds; // Ex: "[0,0][1080,108]"
  final int drawingOrder;
  final String hint;
  final int displayId;

  // Recursão: um nó pode conter vários nós filhos
  final List<UiNode> children;

  UiNode({
    required this.index,
    required this.text,
    required this.resourceId,
    required this.className,
    required this.packageName,
    required this.contentDesc,
    required this.checkable,
    required this.checked,
    required this.clickable,
    required this.enabled,
    required this.focusable,
    required this.focused,
    required this.scrollable,
    required this.longClickable,
    required this.password,
    required this.selected,
    required this.visibleToUser,
    required this.bounds,
    required this.drawingOrder,
    required this.hint,
    required this.displayId,
    required this.children,
  });

  factory UiNode.fromXmlElement(XmlElement element) {
    return UiNode(
      index: int.tryParse(element.getAttribute('index') ?? '0') ?? 0,
      text: element.getAttribute('text') ?? '',
      resourceId: element.getAttribute('resource-id') ?? '',
      className: element.getAttribute('class') ?? '',
      packageName: element.getAttribute('package') ?? '',
      contentDesc: element.getAttribute('content-desc') ?? '',
      checkable: element.getAttribute('checkable') == 'true',
      checked: element.getAttribute('checked') == 'true',
      clickable: element.getAttribute('clickable') == 'true',
      enabled: element.getAttribute('enabled') == 'true',
      focusable: element.getAttribute('focusable') == 'true',
      focused: element.getAttribute('focused') == 'true',
      scrollable: element.getAttribute('scrollable') == 'true',
      longClickable: element.getAttribute('long-clickable') == 'true',
      password: element.getAttribute('password') == 'true',
      selected: element.getAttribute('selected') == 'true',
      visibleToUser: element.getAttribute('visible-to-user') == 'true',
      bounds: Bounds.fromXmlString(element.getAttribute('bounds') ?? '[0,0][0,0]'),
      drawingOrder:
          int.tryParse(element.getAttribute('drawing-order') ?? '0') ?? 0,
      hint: element.getAttribute('hint') ?? '',
      displayId: int.tryParse(element.getAttribute('display-id') ?? '0') ?? 0,
      children: element.childElements
          .where((e) => e.name.local == 'node')
          .map((e) => UiNode.fromXmlElement(e))
          .toList(),
    );
  }
}

class Bounds {
  final int x1;
  final int y1;
  final int x2;
  final int y2;

  Bounds({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  Map<String, double> get center => {'x': (x2 + x1) / 2, 'y': (y2 + y1) / 2};
  double get width => (x2 - x1).toDouble();
  double get height => (y2 - y1).toDouble();


  factory Bounds.fromXmlString(String xmlString) {
    final Map<String, int> parsedBounds = parseBounds(xmlString);

    return Bounds(
      x1: parsedBounds["x1"]!,
      y1: parsedBounds["y1"]!,
      x2: parsedBounds["x2"]!,
      y2: parsedBounds["y2"]!,
    );
  }
}

Map<String, int> parseBounds(String bounds) {
  final RegExp regExp = RegExp(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]');
  final match = regExp.firstMatch(bounds);

  if (match != null) {
    return {
      "x1": int.parse(match.group(1)!), // Primeiro valor do primeiro par
      "y1": int.parse(match.group(2)!), // Segundo valor do primeiro par
      "x2": int.parse(match.group(3)!), // Primeiro valor do segundo par
      "y2": int.parse(match.group(4)!), // Segundo valor do segundo par
    };
  }

  return {"x1": 0, "y1": 0, "x2": 0, "y2": 0};
}
