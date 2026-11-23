// Tests du nettoyage. Lancer : scripts/tester.sh
import Foundation
@MainActor func lancerTests() {
    let dico = [DictEntry(written: "Wispr Flow", heard: ["whisper flow", "whisperflow"]),
                DictEntry(written: "ChatGPT", heard: ["chat gpt"])]
    var ok = 0, ko = 0
    func verifie(_ brut: String, _ attendu: String) {
        let r = Cleaner.clean(brut, dictionary: dico)
        if r == attendu { ok += 1 } else { ko += 1; print("ÉCHEC\n  brut    : \(brut)\n  attendu : \(attendu)\n  obtenu  : \(r)") }
    }
    verifie(" euh, alors je voulais te dire que euh c'est bon.", "Alors je voulais te dire que c'est bon.")
    verifie("Bah euh on se voit demain ? hum oui.", "On se voit demain ? Oui.")
    verifie("J'ai quitté whisper flow pour chat gpt.", "J'ai quitté Wispr Flow pour ChatGPT.")
    verifie("on teste whisper flow et Notion", "On teste Wispr Flow et Notion")
    verifie("Sous-titres réalisés par la communauté d'Amara.org", "")
    verifie("[Musique]", "")
    verifie("Le pneu est neuf, heureux.", "Le pneu est neuf, heureux.")
    verifie("Merci beaucoup pour ton aide.", "Merci beaucoup pour ton aide.")
    verifie(" Bonjour, je teste pour Wispr Flow, et ça\n marche plutôt bien.\n", "Bonjour, je teste pour Wispr Flow, et ça marche plutôt bien.")
    print("Nettoyage : \(ok) réussis, \(ko) échoués")
    if ko > 0 { exit(1) }
}
