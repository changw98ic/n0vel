import 'dart:io';

/// Fixed malformed subprocess used only to prove that the coordinator spends
/// access before rejecting a non-V2 response. It never reads its arguments.
void main(List<String> arguments) {
  stdout.write('{}');
}
