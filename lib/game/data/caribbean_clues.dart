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
          'The blue honours the sea, the yellow stripes represent the sun\'s wealth, and the red star symbolises this island\'s right to self-determination, adopted upon separate status in 1986.',
    ),
    'BB': CaribbeanClueData(
      nickname: 'The Gem of the Caribbean Sea',
      famousLandmark: 'Harrison\'s Cave',
      famousPerson: 'Rihanna',
      flag:
          'The broken trident of Poseidon symbolises independence from colonial rule; ultramarine reflects sea and sky, while gold honours the island\'s famous sand and sunshine.',
    ),
    'BS': CaribbeanClueData(
      nickname: 'The Island of Bimini',
      famousLandmark: 'Exuma Cays Land and Sea Park',
      famousPerson: 'Sir Lynden Pindling',
      flag:
          'Aquamarine represents the sea and sky, gold the island\'s sandy beaches, and the black triangle the unity of the people forging ahead toward independence, achieved in 1973.',
    ),
    'CU': CaribbeanClueData(
      nickname: 'The Pearl of the Antilles',
      famousLandmark: 'Old Havana',
      famousPerson: 'Jose Marti',
      flag:
          'Designed by exiles from the island in 1849, the Lone Star evokes Latin American liberation ideals; the red triangle represents blood spilled for freedom in the struggle against Spanish colonial rule.',
    ),
    'CW': CaribbeanClueData(
      nickname: 'The Island of Diversity',
      famousLandmark: 'Handelskade Waterfront',
      famousPerson: 'Tula',
      flag:
          'The blue and yellow honour the colours of the Dutch House of Nassau; the two stars represent Curaçao and Klein Curaçao, adopted when the island gained autonomy within the Kingdom of the Netherlands in 2010.',
    ),
    'DM': CaribbeanClueData(
      nickname: 'The Nature Isle of the Caribbean',
      famousLandmark: 'Boiling Lake',
      famousPerson: 'Jean Rhys',
      flag:
          'The Sisserou parrot is found nowhere else on Earth, making this nation\'s flag unique for featuring a purple bird; green honours the lush rainforest of this island called the Nature Isle.',
    ),
    'DO': CaribbeanClueData(
      nickname: 'The Land of Merengue',
      famousLandmark: 'Colonial Zone of Santo Domingo',
      famousPerson: 'Juan Pablo Duarte',
      flag:
          'The white cross unifying blue and red was inspired by the French tricolour and Haitian flag; founders Duarte, Mella, and Sánchez created it in 1844 to symbolise faith and the sacrifice of independence.',
    ),
    'HT': CaribbeanClueData(
      nickname: 'The Pearl of the Antilles',
      famousLandmark: 'Citadelle Laferriere',
      famousPerson: 'Toussaint Louverture',
      flag:
          'Born from the revolution of 1803, when rebels tore the white from the French tricolour to reject colonialism; blue and red united all freedom fighters in the world\'s first successful slave revolt.',
    ),
    'JM': CaribbeanClueData(
      nickname: 'The Land of Wood and Water',
      famousLandmark: 'Blue Mountains',
      famousPerson: 'Bob Marley',
      flag:
          'Gold represents the island\'s natural wealth, black the strength of the people, and green the lush landscape; the design deliberately avoids red, unlike most Commonwealth flags, adopted at independence in 1962.',
    ),
    'KN': CaribbeanClueData(
      nickname: 'The Sugar City',
      famousLandmark: 'Brimstone Hill Fortress',
      famousPerson: 'Robert Bradshaw',
      flag:
          'Green honours the fertile land, red the African heritage of its people, and the two stars represent the two-island federation; black recalls the African diaspora\'s contribution to the nation.',
    ),
    'LC': CaribbeanClueData(
      nickname: 'The Helen of the West Indies',
      famousLandmark: 'The Pitons',
      famousPerson: 'Derek Walcott',
      flag:
          'The black and white triangles represent the Piton mountains and the island\'s racial heritage in harmony; the gold triangle symbolises sunshine, and blue the sea and sky, redesigned with a larger triangle in 2002.',
    ),
    'PR': CaribbeanClueData(
      nickname: 'The Island of Enchantment',
      famousLandmark: 'El Morro Fortress',
      famousPerson: 'Roberto Clemente',
      flag:
          'Designed by Cuban independence leader Ramón Emeterio Betances in 1895 as a mirror of Cuba\'s flag, asserting shared liberation ideals; the lone star represents the island\'s statehood aspirations.',
    ),
    'TT': CaribbeanClueData(
      nickname: 'The Land of the Hummingbird',
      famousLandmark: 'Pitch Lake',
      famousPerson: 'V. S. Naipaul',
      flag:
          'Red represents the warmth of the people and fire of the sun, black honours the African heritage of this twin-island nation, and white symbolises the sea uniting the nation; adopted at independence in 1962.',
    ),
    'VC': CaribbeanClueData(
      nickname: 'The Gem of the Antilles',
      famousLandmark: 'La Soufriere Volcano',
      famousPerson: 'Joseph Chatoyer',
      flag:
          'The three diamonds arranged in a V honour the nation\'s name meaning "blessed"; blue represents the sky and sea, yellow the golden sands, and green the lush vegetation of this Windward Island nation.',
    ),
  };
}
