"""German grammar, level A2."""
from grammar_lib import point, mc, order

POINTS = [
    point(
        "g2-01", 2, "The dative case",
        "dem (m, n) · der (f) · den + -n (plural)",
        "The dative marks the person who receives something (the indirect object): Ich gebe dem Mann das Buch. "
        "It also follows the prepositions mit, bei, nach, von, zu, aus and seit. Masculine and neuter use dem, "
        "feminine uses der, and the plural uses den with -n on the noun.",
        [("Ich gebe dem Mann das Buch.", "I give the man the book."),
         ("Sie wohnt bei ihrer Tante.", "She lives with her aunt."),
         ("Wir fahren mit dem Bus.", "We travel by bus.")],
        [mc("'with the car' (das Auto)", "mit dem Auto", "mit das Auto", "mit den Auto"),
         mc("'I give the woman a flower.' (die Frau)", "Ich gebe der Frau eine Blume.", "Ich gebe die Frau eine Blume.", "Ich gebe den Frau eine Blume."),
         order("I live with my parents.", "Ich wohne bei meinen Eltern.")],
    ),
    point(
        "g2-02", 2, "Wo? or Wohin? Two-way prepositions",
        "in · an · auf · über · unter · vor · hinter · neben · zwischen",
        "With these prepositions use the dative to say where something is (Wo?) and the accusative to say "
        "where something is going (Wohin?). Compare: Ich bin im Park (dative) and Ich gehe in den Park (accusative).",
        [("Das Buch liegt auf dem Tisch.", "The book is lying on the table."),
         ("Ich lege das Buch auf den Tisch.", "I put the book on the table."),
         ("Wir gehen in die Stadt.", "We are going into the town.")],
        [mc("'The cat is under the table.' (Wo?)", "Die Katze ist unter dem Tisch.", "Die Katze ist unter den Tisch.", "Die Katze ist unter der Tisch."),
         mc("'I am going into the kitchen.' (Wohin?)", "Ich gehe in die Küche.", "Ich gehe in der Küche.", "Ich gehe in dem Küche."),
         order("The book is on the table.", "Das Buch liegt auf dem Tisch.")],
    ),
    point(
        "g2-03", 2, "The perfect tense with haben",
        "haben + … + Partizip II (at the end)",
        "For past events in speech use the perfect tense. Regular verbs form the participle as ge + stem + t "
        "(gemacht), strong verbs as ge + stem + en (gegessen), sometimes with a vowel change. The participle goes "
        "to the end of the sentence.",
        [("Ich habe Deutsch gelernt.", "I have learned German."),
         ("Wir haben Pizza gegessen.", "We ate pizza."),
         ("Hast du das Buch gelesen?", "Have you read the book?")],
        [mc("'I played football.'", "Ich habe Fußball gespielt.", "Ich habe gespielt Fußball.", "Ich bin Fußball gespielt."),
         mc("What is the participle of 'machen'?", "gemacht", "gemachen", "gemachte"),
         order("We ate pizza.", "Wir haben Pizza gegessen.")],
    ),
    point(
        "g2-04", 2, "The perfect tense with sein",
        "sein + … + Partizip II",
        "Verbs of movement (gehen, fahren, kommen, fliegen) and verbs of change of state (aufwachen, werden, "
        "sterben) form the perfect with sein, not haben. Also use sein with bleiben and sein itself.",
        [("Ich bin nach Hause gegangen.", "I went home."),
         ("Sie ist nach Berlin gefahren.", "She travelled to Berlin."),
         ("Wir sind spät aufgestanden.", "We got up late.")],
        [mc("'He went to school.'", "Er ist zur Schule gegangen.", "Er hat zur Schule gegangen.", "Er ist zur Schule gehat."),
         mc("Which verb forms its perfect with sein?", "fahren", "lernen", "kaufen"),
         order("She travelled to Vienna.", "Sie ist nach Wien gefahren.")],
    ),
    point(
        "g2-05", 2, "Subordinate clauses: weil, dass, wenn",
        "…, weil ich müde bin.",
        "After weil (because), dass (that) and wenn (if, when) the conjugated verb goes to the very end of the "
        "clause. The main clause and the subordinate clause are separated by a comma.",
        [("Ich bleibe zu Hause, weil ich krank bin.", "I am staying at home because I am ill."),
         ("Ich glaube, dass er kommt.", "I think that he is coming."),
         ("Wenn es regnet, bleiben wir hier.", "If it rains, we stay here.")],
        [mc("'because I am tired'", "weil ich müde bin", "weil ich bin müde", "weil bin ich müde"),
         mc("'I know that he is here.'", "Ich weiß, dass er hier ist.", "Ich weiß, dass er ist hier.", "Ich weiß, dass ist er hier."),
         order("I stay at home because it is raining.", "Ich bleibe zu Hause, weil es regnet.")],
    ),
    point(
        "g2-06", 2, "Comparing: comparative and superlative",
        "gut – besser – am besten · schnell – schneller – am schnellsten",
        "Add -er for the comparative and am … -sten for the superlative. Use als for 'than' and so … wie for "
        "'as … as'. A few words are irregular: gut – besser – am besten, viel – mehr – am meisten, "
        "gern – lieber – am liebsten.",
        [("Mein Bruder ist älter als ich.", "My brother is older than me."),
         ("Das Auto ist so schnell wie der Zug.", "The car is as fast as the train."),
         ("Ich esse am liebsten Pizza.", "I like eating pizza best.")],
        [mc("'bigger than'", "größer als", "größer wie", "mehr groß als"),
         mc("'the best' (adverb)", "am besten", "am gutesten", "am bester"),
         order("My sister is taller than me.", "Meine Schwester ist größer als ich.")],
    ),
    point(
        "g2-07", 2, "Reflexive verbs",
        "ich wasche mich · du wäschst dich · er freut sich · wir treffen uns",
        "With a reflexive verb the action goes back to the subject. The reflexive pronoun is mich, dich, sich, "
        "uns, euch, sich. Many common verbs are reflexive: sich freuen, sich treffen, sich anziehen, sich setzen.",
        [("Ich wasche mich.", "I wash (myself)."),
         ("Er freut sich auf das Wochenende.", "He is looking forward to the weekend."),
         ("Wir treffen uns um acht Uhr.", "We are meeting at eight o'clock.")],
        [mc("'I am looking forward to the party.'", "Ich freue mich auf die Party.", "Ich freue die Party.", "Ich freue mir auf die Party."),
         mc("'She is getting dressed.' (sich anziehen)", "Sie zieht sich an.", "Sie anzieht sich.", "Sie zieht an sich."),
         order("We are meeting at eight o'clock.", "Wir treffen uns um acht Uhr.")],
    ),
    point(
        "g2-08", 2, "Commands: the imperative",
        "Komm! · Kommt! · Kommen Sie!",
        "For du use the stem: Komm! Mach! For ihr use the ihr-form: Kommt! For Sie use the infinitive followed "
        "by Sie: Kommen Sie! Add bitte to be polite. Separable verbs put the prefix at the end: Steh auf!",
        [("Komm bitte her!", "Please come here!"),
         ("Seid leise!", "Be quiet!"),
         ("Bitte nehmen Sie Platz.", "Please take a seat.")],
        [mc("Tell a friend: 'Come in!'", "Komm herein!", "Kommst herein!", "Kommen herein!"),
         mc("Polite to a stranger: 'Please wait.'", "Warten Sie bitte.", "Wartest du bitte.", "Warte Sie bitte."),
         order("Open the window, please.", "Öffne bitte das Fenster.")],
    ),
    point(
        "g2-09", 2, "Past of sein, haben and modal verbs",
        "ich war · ich hatte · ich konnte · ich musste · ich wollte",
        "For these verbs people use the simple past (Präteritum) even in speech, instead of the perfect. "
        "Learn the forms: war, hatte, konnte, musste, wollte, durfte, sollte.",
        [("Gestern war ich krank.", "Yesterday I was ill."),
         ("Ich hatte keine Zeit.", "I had no time."),
         ("Wir mussten früh aufstehen.", "We had to get up early.")],
        [mc("'I was at home.'", "Ich war zu Hause.", "Ich warst zu Hause.", "Ich waren zu Hause."),
         mc("'She had to work.'", "Sie musste arbeiten.", "Sie müsste arbeiten.", "Sie muss gearbeitet."),
         order("I could not come.", "Ich konnte nicht kommen.")],
    ),
    point(
        "g2-10", 2, "Adjective endings after der, die, das",
        "der alte Mann · die schöne Stadt · das große Haus",
        "After a definite article the adjective ending is almost always -e or -en. Use -e in the nominative "
        "singular (all genders) and for feminine and neuter in the accusative. Everywhere else use -en.",
        [("Der alte Mann sitzt dort.", "The old man is sitting there."),
         ("Ich sehe die schöne Stadt.", "I see the beautiful city."),
         ("Wir kaufen den roten Pullover.", "We buy the red pullover.")],
        [mc("'the big house' (das Haus)", "das große Haus", "das großen Haus", "das großes Haus"),
         mc("'I see the old man.' (accusative)", "Ich sehe den alten Mann.", "Ich sehe den alte Mann.", "Ich sehe der alten Mann."),
         order("The new car is fast.", "Das neue Auto ist schnell.")],
    ),
    point(
        "g2-11", 2, "Pronouns in the accusative and dative",
        "mich · dich · ihn · sie · es · uns · euch  /  mir · dir · ihm · ihr · uns · euch · ihnen",
        "Replace nouns with pronouns. The accusative pronouns are mich, dich, ihn, sie, es, uns, euch, sie. The "
        "dative pronouns are mir, dir, ihm, ihr, ihm, uns, euch, ihnen. Verbs like helfen, gefallen and danken "
        "always take the dative.",
        [("Ich liebe dich.", "I love you."),
         ("Er hilft mir.", "He helps me."),
         ("Kannst du mir das Buch geben?", "Can you give me the book?")],
        [mc("'He helps me.'", "Er hilft mir.", "Er hilft mich.", "Er helft mir."),
         mc("'I see him.'", "Ich sehe ihn.", "Ich sehe er.", "Ich sehe ihm."),
         order("Can you help me?", "Kannst du mir helfen?")],
    ),
    point(
        "g2-12", 2, "Saying when: am, um, im",
        "um + time · am + day · im + month or season",
        "Use um with clock times (um acht Uhr), am with days and parts of the day (am Montag, am Abend), and "
        "im with months and seasons (im Juli, im Sommer).",
        [("Der Film beginnt um acht Uhr.", "The film starts at eight o'clock."),
         ("Am Montag habe ich frei.", "On Monday I am off."),
         ("Im Sommer fahren wir ans Meer.", "In summer we go to the sea.")],
        [mc("'on Monday'", "am Montag", "um Montag", "im Montag"),
         mc("'in July'", "im Juli", "am Juli", "um Juli"),
         order("The lesson starts at nine o'clock.", "Der Unterricht beginnt um neun Uhr.")],
    ),
]
