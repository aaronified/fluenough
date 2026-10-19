import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/grading/meaning_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool eq(String given, String expected) => meaningsEqual(given, expected);

  test('owner examples', () {
    expect(eq('there is no time', "There's no time."), isTrue);
    expect(eq('how are you', 'How are you? (respectful)'), isTrue);
    expect(eq('can you repeat that', 'Please say that again.'), isFalse);
  });

  test('rule 1: case, whitespace, punctuation', () {
    expect(eq('  HELLO,   there! ', 'hello there'), isTrue);
    expect(eq('"hello"', 'Hello.'), isTrue);
  });

  test('rule 2: contractions, straight and curly', () {
    for (final (c, e) in [
      ("it's cold", 'it is cold'),
      ("I'm here", 'I am here'),
      ("you're late", 'you are late'),
      ("we're in", 'we are in'),
      ("they're in", 'they are in'),
      ("he's in", 'he is in'),
      ("she's in", 'she is in'),
      ("that's it", 'that is it'),
      ("what's this", 'what is this'),
      ("who's there", 'who is there'),
      ("where's it", 'where is it'),
      ("let's go", 'let us go'),
      ("don't go", 'do not go'),
      ("doesn't go", 'does not go'),
      ("didn't go", 'did not go'),
      ("isn't", 'is not'),
      ("aren't", 'are not'),
      ("wasn't", 'was not'),
      ("weren't", 'were not'),
      ("haven't", 'have not'),
      ("hasn't", 'has not'),
      ("hadn't", 'had not'),
      ("can't", 'cannot'),
      ("can't", 'can not'),
      ("couldn't", 'could not'),
      ("won't", 'will not'),
      ("wouldn't", 'would not'),
      ("shouldn't", 'should not'),
      ("I'll go", 'I will go'),
      ("you'll go", 'you will go'),
      ("we'll go", 'we will go'),
      ("they'll go", 'they will go'),
      ("I've gone", 'I have gone'),
      ("you've gone", 'you have gone'),
      ("we've gone", 'we have gone'),
      ("they've gone", 'they have gone'),
      ("I'd go", 'I would go'),
    ]) {
      expect(eq(c, e), isTrue, reason: '$c / $e');
      expect(eq(e, c), isTrue, reason: '$e / $c');
    }
    expect(eq('there’s no time', 'there is no time'), isTrue);
    expect(eq("there's no time", 'There’s no time'), isTrue);
  });

  test('rule 3: bracketed qualifier is optional', () {
    expect(eq('how are you', 'How are you? (respectful)'), isTrue);
    expect(eq('how are you respectful', 'How are you? (respectful)'), isFalse);
    expect(eq('how are you (respectful)', 'How are you?'), isTrue);
  });

  test('rule 4: each ; meaning on its own', () {
    expect(eq('one book', 'a book; one book'), isTrue);
    expect(eq('a book', 'a book; one book'), isTrue);
    expect(eq('two books', 'a book; one book'), isFalse);
  });

  test('rule 5: leading to is optional both ways', () {
    expect(eq('say', 'to say'), isTrue);
    expect(eq('to say', 'say'), isTrue);
    expect(eq('to', 'to say'), isFalse);
  });

  test('ok, okay, o.k. are one word', () {
    expect(eq('ok', 'okay'), isTrue);
    expect(eq('okay', 'ok'), isTrue);
    expect(eq('o.k.', 'okay'), isTrue);
    expect(eq('OK, thanks', 'okay thanks'), isTrue);
    expect(eq('okay thanks', 'O.K., thanks'), isTrue);
  });

  test('please is optional anywhere, both sides', () {
    const card = "I'm sorry; excuse me.";
    expect(eq('please excuse me', card), isTrue);
    expect(eq('excuse me', card), isTrue);
    expect(eq('i am sorry', card), isTrue);
    expect(eq('say that again', 'Please say that again.'), isTrue);
    expect(eq('please say that again', 'say that again'), isTrue);
    expect(eq('say that please again', 'say that again'), isTrue);
  });

  group('AnswerGrader(meaning: true)', () {
    const grader = AnswerGrader(meaning: true);

    test('rule matches are exact, not near misses', () {
      expect(
        grader.grade('there is no time', "There's no time.").outcome,
        AnswerOutcome.exact,
      );
      expect(
        grader.grade('how are you', 'How are you? (respectful)').outcome,
        AnswerOutcome.exact,
      );
      final g = grader.grade(
        'one book',
        'a book; one book',
        alternates: ['the book'],
      );
      expect(g.outcome, AnswerOutcome.exact);
      expect(g.matched, 'a book; one book');
    });

    test('paraphrase stays wrong', () {
      expect(
        grader.grade('can you repeat that', 'Please say that again.').outcome,
        AnswerOutcome.wrong,
      );
    });

    test('a typo after the rules is still a near miss', () {
      expect(
        grader.grade('there is no tiem', "There's no time.").outcome,
        AnswerOutcome.closeTypo,
      );
    });

    test('without meaning, contractions are not expanded', () {
      expect(
        const AnswerGrader()
            .grade('how are you', 'How are you? (respectful)')
            .outcome,
        isNot(AnswerOutcome.exact),
      );
    });
  });
}
