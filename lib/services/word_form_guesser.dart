/// Derives *candidate* base forms for an inflected English word.
///
/// The bundled ECDICT extract has no `exchange` column, so the relation cannot
/// be read from data. Instead this class only proposes rule-based candidates
/// (plural / third person, past tense, participle, comparative, superlative) and
/// the caller must confirm each candidate against the dictionary before showing
/// it. Nothing is ever merged automatically: a linked base form is a *hint*
/// about the same word, not a claim that two user entries are the same entry.
library;

/// How a candidate base form relates to the word the user typed.
///
/// An enum, not a sentence: the guesser is a pure service and must not pick a
/// language. `lib/l10n/enum_labels.dart` owns the display names.
enum WordFormRelation {
  pluralThirdPerson,
  pastParticiple,
  presentParticiple,
  comparative,
  superlative,
}

class WordFormCandidate {
  const WordFormCandidate({required this.lemma, required this.relation});

  final String lemma;

  /// The grammatical relation this candidate would have.
  final WordFormRelation relation;
}

class WordFormGuesser {
  const WordFormGuesser._();

  /// At most this many candidates are returned; the caller still has to verify
  /// them against real dictionary rows.
  static const int maxCandidates = 6;

  static List<WordFormCandidate> candidates(String input) {
    final String word = input.trim().toLowerCase();
    if (word.length < 3 || !RegExp(r'^[a-z]+$').hasMatch(word)) {
      return const <WordFormCandidate>[];
    }
    final Map<String, WordFormRelation> found = <String, WordFormRelation>{};
    void add(String? lemma, WordFormRelation relation) {
      if (lemma == null || lemma.length < 2 || lemma == word) return;
      found.putIfAbsent(lemma, () => relation);
    }

    if (word.endsWith('ies') && word.length > 4) {
      add(
        '${word.substring(0, word.length - 3)}y',
        WordFormRelation.pluralThirdPerson,
      );
    }
    if (word.endsWith('ied') && word.length > 4) {
      add(
        '${word.substring(0, word.length - 3)}y',
        WordFormRelation.pastParticiple,
      );
    }
    if (word.endsWith('es') && word.length > 3) {
      add(
        word.substring(0, word.length - 2),
        WordFormRelation.pluralThirdPerson,
      );
    }
    if (word.endsWith('s') &&
        !word.endsWith('ss') &&
        !word.endsWith('us') &&
        !word.endsWith('is') &&
        word.length > 3) {
      add(
        word.substring(0, word.length - 1),
        WordFormRelation.pluralThirdPerson,
      );
    }
    if (word.endsWith('ed') && word.length > 4) {
      final String stem = word.substring(0, word.length - 2);
      add(stem, WordFormRelation.pastParticiple);
      add('${stem}e', WordFormRelation.pastParticiple);
      if (_isDoubled(stem)) {
        add(
          stem.substring(0, stem.length - 1),
          WordFormRelation.pastParticiple,
        );
      }
    }
    if (word.endsWith('ing') && word.length > 5) {
      final String stem = word.substring(0, word.length - 3);
      add(stem, WordFormRelation.presentParticiple);
      add('${stem}e', WordFormRelation.presentParticiple);
      if (_isDoubled(stem)) {
        add(
          stem.substring(0, stem.length - 1),
          WordFormRelation.presentParticiple,
        );
      }
    }
    if (word.endsWith('ier') && word.length > 4) {
      add(
        '${word.substring(0, word.length - 3)}y',
        WordFormRelation.comparative,
      );
    }
    if (word.endsWith('iest') && word.length > 5) {
      add(
        '${word.substring(0, word.length - 4)}y',
        WordFormRelation.superlative,
      );
    }
    if (word.endsWith('est') && word.length > 4) {
      final String stem = word.substring(0, word.length - 3);
      add(stem, WordFormRelation.superlative);
      add('${stem}e', WordFormRelation.superlative);
    }
    if (word.endsWith('er') && word.length > 4) {
      final String stem = word.substring(0, word.length - 2);
      add(stem, WordFormRelation.comparative);
      add('${stem}e', WordFormRelation.comparative);
      if (_isDoubled(stem)) {
        add(stem.substring(0, stem.length - 1), WordFormRelation.comparative);
      }
    }
    return <WordFormCandidate>[
      for (final MapEntry<String, WordFormRelation> entry in found.entries)
        WordFormCandidate(lemma: entry.key, relation: entry.value),
    ].take(maxCandidates).toList();
  }

  /// `stopp` → true, `play` → false: a final doubled consonant usually means the
  /// last letter has to be dropped before adding -ed / -ing / -er.
  static bool _isDoubled(String stem) {
    if (stem.length < 2) return false;
    final String last = stem[stem.length - 1];
    if (last != stem[stem.length - 2]) return false;
    return !'aeiou'.contains(last) && !'lsz'.contains(last);
  }
}
