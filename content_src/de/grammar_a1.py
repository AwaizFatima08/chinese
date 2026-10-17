"""German grammar, level A1. See grammar_lib.py for the helpers."""
from grammar_lib import point, mc, order

POINTS = [
    point(
        "g1-01", 1, "The verb sein (to be)",
        "ich bin · du bist · er/sie/es ist · wir sind · ihr seid · sie/Sie sind",
        "sein is the most important irregular verb. Use it to say who or what you are, "
        "where you come from and how you feel. It does not follow the regular endings.",
        [("Ich bin Student.", "I am a student."),
         ("Wo bist du?", "Where are you?"),
         ("Wir sind aus Pakistan.", "We are from Pakistan.")],
        [mc("How do you say 'You are tired' to a friend?", "Du bist müde.", "Du ist müde.", "Du bin müde."),
         mc("Choose the correct sentence: 'They are at home.'", "Sie sind zu Hause.", "Sie ist zu Hause.", "Sie seid zu Hause."),
         order("We are happy.", "Wir sind glücklich.")],
    ),
    point(
        "g1-02", 1, "Regular verbs in the present tense",
        "stem + e / st / t / en / t / en",
        "Take the infinitive, remove -en and add the ending for the person: ich lerne, du lernst, "
        "er lernt, wir lernen, ihr lernt, sie lernen. The same form is used for 'I learn' and 'I am learning'.",
        [("Ich wohne in Berlin.", "I live in Berlin."),
         ("Du lernst Deutsch.", "You are learning German."),
         ("Wir machen Hausaufgaben.", "We are doing homework.")],
        [mc("'He lives in Hamburg.'", "Er wohnt in Hamburg.", "Er wohne in Hamburg.", "Er wohnst in Hamburg."),
         mc("'You (informal) play football.'", "Du spielst Fußball.", "Du spielt Fußball.", "Du spiele Fußball."),
         order("She plays tennis.", "Sie spielt Tennis.")],
    ),
    point(
        "g1-03", 1, "Gender of nouns: der, die, das",
        "der (masculine) · die (feminine) · das (neuter)",
        "Every German noun has a gender, shown by its article. There are few reliable rules, so "
        "learn each noun together with its article. In this app der is blue, die is red and das is green.",
        [("Der Mann liest ein Buch.", "The man is reading a book."),
         ("Die Frau trinkt Tee.", "The woman is drinking tea."),
         ("Das Kind spielt im Garten.", "The child is playing in the garden.")],
        [mc("Which article goes with 'Frau'?", "die", "der", "das"),
         mc("Choose the correct sentence: 'The child is small.'", "Das Kind ist klein.", "Der Kind ist klein.", "Die Kind ist klein."),
         order("The man is old.", "Der Mann ist alt.")],
    ),
    point(
        "g1-04", 1, "Plural of nouns",
        "die + plural form (-e, -en, -n, -er, umlaut, or no change)",
        "In the plural the article is always die. The noun changes in different ways, so learn the "
        "plural with each noun. The app shows it under the word.",
        [("Die Kinder spielen.", "The children are playing."),
         ("Ich habe zwei Brüder.", "I have two brothers."),
         ("Die Bücher sind neu.", "The books are new.")],
        [mc("What is the plural of 'das Kind'?", "die Kinder", "die Kinden", "die Kinds"),
         mc("Which article is used for every plural noun?", "die", "der", "das"),
         order("The books are new.", "Die Bücher sind neu.")],
    ),
    point(
        "g1-05", 1, "The accusative: direct objects",
        "den / einen for masculine · die, das, eine, ein stay the same",
        "The thing or person that receives the action is in the accusative case. Only masculine words "
        "change: der becomes den and ein becomes einen. Feminine, neuter and plural stay as they are.",
        [("Ich sehe den Mann.", "I see the man."),
         ("Sie kauft einen Apfel.", "She buys an apple."),
         ("Wir haben ein Auto.", "We have a car.")],
        [mc("'I am buying a table.' (der Tisch)", "Ich kaufe einen Tisch.", "Ich kaufe ein Tisch.", "Ich kaufe einem Tisch."),
         mc("Which sentence is correct?", "Er liest den Brief.", "Er liest der Brief.", "Er liest dem Brief."),
         order("I see the dog.", "Ich sehe den Hund.")],
    ),
    point(
        "g1-06", 1, "The verb comes second",
        "Position 1 + verb + the rest",
        "In a statement the conjugated verb is always in second position. Position one can be the subject "
        "or a time or place. If you start with something else, the subject moves behind the verb.",
        [("Ich lerne heute Deutsch.", "I am learning German today."),
         ("Heute lerne ich Deutsch.", "Today I am learning German."),
         ("Im Park spielen die Kinder.", "The children are playing in the park.")],
        [mc("'Today I work.'", "Heute arbeite ich.", "Heute ich arbeite.", "Ich heute arbeite."),
         mc("Which sentence has the verb in the right place?", "Morgen fahren wir nach Berlin.", "Morgen wir fahren nach Berlin.", "Morgen nach Berlin fahren wir."),
         order("Tomorrow we are travelling.", "Morgen fahren wir.")],
    ),
    point(
        "g1-07", 1, "Asking questions",
        "Verb + subject?  ·  Question word + verb + subject?",
        "Yes/no questions start with the verb. Questions with a question word (wer, was, wo, wann, wie, "
        "warum) start with that word and the verb follows straight after.",
        [("Sprichst du Deutsch?", "Do you speak German?"),
         ("Wo wohnst du?", "Where do you live?"),
         ("Wann kommt der Bus?", "When does the bus come?")],
        [mc("'Do you live here?'", "Wohnst du hier?", "Wohnt du hier?", "Wohne du hier?"),
         mc("'Where is the station?'", "Wo ist der Bahnhof?", "Wo der Bahnhof ist?", "Ist wo der Bahnhof?"),
         order("What are you doing?", "Was machst du?")],
    ),
    point(
        "g1-08", 1, "Saying no: nicht and kein",
        "kein + noun  ·  nicht + verb / adjective",
        "Use kein to negate a noun that has ein or no article: Ich habe kein Auto. Use nicht for everything "
        "else: verbs, adjectives, and nouns with der/die/das. Kein takes the same endings as ein.",
        [("Ich habe keine Zeit.", "I have no time."),
         ("Er ist nicht müde.", "He is not tired."),
         ("Wir gehen nicht ins Kino.", "We are not going to the cinema.")],
        [mc("'I do not have a brother.'", "Ich habe keinen Bruder.", "Ich habe nicht Bruder.", "Ich habe kein Bruder."),
         mc("'The soup is not hot.'", "Die Suppe ist nicht heiß.", "Die Suppe ist keine heiß.", "Die Suppe nicht ist heiß."),
         order("I have no time.", "Ich habe keine Zeit.")],
    ),
    point(
        "g1-09", 1, "Possessive words: mein, dein, …",
        "mein · dein · sein · ihr · unser · euer · ihr",
        "These words show who owns something. They take the same endings as ein: mein Vater, meine Mutter, "
        "mein Kind. In the accusative masculine you need -en: Ich liebe meinen Hund.",
        [("Das ist meine Schwester.", "That is my sister."),
         ("Wo ist dein Handy?", "Where is your phone?"),
         ("Ich liebe meinen Hund.", "I love my dog.")],
        [mc("'my mother'", "meine Mutter", "mein Mutter", "meiner Mutter"),
         mc("'I see your brother.' (informal, der Bruder)", "Ich sehe deinen Bruder.", "Ich sehe dein Bruder.", "Ich sehe deine Bruder."),
         order("This is our house.", "Das ist unser Haus.")],
    ),
    point(
        "g1-10", 1, "Modal verbs: können, müssen, wollen, dürfen",
        "modal verb (position 2) … infinitive (at the end)",
        "A modal verb is conjugated and stands in second position. The main verb goes to the end of the "
        "sentence in the infinitive. können = can, müssen = must, wollen = want to, dürfen = may.",
        [("Ich kann gut schwimmen.", "I can swim well."),
         ("Wir müssen heute arbeiten.", "We have to work today."),
         ("Du darfst hier nicht parken.", "You may not park here.")],
        [mc("'I want to go home.'", "Ich will nach Hause gehen.", "Ich will gehen nach Hause.", "Ich will nach Hause gehe."),
         mc("'She can speak German.'", "Sie kann Deutsch sprechen.", "Sie kann sprechen Deutsch.", "Sie können Deutsch sprechen."),
         order("We have to learn.", "Wir müssen lernen.")],
    ),
    point(
        "g1-11", 1, "Separable verbs",
        "Er steht um sieben Uhr auf.",
        "Many verbs have a prefix that separates in a main clause and goes to the end: aufstehen → ich "
        "stehe auf, anrufen → ich rufe an, einkaufen → ich kaufe ein. In the infinitive they stay together.",
        [("Ich stehe um sieben Uhr auf.", "I get up at seven o'clock."),
         ("Er ruft mich an.", "He calls me."),
         ("Wir kaufen heute ein.", "We are shopping today.")],
        [mc("'She calls her friend.' (anrufen)", "Sie ruft ihre Freundin an.", "Sie anruft ihre Freundin.", "Sie ruft an ihre Freundin."),
         mc("'I get up at six.' (aufstehen)", "Ich stehe um sechs auf.", "Ich aufstehe um sechs.", "Ich stehe auf um sechs."),
         order("The train arrives at eight o'clock.", "Der Zug kommt um acht Uhr an.")],
    ),
    point(
        "g1-12", 1, "Polite requests with möchte",
        "Ich möchte … (, bitte).",
        "möchte (would like) is the polite way to say what you want in shops, cafés and offices. Add "
        "bitte. It works like a modal verb: the thing wanted or the infinitive follows.",
        [("Ich möchte einen Kaffee, bitte.", "I would like a coffee, please."),
         ("Wir möchten zahlen.", "We would like to pay."),
         ("Möchten Sie Tee oder Kaffee?", "Would you like tea or coffee?")],
        [mc("Order a tea politely.", "Ich möchte einen Tee, bitte.", "Ich will Tee.", "Gib mir Tee."),
         mc("What does 'Möchten Sie …?' mean?", "Would you like …?", "Do you have …?", "Can you give …?"),
         order("I would like a water.", "Ich möchte ein Wasser.")],
    ),
]
