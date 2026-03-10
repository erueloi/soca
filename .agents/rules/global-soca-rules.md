---
trigger: always_on
---

# Soca App - AI Agent Rules

## Context del Projecte
Ets un desenvolupador expert en Flutter i Dart. Aquest és un projecte de gestió agrícola i d'espais (Horticultura, Arbres, Construcció, Clima, Tasques). Utilitzem Firebase per al backend (Auth, Firestore, Cloud Functions en TypeScript, Storage).

## Arquitectura del Codi (Molt Important)
El projecte segueix una arquitectura Feature-Driven basada en Clean Architecture. NO barregis lògica de negoci amb UI. Quan creïs una nova funcionalitat, has de seguir estrictament aquesta estructura de carpetes dins de `lib/features/nom_funcionalitat/`:
1. `/domain/entities/`: Models de dades purs i entitats (ex: `tree.dart`). Cap dependència de Flutter aquí.
2. `/data/repositories/`: Lògica de connexió amb Firebase o APIs externes.
3. `/presentation/providers/`: Gestió de l'estat.
4. `/presentation/pages/`: Pantalles principals.
5. `/presentation/widgets/`: Components de UI reutilitzables i petits.

## Principis SOLID i Gestió d'Estat
- **Estat (Riverpod):** Utilitzem `flutter_riverpod`. Utilitza les classes modernes `Notifier` i `AsyncNotifier` (o les anotacions `@riverpod` si utilitzem generació de codi). **MAI** utilitzis el depreciat `StateNotifier`.
- **Injecció de Dependències:** Els Repositoris i Serveis s'han d'injectar als Providers a través del `ref.watch()`. Mai instanciïs classes de lògica directament dins d'una altra classe.
- **Frontera del BuildContext:** Està TOTALMENT PROHIBIT passar el `BuildContext` a un Provider, Repositori o Servei. El context només viu a la capa de UI (`/presentation/pages/` i `/widgets/`).

## Regles de Dart i Flutter
- Fes servir *Null Safety* de manera estricta.
- Prefereix `ConsumerWidget` / `StatelessWidget` combinat amb Providers en lloc de `StatefulWidget` sempre que sigui possible.
- Extreu els ginys complexos a mètodes privats o a fitxers separats dins de la carpeta `/widgets/` per mantenir els fitxers de les pàgines curts (màxim 200-300 línies).
- Fes servir l'arxiu `lib/core/theme/app_theme.dart` per a tots els colors, tipografies i estils. NO utilitzis colors *hardcoded* (ex: `Colors.red`) a les vistes.
- Evita fer servir `Strings` de text *hardcodejats* a la UI si es poden agrupar en constants o fitxers de localització.

## Gestió d'Errors
- Els errors s'han de gestionar a través de les classes base definides a `lib/core/failure.dart`. No llancis excepcions genèriques (`throw Exception()`) a la capa de UI. Els repositoris han de capturar les fallades de Firebase i retornar errors controlats.

## Regles de Backend i Serveis
- Totes crides directes a Firebase s'han de fer o bé als repositoris de cada *feature*, o bé a través del `firebase_service.dart` dins de `lib/core/services/`.
- Si modifiques l'estructura de dades de Firestore, actualitza automàticament les regles a `firestore.rules`.
- El codi de les Cloud Functions (`/functions/src/`) s'ha d'escriure en TypeScript estricte, amb tipatge fort i promeses ben resoltes.