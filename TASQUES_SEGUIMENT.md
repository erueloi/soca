# 📋 Seguiment de Blocs i Tasques - Soca App

Aquest document recopila de forma estructurada totes les tasques desenvolupades, les decisions preses i els fitxers involucrats perquè en puguis fer el seguiment o crear tiquets/tasques fàcilment.

---

## 🟢 BLOC 1: Petits Detalls i Usabilitat UI

### 📌 Tasca 1: Indicador de Versió visible de l'App (`v1.9.17`)
- **Objectiu:** Mostrar la versió actual a l'arrencada de l'aplicació tant en web nativa com en mòbil/escriptori.
- **Canvis aplicats:**
  - `web/index.html`: Afegit text `v1.9.17` al peu del Splash Screen HTML natiu mentre es descarreguen els assets de Flutter.
  - `lib/main.dart`: Ajustat `WelcomeScreen` (fons `#EFEBE9`, logo, spinner i text `v$version`).
  - `lib/features/dashboard/presentation/pages/home_page.dart`: Indicador de versió interactiu amb diàleg de Release Notes.
  - `lib/features/dashboard/presentation/widgets/soca_drawer.dart` i `lib/features/auth/presentation/pages/login_page.dart`.

### 📌 Tasca 2: Fletxes del Carrusel d'Horts al Tauler de Control
- **Objectiu:** Resoldre el parpelleig/bucle de rebuilds i afegir fletxes de navegació manuals `(1/N)` per a qui utilitza ratolí o no arrossega el carrusel.
- **Canvis aplicats:**
  - `lib/features/dashboard/presentation/widgets/hort_dashboard_widget.dart`:
    - Eliminat el bucle de rebuilds causat per callbacks d'animació cíclica.
    - Afegits botons de fletxa anterior/següent (`Icons.chevron_left` / `chevron_right`).
    - Indicador numèric de pàgina activa `(1/2)`.
    - Claus `ValueKey(espai.id)` estables per a les targetes.

### 📌 Tasca 3: Unificació de Visors d'Imatges i Zoom Interactiu
- **Objectiu:** Unificar els dos visors diferents de fotos de l'arbre (foto de capçalera i diari visual) en una sola experiència que a més permeti fer zoom fluidament.
- **Canvis aplicats:**
  - `lib/features/trees/presentation/widgets/tree_photo_gallery_page.dart` *(Nou component)*:
    - Visor unificat a pantalla completa amb fons fosc, carrusel de fotos i panell de metadades (data, salut, observacions, alçada, diàmetre).
    - **Zoom múltiple**: Pinça tàctil (pinch-to-zoom), roda del ratolí / trackpad a web/desktop, doble toc animat (1x <-> 2.5x) i botó de zoom dedicat a la barra superior (`zoom_in` / `zoom_out`).
    - Bloqueig intel·ligent del lliscament lateral mentre hi ha zoom actiu per explorar qualsevol detall de la foto.
    - Accions per establir com a foto principal o eliminar la foto.
  - `lib/features/trees/presentation/widgets/tree_detail.dart`:
    - Enllaçat el clic de la foto de capçalera al nou visor unificat.
    - Enllaçat el clic de qualsevol foto del *Diari Visual* al nou visor unificat.
    - Eliminat el diàleg redundant anterior (`_showFullImage`) i prop de 400 línies de codi duplicat.
  - `lib/features/trees/presentation/pages/tree_growth_timeline_page.dart`:
    - Unificat també l'històric general de creixement al nou visor, eliminant 290 línies de codi repetit.

---

## 💧 BLOC 2: Gestió de Reg, Gota a Gota i Mètriques Hídriques

