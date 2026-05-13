class WorkbenchTextHelpers {
  const WorkbenchTextHelpers._();

  static String collapseWhitespace(String value) {
    final buffer = StringBuffer();
    var previousWasWhitespace = false;
    for (final codeUnit in value.codeUnits) {
      if (isWhitespaceCodeUnit(codeUnit)) {
        if (!previousWasWhitespace) {
          buffer.write(' ');
        }
        previousWasWhitespace = true;
      } else {
        buffer.writeCharCode(codeUnit);
        previousWasWhitespace = false;
      }
    }
    return buffer.toString();
  }

  static String removeWhitespace(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      if (!isWhitespaceCodeUnit(codeUnit)) {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  static bool isWhitespaceCodeUnit(int codeUnit) {
    return codeUnit == 0x20 ||
        codeUnit == 0x09 ||
        codeUnit == 0x0A ||
        codeUnit == 0x0D ||
        codeUnit == 0x0B ||
        codeUnit == 0x0C;
  }
}
