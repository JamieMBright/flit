/// Caribbean island nation clue data for the regional game mode.
/// Covers all 14 Caribbean island nations and territories.
library;

class CaribbeanClueData {
  const CaribbeanClueData({
    required this.nickname,
    required this.famousLandmark,
    required this.famousPerson,
    required this.flag,
  });

  final String nickname;
  final String famousLandmark;
  final String famousPerson;
  final String flag;
}

abstract class CaribbeanClues {
  static const Map<String, CaribbeanClueData> data = {
    'AW': CaribbeanClueData(
      nickname: 'The Happy Island',
      famousLandmark: 'Natural Bridge',
      famousPerson: 'Betico Croes',
      flag:
          'Blue field with two narrow yellow horizontal stripes at bottom and red four-pointed star at upper hoist',
    ),
    'BB': CaribbeanClueData(
      nickname: 'The Gem of the Caribbean Sea',
      famousLandmark: 'Harrison\'s Cave',
      famousPerson: 'Rihanna',
      flag:
          'Vertical ultramarine, gold, and ultramarine stripes with black trident head on gold center stripe',
    ),
    'BS': CaribbeanClueData(
      nickname: 'The Island of Bimini',
      famousLandmark: 'Exuma Cays Land and Sea Park',
      famousPerson: 'Sir Lynden Pindling',
      flag:
          'Horizontal aquamarine, gold, and aquamarine stripes with black equilateral triangle at hoist',
    ),
    'CU': CaribbeanClueData(
      nickname: 'The Pearl of the Antilles',
      famousLandmark: 'Old Havana',
      famousPerson: 'Jose Marti',
      flag:
          'Five alternating blue and white horizontal stripes with red triangle at hoist bearing white star',
    ),
    'CW': CaribbeanClueData(
      nickname: 'The Island of Diversity',
      famousLandmark: 'Handelskade Waterfront',
      famousPerson: 'Tula',
      flag:
          'Blue field with horizontal yellow stripe in lower third and two white five-pointed stars at upper hoist',
    ),
    'DM': CaribbeanClueData(
      nickname: 'The Nature Isle of the Caribbean',
      famousLandmark: 'Boiling Lake',
      famousPerson: 'Jean Rhys',
      flag:
          'Green field with cross of yellow, black, and white stripes and red circle with Sisserou parrot in center',
    ),
    'DO': CaribbeanClueData(
      nickname: 'The Land of Merengue',
      famousLandmark: 'Colonial Zone of Santo Domingo',
      famousPerson: 'Juan Pablo Duarte',
      flag:
          'White cross dividing blue and red rectangles with coat of arms in center',
    ),
    'HT': CaribbeanClueData(
      nickname: 'The Pearl of the Antilles',
      famousLandmark: 'Citadelle Laferriere',
      famousPerson: 'Toussaint Louverture',
      flag:
          'Horizontal blue and red stripes with white rectangle bearing coat of arms in center',
    ),
    'JM': CaribbeanClueData(
      nickname: 'The Land of Wood and Water',
      famousLandmark: 'Blue Mountains',
      famousPerson: 'Bob Marley',
      flag:
          'Gold diagonal cross dividing green triangles at top and bottom and black triangles at hoist and fly',
    ),
    'KN': CaribbeanClueData(
      nickname: 'The Sugar City',
      famousLandmark: 'Brimstone Hill Fortress',
      famousPerson: 'Robert Bradshaw',
      flag:
          'Diagonal green and red halves divided by black stripe bordered in yellow with two white stars on black',
    ),
    'LC': CaribbeanClueData(
      nickname: 'The Helen of the West Indies',
      famousLandmark: 'The Pitons',
      famousPerson: 'Derek Walcott',
      flag:
          'Blue field with golden triangle before black and white triangles forming mountain shape in center',
    ),
    'PR': CaribbeanClueData(
      nickname: 'The Island of Enchantment',
      famousLandmark: 'El Morro Fortress',
      famousPerson: 'Roberto Clemente',
      flag:
          'Five alternating red and white horizontal stripes with blue triangle at hoist bearing white star',
    ),
    'TT': CaribbeanClueData(
      nickname: 'The Land of the Hummingbird',
      famousLandmark: 'Pitch Lake',
      famousPerson: 'V. S. Naipaul',
      flag:
          'Red field with diagonal black stripe bordered in white from upper hoist to lower fly',
    ),
    'VC': CaribbeanClueData(
      nickname: 'The Gem of the Antilles',
      famousLandmark: 'La Soufriere Volcano',
      famousPerson: 'Joseph Chatoyer',
      flag:
          'Vertical blue, yellow, and green stripes with three green diamonds in V pattern on yellow stripe',
    ),
  };
}
