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
          'The Sun of May commemorates the 1810 revolution against Spain; the sky-blue stripes echo the blue of the River Plate and the cloudless pampas sky.',
    ),
    'BO': LatinAmericaClueData(
      nickname: 'The Tibet of the Americas',
      famousLandmark: 'Salar de Uyuni',
      famousPerson: 'Simon Bolivar',
      flag:
          'Red for the blood of patriots, yellow for this nation\'s mineral wealth, and green for the fertile valleys — colors carried from the 1825 independence movement led by Simón Bolívar.',
    ),
    'BR': LatinAmericaClueData(
      nickname: 'The Land of the Holy Cross',
      famousLandmark: 'Christ the Redeemer',
      famousPerson: 'Pele',
      flag:
          'The green and gold recall the House of Braganza and the Amazon; the celestial globe shows the Rio de Janeiro sky at the moment of independence in 1822, with the motto "Order and Progress."',
    ),
    'BZ': LatinAmericaClueData(
      nickname: 'The Jewel in the Heart of the Caribbean Basin',
      famousLandmark: 'Great Blue Hole',
      famousPerson: 'George Cadle Price',
      flag:
          'The blue represents the People\'s United Party, the red the UDP; their union on independence in 1981 symbolises national unity forged from British colonial rule.',
    ),
    'CL': LatinAmericaClueData(
      nickname: 'The Land of Poets',
      famousLandmark: 'Easter Island Moai Statues',
      famousPerson: 'Pablo Neruda',
      flag:
          'The lone star was borrowed from the Texas Lone Star flag as an emblem of sovereignty; red represents the blood of patriots who died fighting Spanish rule in the 1810s.',
    ),
    'CO': LatinAmericaClueData(
      nickname: 'The Gateway to South America',
      famousLandmark: 'Lost City (Ciudad Perdida)',
      famousPerson: 'Gabriel Garcia Marquez',
      flag:
          'The colors derive from the short-lived Gran federation — yellow for sovereignty and justice, blue for the oceans, red for the blood shed in the independence wars of the 1810s.',
    ),
    'CR': LatinAmericaClueData(
      nickname: 'The Rich Coast',
      famousLandmark: 'Arenal Volcano',
      famousPerson: 'Oscar Arias Sanchez',
      flag:
          'Adapted from the Federal Republic of Central America flag, the red was added in 1848 inspired by France\'s tricolor; this nation uniquely added it after abolishing its army in 1948.',
    ),
    'CU': LatinAmericaClueData(
      nickname: 'The Pearl of the Antilles',
      famousLandmark: 'Old Havana',
      famousPerson: 'Jose Marti',
      flag:
          'Designed by poet Miguel Teurbe Tolón in 1849, the three blue stripes represent this nation\'s three military districts; the red triangle stands for the blood of patriots and Freemasonic equality.',
    ),
    'DO': LatinAmericaClueData(
      nickname: 'The Land of Merengue',
      famousLandmark: 'Colonial Zone of Santo Domingo',
      famousPerson: 'Juan Pablo Duarte',
      flag:
          'The white cross was carried by the founding father Juan Pablo Duarte\'s secret liberation society La Trinitaria in 1844; it divides blue for liberty and red for the blood of heroes.',
    ),
    'EC': LatinAmericaClueData(
      nickname: 'The Land of the Equator',
      famousLandmark: 'Galapagos Islands',
      famousPerson: 'Eugenio Espejo',
      flag:
          'Sharing Gran Colombia\'s colors, this nation\'s flag dates to 1860 and emphasizes its equatorial position; the coat of arms features the first steamboat to sail the Pacific — the Guayas.',
    ),
    'GT': LatinAmericaClueData(
      nickname: 'The Land of Eternal Spring',
      famousLandmark: 'Tikal',
      famousPerson: 'Rigoberta Menchu',
      flag:
          'Inherited from the Federal Republic of Central America, the sky-blue stripes represent the Pacific and Caribbean coasts flanking a white highland homeland; the quetzal on the arms symbolises liberty.',
    ),
    'GY': LatinAmericaClueData(
      nickname: 'The Land of Many Waters',
      famousLandmark: 'Kaieteur Falls',
      famousPerson: 'Cheddi Jagan',
      flag:
          'Designed by art teacher David Doris in 1966, the green represents the forests, the golden arrowhead points to a dynamic future, and the red and black warn enemies that this nation will defend its resources.',
    ),
    'HN': LatinAmericaClueData(
      nickname: 'The Land of the Great Depths',
      famousLandmark: 'Copan Ruins',
      famousPerson: 'Francisco Morazan',
      flag:
          'The five stars added in 1866 represent the five Central American nations of the old federation; the blue recalls the two oceans that this nation touches — an exceptional geographical distinction.',
    ),
    'HT': LatinAmericaClueData(
      nickname: 'The Pearl of the Antilles',
      famousLandmark: 'Citadelle Laferriere',
      famousPerson: 'Toussaint Louverture',
      flag:
          'The founders tore the white from the French tricolor in 1803 to symbolize the expulsion of white colonialism; the blue and red halves unite Black and mixed-race freedom fighters.',
    ),
    'JM': LatinAmericaClueData(
      nickname: 'The Land of Wood and Water',
      famousLandmark: 'Blue Mountains',
      famousPerson: 'Bob Marley',
      flag:
          'Adopted at independence in 1962, the gold saltire represents natural wealth and sunlight; black stands for the African heritage of the majority, and green for the island\'s lush vegetation.',
    ),
    'MX': LatinAmericaClueData(
      nickname: 'The Land of the Aztecs',
      famousLandmark: 'Chichen Itza',
      famousPerson: 'Frida Kahlo',
      flag:
          'The Aztec legend foretold founding a city where an eagle devoured a serpent on a cactus — that vision, seen at Tenochtitlán in 1325, anchors the coat of arms at the heart of the flag.',
    ),
    'NI': LatinAmericaClueData(
      nickname: 'The Land of Lakes and Volcanoes',
      famousLandmark: 'Lake Nicaragua',
      famousPerson: 'Ruben Dario',
      flag:
          'Derived from the Federal Republic of Central America, the two blue bands represent the oceans; the rainbow triangle in the arms is unique among national flags, symbolising peace and equality.',
    ),
    'PA': LatinAmericaClueData(
      nickname: 'The Bridge of the World',
      famousLandmark: 'Panama Canal',
      famousPerson: 'Omar Torrijos',
      flag:
          'Blue and red represent the two main parties that agreed to share power at independence in 1903; the stars symbolise the integrity and purity of each party\'s ideals rather than any single faction.',
    ),
    'PE': LatinAmericaClueData(
      nickname: 'The Land of the Incas',
      famousLandmark: 'Machu Picchu',
      famousPerson: 'Mario Vargas Llosa',
      flag:
          'The red and white were chosen by José de San Martín in 1820 to honour the streaks of dawn he saw over the Andes; they remain unchanged since independence as a symbol of sacrifice and purity.',
    ),
    'PR': LatinAmericaClueData(
      nickname: 'The Island of Enchantment',
      famousLandmark: 'El Morro Fortress',
      famousPerson: 'Roberto Clemente',
      flag:
          'Designed by Ramón Emeterio Betances in 1895 as a deliberate inversion of the Cuban flag, it expressed solidarity with Caribbean liberation; the lone star stands for the commonwealth\'s aspiration.',
    ),
    'PY': LatinAmericaClueData(
      nickname: 'The Heart of South America',
      famousLandmark: 'Jesuit Missions of La Santisima Trinidad',
      famousPerson: 'Augusto Roa Bastos',
      flag:
          'This country is the only nation with a flag that differs on each side — the obverse bears the Treasury seal and the reverse the lion of liberty, both inherited from its 1811 declaration of independence.',
    ),
    'SR': LatinAmericaClueData(
      nickname: 'The Greenest Country on Earth',
      famousLandmark: 'Central Suriname Nature Reserve',
      famousPerson: 'Johan Ferrier',
      flag:
          'Adopted at independence in 1975, the green stripes honour the rainforest covering 90% of the country; the golden star was inspired by Indonesia\'s flag, reflecting this nation\'s ties to its former Dutch colonisers\' Asian empire.',
    ),
    'SV': LatinAmericaClueData(
      nickname: 'The Land of Volcanoes',
      famousLandmark: 'Joya de Ceren',
      famousPerson: 'Oscar Arnulfo Romero',
      flag:
          'Drawn from the Central American Federation flag of 1823, the two blue bands echo the Pacific and Caribbean; the Phrygian cap in the arms commemorates the 1821 independence from three centuries of Spanish rule.',
    ),
    'TT': LatinAmericaClueData(
      nickname: 'The Land of the Hummingbird',
      famousLandmark: 'Pitch Lake',
      famousPerson: 'V. S. Naipaul',
      flag:
          'Designed by Carlisle Chang in 1962, the black diagonal represents the earth and the dedication of the people; red stands for the nation\'s vitality, and white for the sea surrounding these twin islands.',
    ),
    'UY': LatinAmericaClueData(
      nickname: 'The Purple Land',
      famousLandmark: 'Colonia del Sacramento',
      famousPerson: 'Jose Gervasio Artigas',
      flag:
          'The nine stripes represent the original departments of 1830; the Sun of May commemorates the May Revolution of 1810 and links this nation to its Argentine neighbour, both children of the Viceroyalty of the Río de la Plata.',
    ),
    'VE': LatinAmericaClueData(
      nickname: 'The Land of Grace',
      famousLandmark: 'Angel Falls',
      famousPerson: 'Simon Bolivar',
      flag:
          'The seven original stars matched this nation\'s provinces at independence in 1811; an eighth was added by Chávez in 2006 to honour Simón Bolívar\'s dream of including Guayana as a founding province.',
    ),
  };
}
