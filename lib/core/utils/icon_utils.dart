import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class IconUtils {
  // Known list for self-healing legacy data (and for the picker)
  static final Map<String, IconData> botanicalIcons = {
    // General / Arbres
    'Arbre': Icons.park,
    'Bosc': Icons.forest,
    'Natura': Icons.nature,
    'Natura (Humà)': Icons.nature_people,
    'Muntanya': Icons.landscape,
    'Terreny': Icons.terrain,

    // Agricultura / Cultiu
    'Agricultura': Icons.agriculture, // Tractor
    'Gespa': Icons.grass,
    'Blat / Gra': Icons.grain, // Agriculture generic
    'Compost': Icons.compost,
    'Jardí': Icons.yard,
    'Flor': Icons.local_florist,
    'Fulla / Spa': Icons.spa,
    'Eco': Icons.eco,
    'Rusc (Abelles)': Icons.hive,
    'Plagues': Icons.pest_control, // Bug
    'Bestiola': Icons.bug_report,

    // Aigua / Reg
    'Aigua': Icons.water_drop,
    'Regadora': Icons.shower, // Sprinkler substitute
    'Oceà / Mar': Icons.water,
    'Humitat': Icons.opacity,

    // Clima
    'Sol': Icons.sunny,
    'Núvol': Icons.cloud,
    'Vent': Icons.air,
    'Tempesta': Icons.thunderstorm,
    'Temperatura': Icons.thermostat,

    // Eines / Estructures
    'Eina': Icons.handyman,
    'Tanca': Icons.fence,
    'Casa': Icons.house,
    'Magatzem': Icons.warehouse,

    // Fruits / Altres
    'Poma': Icons.apple,
    'Reciclatge': Icons.recycling,
    'Fusta': Icons.forest_outlined,
    'Bolet': MdiIcons.mushroom,
    'Palmera': MdiIcons.palmTree,
    'Flor Vintage': Icons.filter_vintage,

    // MDI Extensions
    'Blat de Moro': MdiIcons.corn,
    'Ordi / Blat': MdiIcons.barley,
    'Pastanaga': MdiIcons.carrot,
    'Raïm': MdiIcons.fruitGrapes,
    'Kirsch / Cirera': MdiIcons.fruitCherries,
    'Citrus': MdiIcons.fruitCitrus,
    'Pi': MdiIcons.pineTree,
    'Silo': MdiIcons.silo,
    'Graner': MdiIcons.barn,
    'Tractor (MDI)': MdiIcons.tractor,
    'Porc': MdiIcons.pig,
    'Vaca': MdiIcons.cow,
    'Gos': MdiIcons.dog,
    'Gat': MdiIcons.cat,
    'Brot / Planter': MdiIcons.sprout,
    'Llavors': MdiIcons.seed,
  };

  static IconData resolveIcon(int code, String? family) {
    // 1. Try to find in our known botanical set (Robust fallback for MDI)
    try {
      final known = botanicalIcons.values.firstWhere(
        (icon) => icon.codePoint == code,
      );
      return known;
    } catch (_) {}

    // 2. Fallback to standard construction
    return IconData(
      code,
      fontFamily: family ?? 'MaterialIcons',
      fontPackage: (family == 'Material Design Icons')
          ? 'material_design_icons_flutter'
          : null,
    );
  }
}
