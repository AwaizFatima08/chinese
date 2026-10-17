"""German grammar, level B2."""
from grammar_lib import point, mc, order

POINTS = [
    point(
        "g4-01", 4, "The passive with modal verbs, and the state passive",
        "modal + Partizip II + werden · sein + Partizip II",
        "With a modal verb the passive infinitive is Partizip II + werden at the end: Das Formular muss "
        "ausgefüllt werden. The state passive (sein + participle) describes the result, not the action: Der "
        "Laden ist geschlossen.",
        [("Das Formular muss ausgefüllt werden.", "The form has to be filled in."),
         ("Das Problem kann gelöst werden.", "The problem can be solved."),
         ("Der Laden ist geschlossen.", "The shop is closed.")],
        [mc("'The door must be closed.'", "Die Tür muss geschlossen werden.", "Die Tür muss werden geschlossen.", "Die Tür muss geschlossen wird."),
         mc("Which sentence describes a state, not an action?", "Das Fenster ist geöffnet.", "Das Fenster wird geöffnet.", "Das Fenster wurde geöffnet."),
         order("The problem can be solved.", "Das Problem kann gelöst werden.")],
    ),
    point(
        "g4-02", 4, "Konjunktiv II in the past",
        "hätte / wäre + Partizip II",
        "To talk about something that did not happen, use hätte or wäre with the participle. Verbs that take "
        "sein in the perfect use wäre: Wenn ich das gewusst hätte, wäre ich gekommen.",
        [("Wenn ich das gewusst hätte, wäre ich gekommen.", "If I had known that, I would have come."),
         ("Ich hätte gern mehr Zeit gehabt.", "I would have liked to have more time."),
         ("Er wäre gern länger geblieben.", "He would have liked to stay longer.")],
        [mc("'If I had had time, I would have called.'", "Wenn ich Zeit gehabt hätte, hätte ich angerufen.", "Wenn ich Zeit gehabt habe, hätte ich angerufen.", "Wenn ich Zeit hätte gehabt, habe ich angerufen."),
         mc("Which auxiliary goes with 'gekommen' in this construction?", "wäre", "hätte", "würde"),
         order("I would have liked to stay.", "Ich wäre gern geblieben.")],
    ),
    point(
        "g4-03", 4, "Reported speech: Konjunktiv I",
        "Er sagt, er sei krank. · Sie sagt, sie habe Zeit.",
        "Reported speech in news and formal writing uses the Konjunktiv I: sei, habe, komme, gehe. If the form "
        "looks like the ordinary present, use the Konjunktiv II instead: Sie sagen, sie hätten keine Zeit.",
        [("Er sagt, er sei krank.", "He says he is ill."),
         ("Sie sagt, sie habe keine Zeit.", "She says she has no time."),
         ("Der Minister erklärte, das Projekt werde fortgesetzt.", "The minister declared that the project would continue.")],
        [mc("'He says that he is tired.' (reported speech)", "Er sagt, er sei müde.", "Er sagt, er ist müde.", "Er sagt, er war müde."),
         mc("Which form is the Konjunktiv I of 'haben' (er)?", "habe", "hat", "hätte"),
         order("She says she has no time.", "Sie sagt, sie habe keine Zeit.")],
    ),
    point(
        "g4-04", 4, "Participles used as adjectives",
        "das spielende Kind · die gelesene Zeitung",
        "The present participle (infinitive + d) describes an ongoing action: das spielende Kind. The past "
        "participle describes a completed action or a passive result: die gelesene Zeitung. Both take normal "
        "adjective endings.",
        [("Das spielende Kind lacht.", "The playing child laughs."),
         ("Die gelesene Zeitung liegt auf dem Tisch.", "The newspaper that has been read is on the table."),
         ("Wir hörten den singenden Vogel.", "We heard the singing bird.")],
        [mc("'the sleeping baby' (das Baby)", "das schlafende Baby", "das geschlafene Baby", "das schlafen Baby"),
         mc("'the written letter' (der Brief)", "der geschriebene Brief", "der schreibende Brief", "der schreiben Brief"),
         order("The playing child laughs.", "Das spielende Kind lacht.")],
    ),
    point(
        "g4-05", 4, "Turning verbs into nouns",
        "das Lernen · die Entscheidung · die Freundlichkeit",
        "German forms nouns from verbs and adjectives. An infinitive becomes a neuter noun (das Lernen). Verbs "
        "often give -ung nouns (entscheiden → die Entscheidung), adjectives give -keit or -heit nouns "
        "(freundlich → die Freundlichkeit, schön → die Schönheit), all feminine.",
        [("Das Lernen macht mir Spaß.", "Studying is fun for me."),
         ("Die Entscheidung fiel schnell.", "The decision was made quickly."),
         ("Ich schätze seine Freundlichkeit.", "I appreciate his friendliness.")],
        [mc("Noun from 'entscheiden'", "die Entscheidung", "das Entscheiden", "der Entscheid"),
         mc("What is the gender of nouns ending in -keit?", "feminine (die)", "masculine (der)", "neuter (das)"),
         order("Studying is fun for me.", "Das Lernen macht mir Spaß.")],
    ),
    point(
        "g4-06", 4, "Two-part connectors",
        "nicht nur … sondern auch · sowohl … als auch · weder … noch · entweder … oder · je … desto",
        "Two-part connectors link ideas in pairs. nicht nur … sondern auch (not only … but also), sowohl … als "
        "auch (both … and), weder … noch (neither … nor), entweder … oder (either … or), and je … desto with "
        "comparatives (the more … the more).",
        [("Er spricht nicht nur Deutsch, sondern auch Französisch.", "He speaks not only German but also French."),
         ("Ich habe weder Zeit noch Geld.", "I have neither time nor money."),
         ("Je mehr ich lerne, desto besser verstehe ich.", "The more I learn, the better I understand.")],
        [mc("'neither … nor'", "weder … noch", "entweder … oder", "nicht nur … sondern auch"),
         mc("Complete: 'Je älter er wird, ___ ruhiger wird er.'", "desto", "als", "wie"),
         order("The more I learn, the better I understand.", "Je mehr ich lerne, desto besser verstehe ich.")],
    ),
    point(
        "g4-07", 4, "da- and wo- compounds",
        "darauf · damit · davon  /  worauf · womit · wovon",
        "To refer to a thing after a preposition, German joins da(r)- to the preposition: Ich warte darauf. To "
        "ask about a thing use wo(r)-: Worauf wartest du? For people use the preposition with a pronoun: Ich "
        "warte auf ihn. Add r before a vowel: darauf, worüber.",
        [("Ich freue mich darauf.", "I am looking forward to it."),
         ("Worauf wartest du?", "What are you waiting for?"),
         ("Wir sprechen oft darüber.", "We often talk about it.")],
        [mc("'What are you thinking about?'", "Woran denkst du?", "Wofür denkst du?", "Wovon denkst du?"),
         mc("'I am looking forward to it.'", "Ich freue mich darauf.", "Ich freue mich auf es.", "Ich freue mich dafür."),
         order("What are you waiting for?", "Worauf wartest du?")],
    ),
    point(
        "g4-08", 4, "Modal particles",
        "doch · ja · mal · eben · halt · eigentlich",
        "Small words like doch, ja, mal, eben and halt colour the tone of a sentence and are very common in "
        "speech. mal softens a request (Komm mal her!), doch contradicts or encourages, ja signals shared "
        "knowledge, eben and halt mean 'just like that, that's how it is'.",
        [("Komm mal her!", "Come here for a moment!"),
         ("Das ist doch klar.", "That is obvious, after all."),
         ("Es regnet halt.", "Well, it is raining; that is just how it is.")],
        [mc("Which particle softens a request?", "mal", "ja", "eben"),
         mc("'You do know him, don't you?' (expecting yes)", "Du kennst ihn doch.", "Du kennst ihn eben.", "Du kennst ihn mal."),
         order("Come here for a moment!", "Komm mal her!")],
    ),
    point(
        "g4-09", 4, "Time connectors: während, bevor, sobald, nachdem, seitdem",
        "während · bevor · sobald · nachdem · seitdem · bis",
        "These conjunctions send the verb to the end. während = while, bevor = before, sobald = as soon as, "
        "nachdem = after (with the past perfect or perfect), seitdem = since then, bis = until.",
        [("Während ich koche, hört er Musik.", "While I cook, he listens to music."),
         ("Bevor du gehst, ruf mich an.", "Before you go, call me."),
         ("Sobald ich fertig bin, komme ich.", "As soon as I am finished, I will come.")],
        [mc("'Before I go to bed, I read.'", "Bevor ich ins Bett gehe, lese ich.", "Bevor ich gehe ins Bett, lese ich.", "Bevor ich ins Bett gehe, ich lese."),
         mc("'After we had eaten, we left.'", "Nachdem wir gegessen hatten, gingen wir.", "Nachdem wir essen hatten, gingen wir.", "Nachdem wir gegessen haben, gehen wir."),
         order("As soon as I am finished, I will come.", "Sobald ich fertig bin, komme ich.")],
    ),
    point(
        "g4-10", 4, "Relative clauses with prepositions, was and wo",
        "in der · mit dem · alles, was · der Ort, wo",
        "A preposition stays in front of the relative pronoun and decides its case: Die Stadt, in der ich "
        "wohne. After alles, nichts, etwas, vieles and whole clauses use was: Alles, was du sagst, ist richtig. "
        "For places wo is possible: der Ort, wo wir uns trafen.",
        [("Das ist die Stadt, in der ich geboren wurde.", "That is the city in which I was born."),
         ("Alles, was du sagst, ist richtig.", "Everything you say is right."),
         ("Der Mann, mit dem ich spreche, ist mein Chef.", "The man I am talking to is my boss.")],
        [mc("'the friend I am travelling with' (der Freund)", "der Freund, mit dem ich reise", "der Freund, mit den ich reise", "der Freund, mit der ich reise"),
         mc("Complete: 'Nichts, ___ er sagt, stimmt.'", "was", "das", "dass"),
         order("Everything you say is right.", "Alles, was du sagst, ist richtig.")],
    ),
]
