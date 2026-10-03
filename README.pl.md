[English](README.md) · **Polski**

# Bridge — systemowa warstwa wprowadzania, która daje głos wszędzie

> HackYeah 2026 · OpenHarmony / HarmonyOS Challenge
> Temat wiodący: **Human-Centric Technology** w połączeniu z **Intelligent Experiences**

## Problem

Osoby z afazją po udarze, osoby niemówiące korzystające z AAC, osoby z ALS lub
mózgowym porażeniem dziecięcym oraz osoby z dysleksją nie potrafią pisać w sposób,
jaki zakłada standardowa klawiatura.

Dziś w tym celu kupują drogą **osobną aplikację** do komunikacji wspomagającej — a ta
aplikacja jest wyspą. Użytkownik może w niej ułożyć zdanie, ale nie może go *wysłać* w
komunikatorze, w wiadomości e-mail, w aplikacji bankowej ani w grze. Kopiuj-wklej to
proteza, a nie rozwiązanie.

Nikt nie dostarcza tego jako **zdolności systemowej**, ponieważ na zamkniętych
platformach warstwa wprowadzania nie jest czymś, co zewnętrzny deweloper może
rozszerzać.

## Czym jest Bridge

Bridge to nie kolejna aplikacja. To **metoda wprowadzania** — komponent systemowy,
który zastępuje klawiaturę w **każdym polu tekstowym na urządzeniu**.

**Dwa tryby, jedna zdolność:**

| Tryb | Interakcja | Dla kogo | Stan |
| --- | --- | --- | --- |
| **Rewrite** | Pisz, jak potrafisz, a następnie dotknij *Correct / Plain / Polite*. Tekst w polu zostaje przepisany w miejscu. | Dysleksja, afazja, osoby piszące w języku obcym, każdy, kto pisze do urzędu, a nie do znajomego | **działa**, zweryfikowane na emulatorze |
| **Compose** | Wybieraj pojęcia (🍽️ ⏰ 👨‍👩‍👧) zamiast pisać; powstaje poprawne gramatycznie zdanie w rejestrze językowym aplikacji, w której się znajdujesz. | Osoby niemówiące, znaczne ograniczenia motoryczne | **działa**, zweryfikowane na emulatorze |

Ponieważ jeden silnik obsługuje oba tryby, budujemy **jedną zdolność platformy i
prowadzimy ją od początku do końca**, zamiast pięciu płytkich integracji.

## Dlaczego liczy się otwarta platforma

To `InputMethodExtensionAbility` (IME Kit) sprawia, że jest to możliwe: klawiatura
firmy trzeciej otrzymuje **proxy edytora tekstu** dla aplikacji, która aktualnie posiada
pole, dzięki czemu może odczytywać, przepisywać i wstawiać tekst w całym systemie.
Europejski akt o dostępności czyni z tego problem zgodności dla europejskich
produktów, a nie niszową przysługę — i jest to dokładnie ten rodzaj punktu
rozszerzeń, którego platforma kontrolowana przez dostawcę nie udostępnia.

## Prywatność to funkcja produktu, a nie zastrzeżenie

Silnik przepisywania korzysta ze zdalnego modelu LLM i **jest to zdarzenie związane
z prywatnością**. Bridge podchodzi do niego wprost:

- **Lokalne oczyszczanie danych osobowych (PII) przed każdym żądaniem.** Adresy
  e-mail, numery telefonów, numery PESEL, numery IBAN, ciągi cyfr przypominające
  numery kart oraz adresy URL są zastępowane typowanymi symbolami zastępczymi,
  wysyłane jako symbole zastępcze i przywracane lokalnie w odpowiedzi. Model nigdy
  nie otrzymuje rzeczywistych wartości.
- **Widoczny licznik** na klawiaturze: *"3 items hidden from the model"*.
- **Deterministyczne działanie offline.** Jeśli zawiedzie sieć, limit czasu lub sam
  model, przejmuje lokalny silnik reguł, a klawiatura mówi o tym wprost, zamiast
  udawać.
- **Klucz API nigdy nie trafia do tego repozytorium.** Wprowadza się go raz na
  ekranie ustawień aplikacji i jest przechowywany w preferencjach urządzenia.

Zobacz [`docs/AI_INTEGRATION.md`](docs/AI_INTEGRATION.md), aby poznać obsługę danych,
ograniczenia i walidację, oraz [`AI_WORKFLOW.md`](AI_WORKFLOW.md), aby dowiedzieć się,
jak projekt powstał z użyciem narzędzi AI.

## Wykorzystane zdolności platformy

