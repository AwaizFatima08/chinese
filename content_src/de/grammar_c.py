"""German grammar, levels C1 and C2."""
from grammar_lib import point, mc, order

POINTS = [
    # ------------------------------------------------------------------ C1
    point(
        "g5-01", 5, "Reported speech in more detail",
        "Konjunktiv I · Konjunktiv II as a substitute · würde + infinitive",
        "In careful writing, reported speech uses the Konjunktiv I (er sei, sie habe, es gebe). If its form is "
        "identical to the indicative (sie haben, wir kommen), switch to the Konjunktiv II (sie hätten, wir "
        "kämen) or to würde + infinitive. Past events use sei or habe + participle.",
        [("Er behauptet, er sei gestern nicht dort gewesen.", "He claims he was not there yesterday."),
         ("Die Kollegen sagten, sie hätten keine Zeit.", "The colleagues said they had no time."),
         ("Sie meinte, es gebe keine andere Lösung.", "She thought there was no other solution.")],
        [mc("Reported speech: 'The doctors said they had no time.'", "Die Ärzte sagten, sie hätten keine Zeit.", "Die Ärzte sagten, sie haben keine Zeit.", "Die Ärzte sagten, sie habe keine Zeit."),
         mc("Which form reports a past event? 'He said he had been ill.'", "Er sagte, er sei krank gewesen.", "Er sagte, er war krank gewesen.", "Er sagte, er wäre krank."),
         order("She thought there was no other solution.", "Sie meinte, es gebe keine andere Lösung.")],
    ),
    point(
        "g5-02", 5, "Genitive prepositions in formal language",
        "aufgrund · angesichts · hinsichtlich · anhand · mithilfe · infolge · zugunsten + genitive",
        "Formal writing prefers prepositions that take the genitive: aufgrund (because of), angesichts (in view "
        "of), hinsichtlich (with regard to), anhand (using, on the basis of), mithilfe (with the help of), infolge "
        "(as a result of), zugunsten (in favour of). Some also accept the dative in everyday speech.",
        [("Aufgrund des schlechten Wetters fällt das Fest aus.", "Because of the bad weather the party is cancelled."),
         ("Angesichts der Lage ist Vorsicht geboten.", "In view of the situation caution is advised."),
         ("Anhand dieser Zahlen lässt sich der Trend erkennen.", "The trend can be recognised from these figures.")],
        [mc("'In view of the costs …'", "Angesichts der Kosten …", "Angesichts die Kosten …", "Angesichts den Kosten …"),
         mc("Which case follows 'aufgrund'?", "genitive", "dative", "accusative"),
         order("Because of the bad weather the party is cancelled.", "Aufgrund des schlechten Wetters fällt das Fest aus.")],
    ),
    point(
        "g5-03", 5, "Ways to avoid the passive",
        "man · sich lassen + infinitive · sein + zu + infinitive · -bar / -lich",
        "German offers several alternatives to the werden-passive. man + active verb is the most common: Man "
        "spricht hier Deutsch. sich lassen + infinitive means 'can be done': Das lässt sich lösen. sein + zu + "
        "infinitive expresses necessity or possibility: Das ist zu beachten. Adjectives in -bar or -lich express "
        "'can be': lösbar, erhältlich.",
        [("Man spricht hier Deutsch.", "German is spoken here."),
         ("Das Problem lässt sich leicht lösen.", "The problem can easily be solved."),
         ("Die Regeln sind unbedingt zu beachten.", "The rules must be observed without fail.")],
        [mc("'The problem can be solved.' (sich lassen)", "Das Problem lässt sich lösen.", "Das Problem lässt lösen sich.", "Das Problem sich lässt lösen."),
         mc("Which sentence means 'The form must be filled in'?", "Das Formular ist auszufüllen.", "Das Formular ist ausgefüllt.", "Das Formular wird ausfüllen."),
         order("German is spoken here.", "Man spricht hier Deutsch.")],
    ),
    point(
        "g5-04", 5, "Fixed verb-noun phrases",
        "in Betracht ziehen · zur Verfügung stellen · in Frage kommen · zur Sprache bringen",
        "Formal German often uses a noun with a light verb instead of a single verb: in Betracht ziehen "
        "(consider), zur Verfügung stellen (provide), in Frage kommen (be possible), zur Sprache bringen (bring "
        "up), Entscheidung treffen (make a decision). Learn them as fixed units, including the preposition.",
        [("Wir ziehen mehrere Möglichkeiten in Betracht.", "We are considering several possibilities."),
         ("Die Firma stellt uns ein Auto zur Verfügung.", "The company provides us with a car."),
         ("Er brachte das Problem zur Sprache.", "He brought up the problem.")],
        [mc("'to make a decision'", "eine Entscheidung treffen", "eine Entscheidung machen", "eine Entscheidung tun"),
         mc("'to be possible' (formal)", "in Frage kommen", "an Frage kommen", "zur Frage kommen"),
         order("The company provides us with a car.", "Die Firma stellt uns ein Auto zur Verfügung.")],
    ),
    point(
        "g5-05", 5, "Extended participial attributes",
        "die von der Firma entwickelte Software",
        "In written German a participle can carry a whole phrase before the noun: die von der Firma entwickelte "
        "Software = die Software, die von der Firma entwickelt wurde. The article, the phrase and the participle "
        "with its adjective ending all come before the noun. Read from the article to the noun to find the "
        "meaning.",
        [("Die von der Firma entwickelte Software ist sehr beliebt.", "The software developed by the company is very popular."),
         ("Der seit Jahren geplante Bau beginnt nächste Woche.", "The construction, planned for years, begins next week."),
         ("Die im Vertrag genannten Bedingungen gelten weiter.", "The conditions named in the contract remain valid.")],
        [mc("Which relative clause is equivalent to 'die vom Chef unterschriebene Rechnung'?", "die Rechnung, die vom Chef unterschrieben wurde", "die Rechnung, die vom Chef unterschreiben wird", "die Rechnung, die den Chef unterschrieb"),
         mc("In 'der seit Jahren geplante Bau', what is the noun?", "Bau", "Jahren", "geplante"),
         order("The planned construction begins next week.", "Der geplante Bau beginnt nächste Woche.")],
    ),
    point(
        "g5-06", 5, "als ob and als wenn with Konjunktiv",
        "…, als ob + Konjunktiv II (verb at the end) · …, als + Konjunktiv II (verb second)",
        "To say that something only seems to be the case, use als ob or als wenn with the Konjunktiv II and the "
        "verb at the end. With plain als the verb comes straight after: Er tut, als wüsste er alles. The "
        "Konjunktiv I is possible in formal style.",
        [("Er tut, als ob er alles wüsste.", "He acts as if he knew everything."),
         ("Es sieht aus, als würde es regnen.", "It looks as if it were going to rain."),
         ("Sie lächelt, als hätte sie nichts gehört.", "She smiles as if she had heard nothing.")],
        [mc("'He acts as if he were ill.'", "Er tut, als ob er krank wäre.", "Er tut, als ob er krank ist.", "Er tut, als ob wäre er krank."),
         mc("Which sentence puts the verb straight after 'als'?", "Er tut, als wäre er krank.", "Er tut, als er krank wäre.", "Er tut, als ob wäre er krank."),
         order("He acts as if he knew everything.", "Er tut, als ob er alles wüsste.")],
    ),
    point(
        "g5-07", 5, "Concession and contrast",
        "obgleich · wenngleich · wenn auch · zwar … aber · während",
        "Several connectors express concession ('although'): obwohl, obgleich, wenngleich, wenn auch. zwar … "
        "aber admits a point and then contrasts it: Er ist zwar jung, aber erfahren. während can also express "
        "contrast: Er ist ruhig, während sie lebhaft ist.",
        [("Wenngleich das Projekt teuer ist, lohnt es sich.", "Although the project is expensive, it is worth it."),
         ("Er ist zwar jung, aber sehr erfahren.", "He is young, it is true, but very experienced."),
         ("Er ist ruhig, während seine Schwester sehr lebhaft ist.", "He is quiet, whereas his sister is very lively.")],
        [mc("Which connector can replace 'obwohl' in formal writing?", "obgleich", "weshalb", "sofern"),
         mc("'He is poor, it is true, but happy.'", "Er ist zwar arm, aber glücklich.", "Er ist zwar arm, sondern glücklich.", "Er ist zwar arm, deshalb glücklich."),
         order("He is young, it is true, but very experienced.", "Er ist zwar jung, aber sehr erfahren.")],
    ),
    point(
        "g5-08", 5, "Word building: prefixes ver-, ent-, er-, zer-, be-",
        "ver- · ent- · er- · zer- · be-",
        "Inseparable prefixes change the meaning of a verb in systematic ways. ver- often means a mistake or a "
        "change (verlaufen, verändern), ent- means removal (entfernen, entkommen), er- means achievement or "
        "result (erreichen, erkennen), zer- means destruction (zerstören, zerbrechen), be- makes a verb "
        "transitive (beantworten).",
        [("Wir haben uns im Wald verlaufen.", "We got lost in the forest."),
         ("Der Sturm hat das Dach zerstört.", "The storm destroyed the roof."),
         ("Sie hat ihr Ziel endlich erreicht.", "She has finally reached her goal.")],
        [mc("Which prefix means 'destroy' in zerstören?", "zer-", "ver-", "be-"),
         mc("Participle of 'verstehen'", "verstanden", "geverstanden", "verstehen gewesen"),
         order("She has finally reached her goal.", "Sie hat ihr Ziel endlich erreicht.")],
    ),
    # ------------------------------------------------------------------ C2
    point(
        "g6-01", 6, "Fronting and inversion for emphasis",
        "Selten habe ich … · Nie zuvor war … · Kaum hatte … , da …",
        "To stress a word or adverb, move it to the front; the verb stays in second position and the subject "
        "moves behind it. This is common after negative and restrictive adverbs such as nie, selten, kaum, "
        "keineswegs: Nie zuvor hatte ich so gelacht. Kaum hatte er geredet, da klingelte das Telefon.",
        [("Selten habe ich so gelacht.", "I have rarely laughed so much."),
         ("Nie zuvor hatte er so viel Glück gehabt.", "Never before had he had so much luck."),
         ("Kaum hatte er geredet, da klingelte das Telefon.", "Hardly had he spoken when the phone rang.")],
        [mc("'Never have I seen that.'", "Nie habe ich das gesehen.", "Nie ich habe das gesehen.", "Nie ich das habe gesehen."),
         mc("What follows 'kaum hatte er geredet' in the typical pattern?", "da + main clause", "dass + clause", "ob + clause"),
         order("Rarely have I laughed so much.", "Selten habe ich so gelacht.")],
    ),
    point(
        "g6-02", 6, "Double infinitives",
        "hätte … sagen sollen · habe … kommen sehen",
        "With modal verbs and verbs of perception the perfect tense uses an infinitive instead of the "
        "participle (the double infinitive) and the auxiliary goes before both: Ich habe das nicht sagen "
        "wollen. In a subordinate clause the auxiliary comes before the infinitives: …, weil er hat gehen "
        "müssen.",
        [("Ich hätte das nicht sagen sollen.", "I should not have said that."),
         ("Wir haben ihn kommen sehen.", "We saw him coming."),
         ("Sie hat das Auto nicht kaufen können.", "She was not able to buy the car.")],
        [mc("'I could not come.' (perfect)", "Ich habe nicht kommen können.", "Ich habe nicht kommen gekonnt.", "Ich bin nicht kommen können."),
         mc("'He should have called.'", "Er hätte anrufen sollen.", "Er hätte angerufen sollen.", "Er hätte anrufen gesollt."),
         order("I should not have said that.", "Ich hätte das nicht sagen sollen.")],
    ),
    point(
        "g6-03", 6, "Formal and official register",
        "Hiermit teile ich Ihnen mit, dass … · Ich bitte um … · Wir bedauern, Ihnen mitteilen zu müssen …",
        "Letters, contracts and official notices use a recognisable formal register: Hiermit, Bezug nehmend auf, "
        "mit freundlichen Grüßen, Wir bitten um Verständnis. Sentences are long, nouns carry the meaning, and "
        "passive and genitive constructions are common. Know it for reading even if you rarely write it.",
        [("Hiermit teile ich Ihnen mit, dass sich der Termin ändert.", "I hereby inform you that the appointment will change."),
         ("Bezug nehmend auf Ihr Schreiben vom 5. Mai bitte ich um Rückruf.", "With reference to your letter of 5 May, I ask for a call back."),
         ("Wir bitten um Ihr Verständnis.", "We ask for your understanding.")],
        [mc("How does a formal letter usually end?", "Mit freundlichen Grüßen", "Bis später", "Tschüss und danke"),
         mc("Which phrase opens a formal announcement?", "Hiermit teile ich Ihnen mit, dass …", "Also, ich sag dir mal, …", "Hör mal zu, …"),
         order("We ask for your understanding.", "Wir bitten um Ihr Verständnis.")],
    ),
    point(
        "g6-04", 6, "Hedging and careful statements",
        "Es dürfte sich um … handeln · Das wäre es dann · Man könnte meinen, …",
        "The Konjunktiv II and modal verbs help you sound careful and polite. dürfte means 'probably': Das "
        "dürfte stimmen. könnte, müsste and wäre soften claims, and phrases such as Es scheint, dass … or "
        "Man könnte sagen, … present an opinion as one possibility.",
        [("Es dürfte sich um einen Irrtum handeln.", "It is probably a mistake."),
         ("Das dürfte stimmen.", "That is probably true."),
         ("Man könnte meinen, die Sache sei erledigt.", "One might think the matter is settled.")],
        [mc("Which verb form means 'probably' here? 'Das ___ stimmen.'", "dürfte", "darf", "durfte"),
         mc("Which sentence is the most cautious?", "Das könnte ein Fehler sein.", "Das ist ein Fehler.", "Das muss ein Fehler sein."),
         order("That is probably true.", "Das dürfte stimmen.")],
    ),
    point(
        "g6-05", 6, "Fixed expressions and idioms",
        "im Grunde · auf jeden Fall · nach wie vor · von Fall zu Fall · es sei denn",
        "Advanced German relies on fixed expressions that cannot be translated word for word: im Grunde "
        "(basically), nach wie vor (still, as before), es sei denn (unless), nicht zuletzt (not least), auf "
        "Anhieb (at the first attempt). Notice the prepositions and the missing articles.",
        [("Im Grunde hast du recht.", "Basically you are right."),
         ("Er arbeitet nach wie vor in Hamburg.", "He still works in Hamburg."),
         ("Wir kommen, es sei denn, es regnet.", "We will come, unless it rains.")],
        [mc("'unless'", "es sei denn", "es ist denn", "wenn nicht denn"),
         mc("'still, as before'", "nach wie vor", "vor wie nach", "nach wo vor"),
         order("Basically you are right.", "Im Grunde hast du recht.")],
    ),
    point(
        "g6-06", 6, "Style: nominal versus verbal expression",
        "Nach der Ankunft … · Nachdem er angekommen war, …",
        "Formal and academic German often replaces a subordinate clause with a noun phrase: Nachdem er "
        "angekommen war, … becomes Nach seiner Ankunft, … The noun style is compact and impersonal; the verbal "
        "style is livelier and clearer in speech. Being able to switch between them is a mark of advanced "
        "German.",
        [("Nach seiner Ankunft rief er sofort an.", "After his arrival he called immediately."),
         ("Bei schlechtem Wetter fällt das Konzert aus.", "In bad weather the concert is cancelled."),
         ("Wegen der Verspätung des Zuges kamen wir zu spät.", "Because of the train's delay we arrived late.")],
        [mc("Which is the noun-style version of 'Wenn es regnet, bleiben wir zu Hause'?", "Bei Regen bleiben wir zu Hause.", "Wenn Regen, bleiben wir zu Hause.", "Regnen wir bleiben zu Hause."),
         mc("'After his arrival' (noun style)", "Nach seiner Ankunft", "Nachdem seine Ankunft", "Nach er ankommt"),
         order("In bad weather the concert is cancelled.", "Bei schlechtem Wetter fällt das Konzert aus.")],
    ),
]
