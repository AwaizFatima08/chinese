"""German grammar, level B1."""
from grammar_lib import point, mc, order

POINTS = [
    point(
        "g3-01", 3, "The simple past (Präteritum)",
        "regular: stem + te · strong verbs: new stem (gehen → ging)",
        "In written German, stories and news the simple past replaces the perfect tense. Regular verbs add -te: "
        "er machte, sie wohnte. Strong verbs change their stem: er ging, sie kam, ich sah. Learn the stems with "
        "each strong verb.",
        [("Gestern regnete es den ganzen Tag.", "Yesterday it rained all day."),
         ("Sie kam spät an.", "She arrived late."),
         ("Ich sah einen Film.", "I saw a film.")],
        [mc("Simple past of 'machen' (er)", "er machte", "er mache", "er gemacht"),
         mc("Simple past of 'gehen' (sie)", "sie ging", "sie gehte", "sie ginge"),
         order("He lived in Munich.", "Er wohnte in München.")],
    ),
    point(
        "g3-02", 3, "Adjective endings with ein-words and without article",
        "ein guter Freund · ein gutes Buch · gute Freunde",
        "After ein, mein or kein the masculine nominative needs -er (ein guter Mann) and the neuter nominative "
        "and accusative need -es (ein gutes Buch). Without an article the adjective takes the ending the article "
        "would have: heiße Suppe, kaltes Wasser.",
        [("Ein guter Freund hilft immer.", "A good friend always helps."),
         ("Das ist ein altes Haus.", "That is an old house."),
         ("Heiße Suppe schmeckt gut.", "Hot soup tastes good.")],
        [mc("'a good friend' (masculine, nominative)", "ein guter Freund", "ein gute Freund", "ein gutes Freund"),
         mc("'a new book' (das Buch)", "ein neues Buch", "ein neue Buch", "ein neuer Buch"),
         order("I have a small dog.", "Ich habe einen kleinen Hund.")],
    ),
    point(
        "g3-03", 3, "Relative clauses",
        "…, der / die / das / die … (verb at the end)",
        "A relative clause adds information about a noun. The relative pronoun takes its gender and number from "
        "that noun and its case from its role in the clause. The verb goes to the end and the clause is set off "
        "by commas.",
        [("Der Mann, der dort steht, ist mein Lehrer.", "The man who is standing there is my teacher."),
         ("Das Buch, das ich lese, ist spannend.", "The book that I am reading is exciting."),
         ("Die Frau, die ich kenne, wohnt hier.", "The woman whom I know lives here.")],
        [mc("'The woman who lives here' (die Frau)", "Die Frau, die hier wohnt", "Die Frau, der hier wohnt", "Die Frau, das hier wohnt"),
         mc("Complete: 'Das ist der Film, ___ ich gestern gesehen habe.'", "den", "der", "dem"),
         order("The book that I am reading is exciting.", "Das Buch, das ich lese, ist spannend.")],
    ),
    point(
        "g3-04", 3, "The passive voice (present)",
        "werden + Partizip II",
        "Use the passive when the action matters more than who does it. Form it with werden and the past "
        "participle at the end. The thing acted on becomes the subject: Das Auto wird repariert.",
        [("Hier wird Deutsch gesprochen.", "German is spoken here."),
         ("Die Tür wird geöffnet.", "The door is opened."),
         ("Das Essen wird gekocht.", "The food is being cooked.")],
        [mc("'German is spoken here.'", "Hier wird Deutsch gesprochen.", "Hier ist Deutsch gesprochen.", "Hier wird Deutsch sprechen."),
         mc("Which verb forms the passive?", "werden", "sein", "haben"),
         order("The letter is written.", "Der Brief wird geschrieben.")],
    ),
    point(
        "g3-05", 3, "Konjunktiv II: wishes and polite requests",
        "ich hätte · ich wäre · ich würde + infinitive · ich könnte",
        "The Konjunktiv II expresses wishes, polite requests and unreal situations. Use hätte, wäre, könnte, or "
        "würde + infinitive. For an unreal condition use wenn with the Konjunktiv II: Wenn ich Zeit hätte, würde "
        "ich reisen.",
        [("Ich hätte gern einen Kaffee.", "I would like a coffee."),
         ("Könntest du mir helfen?", "Could you help me?"),
         ("Wenn ich Zeit hätte, würde ich reisen.", "If I had time I would travel.")],
        [mc("'I would like to travel.'", "Ich würde gern reisen.", "Ich werde gern reisen.", "Ich wurde gern reisen."),
         mc("Which clause is an unreal condition ('If I had time …')?", "Wenn ich Zeit hätte, …", "Wenn ich Zeit habe, …", "Wenn ich Zeit hatte, …"),
         order("I would like a coffee.", "Ich hätte gern einen Kaffee.")],
    ),
    point(
        "g3-06", 3, "The infinitive with zu",
        "…, (um) … zu + infinitive",
        "After many verbs and expressions the second verb is an infinitive with zu at the end: Ich versuche, "
        "jeden Tag zu lernen. With separable verbs zu goes between prefix and verb: aufzustehen. Use um … zu to "
        "express a purpose.",
        [("Ich versuche, jeden Tag zu lernen.", "I try to study every day."),
         ("Es ist wichtig, genug zu schlafen.", "It is important to sleep enough."),
         ("Er geht in die Stadt, um einzukaufen.", "He goes into town in order to shop.")],
        [mc("'I plan to travel.' (vorhaben)", "Ich habe vor, zu reisen.", "Ich habe vor, reisen.", "Ich habe vor, zu reist."),
         mc("Which sentence is correct?", "Sie fängt an, zu arbeiten.", "Sie fängt an, arbeiten.", "Sie fängt an zu arbeitet."),
         order("It is important to sleep enough.", "Es ist wichtig, genug zu schlafen.")],
    ),
    point(
        "g3-07", 3, "The genitive case",
        "des Mannes · der Frau · des Kindes · der Kinder",
        "The genitive shows possession: das Auto meines Vaters. Masculine and neuter nouns add -(e)s and use "
        "des; feminine and plural use der. The prepositions wegen, trotz, während and innerhalb take the genitive.",
        [("Das ist das Auto meines Vaters.", "That is my father's car."),
         ("Wegen des Wetters bleiben wir hier.", "Because of the weather we are staying here."),
         ("Das Haus der Eltern ist groß.", "The parents' house is big.")],
        [mc("'the car of my father'", "das Auto meines Vaters", "das Auto mein Vater", "das Auto meinem Vater"),
         mc("'because of the rain'", "wegen des Regens", "wegen der Regen", "wegen den Regen"),
         order("That is the book of the teacher.", "Das ist das Buch des Lehrers.")],
    ),
    point(
        "g3-08", 3, "Verbs with fixed prepositions",
        "warten auf + A · denken an + A · sich interessieren für + A · träumen von + D",
        "Many German verbs always go with one preposition, and the preposition decides the case. Learn them "
        "together: warten auf (accusative), sich freuen auf, denken an, sich interessieren für, sprechen über, "
        "träumen von (dative).",
        [("Ich warte auf den Bus.", "I am waiting for the bus."),
         ("Sie denkt an ihre Familie.", "She is thinking of her family."),
         ("Er interessiert sich für Musik.", "He is interested in music.")],
        [mc("'I am waiting for you.'", "Ich warte auf dich.", "Ich warte für dich.", "Ich warte an dich."),
         mc("'She is interested in art.'", "Sie interessiert sich für Kunst.", "Sie interessiert sich an Kunst.", "Sie interessiert sich über Kunst."),
         order("We are talking about the film.", "Wir sprechen über den Film.")],
    ),
    point(
        "g3-09", 3, "The past perfect (Plusquamperfekt)",
        "hatte / war + Partizip II",
        "Use the past perfect for something that happened before another past event. Form it with hatte or war "
        "and the participle. It often appears with nachdem (after) and als (when): Nachdem ich gegessen hatte, "
        "ging ich spazieren.",
        [("Nachdem ich gegessen hatte, ging ich spazieren.", "After I had eaten, I went for a walk."),
         ("Er war schon gegangen, als ich ankam.", "He had already left when I arrived."),
         ("Wir hatten den Zug verpasst.", "We had missed the train.")],
        [mc("'I had worked.'", "Ich hatte gearbeitet.", "Ich habe gearbeitet.", "Ich war gearbeitet."),
         mc("Which participle needs 'war' in the past perfect?", "gegangen", "gelernt", "gekauft"),
         order("She had already left.", "Sie war schon gegangen.")],
    ),
    point(
        "g3-10", 3, "The future with werden",
        "werden + infinitive (at the end)",
        "The future tense uses werden and an infinitive at the end. Often the present tense with a time word is "
        "enough: Morgen fahre ich nach Berlin. Use werden for predictions, promises and plans.",
        [("Ich werde nächstes Jahr in Berlin wohnen.", "I will live in Berlin next year."),
         ("Es wird morgen regnen.", "It will rain tomorrow."),
         ("Wirst du kommen?", "Will you come?")],
        [mc("'It will rain.'", "Es wird regnen.", "Es wurde regnen.", "Es werde regnen."),
         mc("'We will travel.'", "Wir werden reisen.", "Wir werden gereist.", "Wir wurden reisen."),
         order("I will call you tomorrow.", "Ich werde dich morgen anrufen.")],
    ),
    point(
        "g3-11", 3, "Connectors: obwohl, damit, um … zu",
        "obwohl + clause · damit + clause · um … zu + infinitive",
        "obwohl (although) and damit (so that) introduce subordinate clauses with the verb at the end. Use um … "
        "zu with an infinitive when the subject is the same in both parts, and damit when the subjects differ.",
        [("Obwohl ich müde bin, arbeite ich weiter.", "Although I am tired, I keep working."),
         ("Ich spare Geld, damit wir reisen können.", "I am saving money so that we can travel."),
         ("Ich lerne Deutsch, um in Berlin zu arbeiten.", "I am learning German in order to work in Berlin.")],
        [mc("'Although it is cold, we go out.'", "Obwohl es kalt ist, gehen wir raus.", "Obwohl es ist kalt, gehen wir raus.", "Obwohl es kalt ist, wir gehen raus."),
         mc("Which connector is used for the same subject ('in order to')?", "um … zu", "damit", "weil"),
         order("I am learning German in order to work in Vienna.", "Ich lerne Deutsch, um in Wien zu arbeiten.")],
    ),
    point(
        "g3-12", 3, "Indirect questions",
        "Ich weiß nicht, ob … / wo … / wann … (verb at the end)",
        "When a question is part of a longer sentence, the verb moves to the end. Yes/no questions become ob "
        "clauses, and question words stay in front of the clause: Ich weiß nicht, wo er wohnt.",
        [("Ich weiß nicht, wo er wohnt.", "I do not know where he lives."),
         ("Kannst du mir sagen, wie spät es ist?", "Can you tell me what time it is?"),
         ("Ich frage mich, ob er kommt.", "I wonder whether he is coming.")],
        [mc("'I do not know where she is.'", "Ich weiß nicht, wo sie ist.", "Ich weiß nicht, wo ist sie.", "Ich weiß nicht, sie ist wo."),
         mc("Which word introduces an indirect yes/no question?", "ob", "dass", "weil"),
         order("Can you tell me where the station is?", "Kannst du mir sagen, wo der Bahnhof ist?")],
    ),
]