| Zdolność | Dlaczego jest kluczowa |
| --- | --- |
| `InputMethodExtensionAbility` + `InputMethodEngine` / `TextEditorProxy` | Cały produkt: odczyt, przepisywanie i wstawianie tekstu w całym systemie. Na iOS zwykłe aplikacje nie mają do tego dostępu w ogóle |
| zdarzenia cyklu życia `inputMethodAbility` | Podłączenie i odłączenie od aktywnego edytora, dzięki czemu wiemy, kiedy pole ma fokus |
| `EditorAttribute.bundleName` przez `editorAttributeChanged` (API 14+) | Klawiatura wie, **która aplikacja posiada pole**, więc przepisanie może dopasować się do jej rejestru językowego — swobodnego w komunikatorze, formalnego w kliencie poczty |
| `@ohos.net.http` | Zdalny silnik przepisywania |
| `hdc shell ime -e/-s` (narzędzie IME, API 20+) | Odtwarzalne włączanie i przełączanie z wiersza poleceń zamiast przeklikiwania się przez Ustawienia |

Żadnych uprawnień uprzywilejowanych, żadnego podpisywania jako aplikacja systemowa,
żadnego profilu `hos_system_app`. To świadoma decyzja o zakresie: usuwa największe
ryzyko harmonogramu z budowy w czasie poniżej 24 godzin.

## Układ repozytorium

```
core/       Platform-agnostic rewrite engine (ArkTS-compatible TypeScript) + tests
app/        The ArkTS/ArkUI application and the input method extension
scripts/    Toolchain setup, IME enablement, dev loop, checks
docs/       Architecture, AI integration, environment, demo plan, decision log
dist/       The signed .hap, ready to install
```

