/// Latin American country clue data for the regional game mode.
/// Covers all 26 Latin American and select Caribbean nations in this grouping.
library;

class LatinAmericaClueData {
  const LatinAmericaClueData({
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

abstract class LatinAmericaClues {
  static const Map<String, LatinAmericaClueData> data = {
    'AR': LatinAmericaClueData(
      nickname: 'The Land of Silver',
      famousLandmark: 'Iguazu Falls',
      famousPerson: 'Lionel Messi',
      flag:
          'Horizontal light blue, white, and light blue stripes with golden Sun of May on white stripe',
    ),
    'BO': LatinAmericaClueData(
      nickname: 'The Tibet of the Americas',
      famousLandmark: 'Salar de Uyuni',
      famousPerson: 'Simon Bolivar',
      flag:
          'Horizontal red, yellow, and green stripes with coat of arms on yellow stripe',
    ),
    'BR': LatinAmericaClueData(
      nickname: 'The Land of the Holy Cross',
      famousLandmark: 'Christ the Redeemer',
      famousPerson: 'Pele',
      flag:
          'Green field with large yellow diamond and blue globe with white stars and curved white band',
    ),
    'BZ': LatinAmericaClueData(
      nickname: 'The Jewel in the Heart of the Caribbean Basin',
      famousLandmark: 'Great Blue Hole',
      famousPerson: 'George Cadle Price',
      flag:
          'Blue field with red stripes at top and bottom and circular coat of arms in center',
    ),
    'CL': LatinAmericaClueData(
      nickname: 'The Land of Poets',
      famousLandmark: 'Easter Island Moai Statues',
      famousPerson: 'Pablo Neruda',
      flag:
          'Lower red half and upper half divided into white section and blue square with white star',
    ),
    'CO': LatinAmericaClueData(
      nickname: 'The Gateway to South America',
      famousLandmark: 'Lost City (Ciudad Perdida)',
      famousPerson: 'Gabriel Garcia Marquez',
      flag:
          'Horizontal yellow, blue, and red stripes with yellow taking upper half',
    ),
    'CR': LatinAmericaClueData(
      nickname: 'The Rich Coast',
      famousLandmark: 'Arenal Volcano',
      famousPerson: 'Oscar Arias Sanchez',
      flag:
          'Horizontal blue, white, red, white, and blue stripes with wider red center stripe',
    ),
    'CU': LatinAmericaClueData(
      nickname: 'The Pearl of the Antilles',
      famousLandmark: 'Old Havana',
      famousPerson: 'Jose Marti',
      flag:
          'Five alternating blue and white horizontal stripes with red triangle at hoist bearing white star',
    ),
    'DO': LatinAmericaClueData(
      nickname: 'The Land of Merengue',
      famousLandmark: 'Colonial Zone of Santo Domingo',
      famousPerson: 'Juan Pablo Duarte',
      flag:
          'White cross dividing blue and red rectangles with coat of arms in center',
    ),
    'EC': LatinAmericaClueData(
      nickname: 'The Land of the Equator',
      famousLandmark: 'Galapagos Islands',
      famousPerson: 'Eugenio Espejo',
      flag:
          'Horizontal yellow, blue, and red stripes with yellow taking upper half and coat of arms in center',
    ),
    'GT': LatinAmericaClueData(
      nickname: 'The Land of Eternal Spring',
      famousLandmark: 'Tikal',
      famousPerson: 'Rigoberta Menchu',
      flag:
          'Vertical light blue, white, and light blue stripes with coat of arms on white stripe',
    ),
    'GY': LatinAmericaClueData(
      nickname: 'The Land of Many Waters',
      famousLandmark: 'Kaieteur Falls',
      famousPerson: 'Cheddi Jagan',
      flag:
          'Green field with red and black triangles forming arrow shape bordered by yellow and white',
    ),
    'HN': LatinAmericaClueData(
      nickname: 'The Land of the Great Depths',
      famousLandmark: 'Copan Ruins',
      famousPerson: 'Francisco Morazan',
      flag:
          'Horizontal blue, white, and blue stripes with five blue stars in X pattern on white stripe',
    ),
    'HT': LatinAmericaClueData(
      nickname: 'The Pearl of the Antilles',
      famousLandmark: 'Citadelle Laferriere',
      famousPerson: 'Toussaint Louverture',
      flag:
          'Horizontal blue and red stripes with white rectangle bearing coat of arms in center',
    ),
    'JM': LatinAmericaClueData(
      nickname: 'The Land of Wood and Water',
      famousLandmark: 'Blue Mountains',
      famousPerson: 'Bob Marley',
      flag:
          'Gold diagonal cross dividing green triangles at top and bottom and black triangles at hoist and fly',
    ),
    'MX': LatinAmericaClueData(
      nickname: 'The Land of the Aztecs',
      famousLandmark: 'Chichen Itza',
      famousPerson: 'Frida Kahlo',
      flag:
          'Vertical green, white, and red stripes with coat of arms featuring eagle on cactus on white stripe',
    ),
    'NI': LatinAmericaClueData(
      nickname: 'The Land of Lakes and Volcanoes',
      famousLandmark: 'Lake Nicaragua',
      famousPerson: 'Ruben Dario',
      flag:
          'Horizontal blue, white, and blue stripes with coat of arms triangle on white stripe',
    ),
    'PA': LatinAmericaClueData(
      nickname: 'The Bridge of the World',
      famousLandmark: 'Panama Canal',
      famousPerson: 'Omar Torrijos',
      flag:
          'Four rectangles of white with blue star, red, blue, and white with red star',
    ),
    'PE': LatinAmericaClueData(
      nickname: 'The Land of the Incas',
      famousLandmark: 'Machu Picchu',
      famousPerson: 'Mario Vargas Llosa',
      flag:
          'Vertical red, white, and red stripes with coat of arms on white stripe',
    ),
    'PR': LatinAmericaClueData(
      nickname: 'The Island of Enchantment',
      famousLandmark: 'El Morro Fortress',
      famousPerson: 'Roberto Clemente',
      flag:
          'Five alternating red and white horizontal stripes with blue triangle at hoist bearing white star',
    ),
    'PY': LatinAmericaClueData(
      nickname: 'The Heart of South America',
      famousLandmark: 'Jesuit Missions of La Santisima Trinidad',
      famousPerson: 'Augusto Roa Bastos',
      flag:
          'Horizontal red, white, and blue stripes with different emblems on front and back center',
    ),
    'SR': LatinAmericaClueData(
      nickname: 'The Greenest Country on Earth',
      famousLandmark: 'Central Suriname Nature Reserve',
      famousPerson: 'Johan Ferrier',
      flag:
          'Horizontal green, white, red, white, and green stripes with yellow star on red center stripe',
    ),
    'SV': LatinAmericaClueData(
      nickname: 'The Land of Volcanoes',
      famousLandmark: 'Joya de Ceren',
      famousPerson: 'Oscar Arnulfo Romero',
      flag:
          'Horizontal blue, white, and blue stripes with coat of arms on white stripe',
    ),
    'TT': LatinAmericaClueData(
      nickname: 'The Land of the Hummingbird',
      famousLandmark: 'Pitch Lake',
      famousPerson: 'V. S. Naipaul',
      flag:
          'Red field with diagonal black stripe bordered in white from upper hoist to lower fly',
    ),
    'UY': LatinAmericaClueData(
      nickname: 'The Purple Land',
      famousLandmark: 'Colonia del Sacramento',
      famousPerson: 'Jose Gervasio Artigas',
      flag:
          'Nine alternating white and blue horizontal stripes with white canton bearing golden Sun of May',
    ),
    'VE': LatinAmericaClueData(
      nickname: 'The Land of Grace',
      famousLandmark: 'Angel Falls',
      famousPerson: 'Simon Bolivar',
      flag:
          'Horizontal yellow, blue, and red stripes with arc of eight white stars on blue stripe',
    ),
  };
}