### 📌 Tasca 1: Revisió de la Coherència dels Litres de Reg
- **Objectiu:** Corregir la recomanació excessiva de 39 L d'aigua per arbre i adaptar-la a la realitat agronòmica de Catalunya (estàndards IRTA i RuralCat).
- **Canvis aplicats:**
  - `lib/features/trees/domain/entities/tree_extensions.dart`:
    - S'ha establert la dosi de suport en clima mediterrani: **8 L** (1 degoter de 4 L/h durant 2h) o **16 L** (2 degoters de 4 L/h durant 2h).
    - Si el balanç hídric no és deficitari o l'arbre ja està establert/arrelat, la necessitat és de **0 L**.
    - Càlcul automàtic del temps de reg recomanat en hores (`recommendedWateringHours`, habitualment **2.0 h**).

### 📌 Tasca 2: Modelatge del Reg Gota a Gota a l'Arbre
- **Objectiu:** Permetre guardar quants degoters té cada arbre i de quin cabal són.
- **Canvis aplicats:**
  - `lib/features/trees/domain/entities/tree.dart`:
    - Nous camps opcionals: `dripEmitters` (nombre de degoters, per defecte 1) i `dripFlowRate` (cabal en L/h, per defecte 4.0 L/h).
    - Getter `totalDripRate` (`dripEmitters * dripFlowRate`, p. ex. 4 L/h, 8 L/h, 12 L/h, o 0 si és manual).
  - `lib/features/trees/data/repositories/trees_repository.dart`:
    - Mètode `updateTreesDripConfig` amb escriptura en bloc (`WriteBatch`) a Firestore per configurar un o desenes d'arbres de cop.

### 📌 Tasca 3: Configurador Visual de Reg a la Fitxa de l'Arbre
- **Objectiu:** Fer intuïtiva la configuració de reg sense dropdowns pesats ni texts confusos ("Reg gota a gota").
- **Canvis aplicats:**
  - `lib/features/trees/presentation/widgets/tree_detail.dart`:
    - Nova secció **"REG"** a la pestanya tècnica amb 3 mètriques: *Instal·lació*, *Cabal total* i *Necessitat hídrica*.
    - Configurador per targetes visuals seleccionables en 1 clic:
      - **1 Degoter (4 L/h)**
      - **2 Degoters (8 L/h)**
      - **Reg Manual (garrafa / mànega)**
      - **Personalitzat** (camps numèrics lliures per a nombre de degoters i cabal).
    - Botó únic a mida completa per a accions de reg.

### 📌 Tasca 4: Giny de Dipòsit d'Aigua al Formulari de Reg
- **Objectiu:** Donar consciència del volum total d'aigua gastat amb representació visual de dipòsit i equivalència en dipòsits IBC de 1.000 L.
- **Canvis aplicats:**
  - `lib/features/trees/presentation/pages/watering_page.dart`:
    - Giny estilitzat en tons blaus que representa un tanc d'aigua.
    - Càlcul dinàmic: litres totals consumits, metres cúbics (`m³`) i equivalència de camp: **`~X.X dipòsits IBC (1.000 L)`** quan supera els 500 L.
    - Desglossament per grups d'arbres.

### 📌 Tasca 5: Targeta de Necessitat Actual a la Pàgina Inicial de Reg
- **Objectiu:** Conèixer d'un cop d'ull a dalt a la dreta quantes hores i quants litres cal regar avui abans d'iniciar la sessió.
- **Canvis aplicats:**
  - `lib/features/trees/presentation/pages/watering_page.dart`:
    - Targeta superior dreta (responsive: al costat dels filtres a web/desktop i a sobre en mòbil).
    - Mètriques en temps real: litres totals necessaris, volum en m³, temps de gota a gota recomanat (`Reg: ~2.0h`) i equivalència en dipòsits IBC.
    - Botó blau directe **"Regar (N)"** per regar tots els arbres amb estrès hídric en un sol clic.

### 📌 Tasca 6: Botó Blau i Gestió de Barreja (Manual + Gota a Gota)
- **Objectiu:** Recuperar el botó blau prominent i resoldre què passa si en una mateixa sessió hi ha arbres amb degoter i arbres sense degoter.
- **Canvis aplicats:**
  - `lib/features/trees/presentation/pages/watering_page.dart`:
    - Botó blau visible a la barra d'eines (`Regar (X)`), a la targeta del dipòsit i al botó flotant inferior.
    - En regar per temps de sector de gota a gota, s'inclou un interruptor dedicat per als arbres manuals:
      - *Activat*: Registra reg manual simultani (8 L).
      - *Desactivat*: Ignora els arbres manuals per no registrar falsos regs si només s'ha obert l'aixeta del gota a gota.
    - Notes automàtiques diferenciades per a cada esdeveniment de reg.