Zacznij od **[`docs/DECISIONS.md`](docs/DECISIONS.md)**: to rejestr decyzji, którymi
kieruje się ten projekt, zapisanych jako twierdzenia możliwe do sprawdzenia, a nie
jako proza. Każdy pull request jest wobec niego recenzowany przez
[Prelint](https://prelint.com), dzięki czemu zmiana odbiegająca od decyzji zostaje
wychwycona przed scaleniem, a nie po nim.

## Wymagane elementy dostarczane i ich lokalizacja

| # | Element | Lokalizacja | Stan |
| --- | --- | --- | --- |
| 1 | Publiczne repozytorium kodu źródłowego | to repozytorium | gotowe |
| 2 | Odtwarzalne instrukcje konfiguracji, budowania, instalacji i uruchamiania | [Budowanie i uruchamianie](#build-and-run), [`scripts/`](scripts) | gotowe w zakresie kroków łańcucha narzędzi; zweryfikowane do granicy SDK |
| 3 | Działający pakiet `.hap` | [`dist/bridge-1.0.0-signed.hap`](dist/bridge-1.0.0-signed.hap), wytworzony przez `scripts/dev-loop.sh build` + `scripts/sign-hap.sh` | **zbudowany i podpisany** jako zwykła aplikacja; instalacja na emulatorze w toku |
| 4 | Krótka nagrana demonstracja | plan i lista ujęć w [`docs/DEMO.md`](docs/DEMO.md) | plan gotowy, jeszcze nie nagrano |
| 5 | Opis architektury i implementacji | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | gotowy |
| 6 | `AI_WORKFLOW.md` | [`AI_WORKFLOW.md`](AI_WORKFLOW.md) | gotowy, aktualizowany w miarę postępów prac |
| 7 | Dokumentacja integracji z AI | [`docs/AI_INTEGRATION.md`](docs/AI_INTEGRATION.md) | gotowa |

## Zweryfikowane na emulatorze

To nie makieta. Zarejestrowane na emulatorze telefonu z HarmonyOS 6.1.1(24); zrzuty
ekranu znajdują się w [`docs/evidence/`](docs/evidence).

```
field text : ja chciec jutro przyjsc na spotkanie o 10
status line: model: 1233 ms, 0 hidden
variants   : minimal  Ja chcę jutro przyjść na spotkanie o 10.
             natural  Chcę przyjść jutro na spotkanie o 10.
             formal   Będę na spotkaniu o 10 jutro.
after a tap: the field contains the corrected sentence
             status line: replaced 41 characters
```

Polska odmiana i znaki diakrytyczne wracają poprawne. Wiersz `replaced 41 characters`
jest także najostrzejszym dostępnym dowodem, że API kursora jest używane w prawidłowy
sposób: usunięto dokładnie te znaki, które znajdowały się przed kursorem, a zamiennik
trafił na ich miejsce.

**Compose**, na podstawie trzech dotknięć pojęć — `jeść`, `później`, `rodzina`:

```
picked     : jeść, później, rodzina
status line: model: 1490 ms, 0 hidden
variants   : faithful  Zjem później z rodziną.
             natural   Będę jeść później z rodziną.
             expanded  Zamierzam zjeść później z rodziną.
after a tap: the field contains "Zjem później z rodziną."
```

Poprawny polski aspekt i przypadek, z trzech emoji. **Użytkownik, który nie potrafi
pisać, utworzył poprawne gramatycznie zdanie — w polu tekstowym innej aplikacji.**

Zrzutami ekranu w [`docs/evidence/`](docs/evidence) potwierdzono również dwa
identyfikatory osobiste (`2 hidden`) powstrzymane przed wysłaniem do modelu
i przywrócone lokalnie, a także nieosiągalny punkt końcowy degradujący się do
`offline: The model service could not be reached.` z użytecznym wynikiem offline.

## Stan

| Etap | Stan |
| --- | --- |
| Rdzeń silnika przepisywania + testy jednostkowe | **gotowe** — 92 testy przechodzą, `tsc --noEmit` w trybie strict bez błędów |
| Łańcuch narzędzi | **gotowe** — DevEco Studio 6.1.1.280, pełne SDK zweryfikowane sumą kontrolną, obraz emulatora zainstalowany |
| Aplikacja ArkTS | **kompiluje się** — `BUILD SUCCESSFUL` |
| Podpisywanie | **wykonane offline** przy użyciu tożsamości deweloperskiej z SDK; `app-feature: hos_normal_app` |
| `.hap` zainstalowany na emulatorze | **gotowe** |
| Bramka metody wprowadzania: podłączenie, odczyt i zapis w innej aplikacji | **zaliczona**, ze zrzutami ekranu |
| Przepisanie przez rzeczywisty model, zastosowane w polu | **gotowe**, patrz wyżej |
| Oczyszczanie danych osobowych, udokumentowane na urządzeniu | **gotowe** — `2 hidden`, a wartości przywrócone w wariantach |
| Działanie offline w razie awarii, udokumentowane na urządzeniu | **gotowe** — nieosiągalny punkt końcowy zwrócił `offline: The model service could not be reached.` oraz użyteczny wynik offline |
| Tryb Compose (pasek pojęć) | **gotowe** — trzy dotknięcia pojęć utworzyły poprawne gramatycznie zdanie po polsku, zastosowane w polu |
| Nagranie demonstracji | jeszcze nie — lista ujęć jest gotowa w [`docs/DEMO.md`](docs/DEMO.md) |

Pierwszym kamieniem milowym nie jest AI. Jest nim dowód, że metoda wprowadzania
firmy trzeciej potrafi podłączyć się do pola tekstowego innej aplikacji i w nim
pisać, ponieważ od tego zależy każde inne twierdzenie w tym README. Zostało to
wyodrębnione w
[`KeyboardController.ets`](app/entry/src/main/ets/inputmethod/KeyboardController.ets),
a przyciski trybów na klawiaturze celowo mówią, że nie są jeszcze modelem. Zobacz
bramkę go/no-go w [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

<a id="build-and-run"></a>
## Budowanie i uruchamianie

Odtwarzalne z czystego klonu repozytorium, gdy DevEco Studio jest już zainstalowane:

```bash
# 1. DevEco CLI, and a report of what is still missing
scripts/setup-toolchain.sh

# 2. Region switch to CN (once, with DevEco Studio closed).
#    Without it the emulator only offers a watch profile.
scripts/set-devco-region-cn.sh

# 3. A phone emulator. The system image is several gigabytes.
scripts/create-emulator.sh

# 4. Engine tests - these need no SDK at all
scripts/dev-loop.sh tests

# 5. Exercise the engine end to end against a local mock model, or your real one
scripts/dev-loop.sh engine
BRIDGE_API_KEY=sk-... node scripts/try-engine.mjs

# 6. Build, sign, then install and launch
scripts/dev-loop.sh build
scripts/sign-hap.sh
scripts/dev-loop.sh run

# 7. Enable and switch to the Bridge keyboard
scripts/enable-ime.sh com.bridge.ime
scripts/enable-ime.sh --status

# 8. Capture evidence from the emulator
scripts/dev-loop.sh shot rewrite-demo
```

`scripts/try-engine.mjs` korzysta z dokładnie tego samego dostarczanego rdzenia, więc
to, co wypisuje, jest tym, co pokaże klawiatura. W ten sposób zwalidowano prompt,
zanim istniało jakiekolwiek urządzenie; opiera się na tym krok 3 w
[`docs/SETUP.md`](docs/SETUP.md#step-6--verification-checklist).

Silnik jest jedynym źródłem prawdy i jest kopiowany do modułu ArkTS przez
`scripts/sync-core.sh`; nigdy nie edytuj kopii w `app/entry/src/main/ets/core/`.

Dokładne wersje, na których to zweryfikowano: Node.js 26.9.0, npm 11.19.1,
`@deveco/deveco-cli` 1.3.4, DevEco Studio dla macOS (Apple Silicon).


## Uruchamianie testów silnika

Wymaga jedynie Node.js 22+ (Node 26 uruchamia TypeScript natywnie):

```bash
node --test core/test/
```
