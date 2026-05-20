import '../domain/memory_models.dart';
import '../domain/contracts/memory_policy.dart';
import '../domain/contracts/memory_writeback_gate.dart' as gate;

class CanonKeeper {
  const CanonKeeper();

  static final _ws = RegExp(r'\s+');
  static final _enNeg = RegExp(
    r"\b(not|no|never|don't|doesn't|didn't|won't|wouldn't|can't|cannot"
    r"|isn't|aren't|wasn't|weren't)\b",
  );
  static final _zhNeg = RegExp(r'(不|没有|不是|并非)');
  static final _sp = RegExp(r'^(.+?)\s*(?:is|是|=)\s*(.+)$');
  static final _num = RegExp(r'\d+\.?\d*');

  List<String> checkConsistency(
    gate.ProposedWrite write,
    List<StoryMemoryChunk> canonFacts,
  ) {
    final issues = <String>[];
    final w = _norm(write.content);
    for (final f in canonFacts) {
      if (f.tier != MemoryTier.canon) continue;
      final c = _norm(f.content);
      for (final fn in [_negConflict, _spConflict, _numConflict]) {
        final r = fn(w, c);
        if (r != null) issues.add(r);
      }
    }
    return issues;
  }

  gate.CanonKeeper asWritebackCanonKeeper(List<StoryMemoryChunk> canonFacts) =>
      (write) => checkConsistency(write, canonFacts);

  // -- private helpers ----------------------------------------------------------

  String _norm(String s) => s.toLowerCase().replaceAll(_ws, ' ').trim();

  String _stripNeg(String s) =>
      _norm(s.replaceAll(_enNeg, '').replaceAll(_zhNeg, ''));

  bool _hasNeg(String s) => _enNeg.hasMatch(s) || _zhNeg.hasMatch(s);

  String? _negConflict(String a, String b) {
    if (_hasNeg(a) == _hasNeg(b)) return null;
    final sa = _stripNeg(a), sb = _stripNeg(b);
    if (sa.isEmpty || sa != sb) return null;
    return 'Negation conflict: ${_hasNeg(a) ? 'write' : 'canon'} negated';
  }

  String? _spConflict(String a, String b) {
    final ma = _sp.firstMatch(a), mb = _sp.firstMatch(b);
    if (ma == null || mb == null) return null;
    final sA = ma.group(1)!.trim(), sB = mb.group(1)!.trim();
    if (sA != sB) return null;
    final vA = ma.group(2)!.trim(), vB = mb.group(2)!.trim();
    if (vA == vB) return null;
    return 'Predicate conflict: "$sA" — "$vA" vs "$vB"';
  }

  String? _numConflict(String a, String b) {
    final ma = a.replaceAll(_num, '#'), mb = b.replaceAll(_num, '#');
    if (ma != mb) return null;
    final na = _num.allMatches(a).map((m) => m.group(0)!).toList();
    final nb = _num.allMatches(b).map((m) => m.group(0)!).toList();
    if (na.length != nb.length) return null;
    for (var i = 0; i < na.length; i++) {
      if (na[i] != nb[i]) return 'Numeric conflict: ${na[i]} vs ${nb[i]}';
    }
    return null;
  }
}