### 📌 Tasca 7: Actualització del Giny de Reg al Tauler de Control
- **Objectiu:** Sincronitzar el giny de la pàgina principal amb les noves dades i substituir el botó buit d'emergència.
- **Canvis aplicats:**
  - `lib/features/dashboard/presentation/widgets/irrigation_widget.dart`:
    - Filtre unificat (exclou arbres planificats, existents i veterans).
    - Canvi de *"Reg Manual (Avui)"* a **"Regat Avui"** (suma gota a gota + manual).
    - Dades de necessitat amb litres reals, hores estimades i dipòsits IBC.
    - Substituït el botó d'emergència per:
      - **`REGAR ARA (X)`** (blau) si hi ha dèficit, que obre directament la pàgina amb el filtre aplicat.
      - **`GESTIONAR REG`** si tots els arbres estan hidratats.
### 📌 Tasca 8: Revisió i Ajust del Reg de l'Hort (Bancals)
- **Objectiu:** Verificar que el balanç hídric de l'hort no patís sobredimensió i corregir el càlcul del temps de gota a gota.
- **Canvis aplicats:**
  - `lib/features/horticulture/domain/services/garden_irrigation_service.dart`:
    - Confirmada la total validesa dels litres necessaris per bancal (consum diari basat en $ET_0 \times K_c$ per $\text{m}^2$ i llindar de dèficit $>2\text{ mm}$).
    - Corregida la fórmula dels minuts de reg per degoteig: ara es calcula el cabal total del bancal multiplicant el cabal per $\text{m}^2$ per l'àrea real del bancal (`bed.cabalSistemaLitersHora * actualAreaM2`), evitant que el temps de reg es multipliqués erròniament per l'àrea i donant el temps exacte de clau oberta (ex: 18 min en comptes de 86 min).

### 📌 Tasca 9: Filtre per Reg Manual i Reg Gota a Gota
- **Objectiu:** Permetre filtrar fàcilment a la pantalla de reg entre arbres amb sistema gota a gota instal·lat o arbres amb reg manual (garrafa/mànega).
- **Canvis aplicats:**
  - `lib/features/trees/presentation/providers/trees_provider.dart`:
    - Creat l'enum `DripFilter { all, drip, manual }`.
    - Afegit el camp `dripFilter` a l'estat `WateringFilters` (per defecte `all`), amb els mètodes `setDripFilter` i `toggleDripFilter` al notifier `WateringFiltersNotifier`.
  - `lib/features/trees/presentation/pages/watering_page.dart`:
    - Afegits dos nous xips de filtratge ràpid a la barra d'eines: **`💧 Gota a Gota`** (blau) i **`🪣 Manual`** (turquesa) en un component `Wrap` responsive.
    - Integrat el filtre a `filteredTrees` (`dripEmitters > 0` vs `dripEmitters == 0`).
    - Actualitzat el càlcul de la targeta de Necessitat del Dipòsit d'Aigua (`targetTreesForNeed`): si s'aplica el filtre de gota a gota o de manual, els litres, hores i tancs IBC es recalculen en temps real només per al subconjunt seleccionat.
    - Afegit xip actiu descartable (`InputChip` amb icona de creu) per treure el filtre amb un sol toc.
    - Les accions massives ("Seleccionar Tots" i "Regar (X)") respecten el filtre actiu.

---

## 🔍 Estat de Validació i Qualitat

- `flutter analyze lib/`: **0 errors, 0 advertències** en la totalitat del projecte.
- Codi adaptat estrictament a les regles del projecte (`global-soca-rules.md`): Clean Architecture, Riverpod modern, sense BuildContext en lògica, Null Safety estricte.
