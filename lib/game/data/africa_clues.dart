/// African country clue data for the regional game mode.
/// Covers all 54 recognized African nations.
library;

class AfricaClueData {
  const AfricaClueData({
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

abstract class AfricaClues {
  static const Map<String, AfricaClueData> data = {
    'AO': AfricaClueData(
      nickname: 'The Land of the Giant Sable',
      famousLandmark: 'Kalandula Falls',
      famousPerson: 'Agostinho Neto',
      flag:
          'Horizontal red and black stripes with yellow machete, gear, and star emblem',
    ),
    'BF': AfricaClueData(
      nickname: 'Land of Upright People',
      famousLandmark: 'Ruins of Loropeni',
      famousPerson: 'Thomas Sankara',
      flag:
          'Horizontal red and green stripes with yellow five-pointed star in center',
    ),
    'BI': AfricaClueData(
      nickname: 'The Heart of Africa',
      famousLandmark: 'Source of the Nile',
      famousPerson: 'Louis Rwagasore',
      flag:
          'White diagonal cross dividing red and green triangles with three red and green stars in center circle',
    ),
    'BJ': AfricaClueData(
      nickname: 'The Birthplace of Voodoo',
      famousLandmark: 'Royal Palaces of Abomey',
      famousPerson: 'Angelique Kidjo',
      flag:
          'Green vertical stripe at hoist with horizontal yellow and red stripes',
    ),
    'BW': AfricaClueData(
      nickname: 'The Gem of Africa',
      famousLandmark: 'Okavango Delta',
      famousPerson: 'Seretse Khama',
      flag:
          'Light blue field with horizontal black stripe bordered by white stripes in center',
    ),
    'CD': AfricaClueData(
      nickname: 'The Congo',
      famousLandmark: 'Virunga National Park',
      famousPerson: 'Patrice Lumumba',
      flag:
          'Sky blue field with diagonal red stripe bordered in yellow and yellow star in upper left',
    ),
    'CF': AfricaClueData(
      nickname: 'The Heart of Central Africa',
      famousLandmark: 'Dzanga-Sangha Reserve',
      famousPerson: 'Barthelemy Boganda',
      flag:
          'Four horizontal stripes of blue, white, green, yellow with vertical red stripe and yellow star',
    ),
    'CG': AfricaClueData(
      nickname: 'The Land of the Emerald Forest',
      famousLandmark: 'Odzala-Kokoua National Park',
      famousPerson: 'Denis Sassou Nguesso',
      flag:
          'Green and red triangles divided by diagonal yellow stripe from lower hoist to upper fly',
    ),
    'CI': AfricaClueData(
      nickname: 'Land of the Elephants',
      famousLandmark: 'Basilica of Our Lady of Peace',
      famousPerson: 'Didier Drogba',
      flag: 'Vertical stripes of orange, white, and green from hoist to fly',
    ),
    'CM': AfricaClueData(
      nickname: 'Africa in Miniature',
      famousLandmark: 'Mount Cameroon',
      famousPerson: 'Samuel Eto\'o',
      flag:
          'Vertical stripes of green, red, and yellow with yellow star on red center stripe',
    ),
    'CV': AfricaClueData(
      nickname: 'The Islands of Cape Verde',
      famousLandmark: 'Pico do Fogo Volcano',
      famousPerson: 'Cesaria Evora',
      flag:
          'Blue field with horizontal red and white stripes and ten yellow stars in circle',
    ),
    'DJ': AfricaClueData(
      nickname: 'The Gateway to the Red Sea',
      famousLandmark: 'Lake Assal',
      famousPerson: 'Hassan Gouled Aptidon',
      flag:
          'Light blue and green horizontal halves with white triangle at hoist bearing red star',
    ),
    'DZ': AfricaClueData(
      nickname: 'The Land of Cherries and Dates',
      famousLandmark: 'Casbah of Algiers',
      famousPerson: 'Albert Camus',
      flag:
          'Vertical green and white halves with red crescent and star in center',
    ),
    'EG': AfricaClueData(
      nickname: 'The Land of the Pharaohs',
      famousLandmark: 'Great Pyramids of Giza',
      famousPerson: 'Cleopatra',
      flag:
          'Horizontal red, white, and black stripes with golden eagle emblem on white stripe',
    ),
    'EH': AfricaClueData(
      nickname: 'The Last Colony in Africa',
      famousLandmark: 'Dakhla Bay',
      famousPerson: 'Mohamed Abdelaziz',
      flag:
          'Black, white, and green horizontal stripes with red triangle at hoist and red crescent and star on white',
    ),
    'ER': AfricaClueData(
      nickname: 'The Red Sea State',
      famousLandmark: 'Dahlak Archipelago',
      famousPerson: 'Isaias Afwerki',
      flag:
          'Red triangle at hoist with green and blue triangles and yellow olive wreath emblem',
    ),
    'ET': AfricaClueData(
      nickname: 'The Roof of Africa',
      famousLandmark: 'Rock-Hewn Churches of Lalibela',
      famousPerson: 'Haile Selassie',
      flag:
          'Horizontal green, yellow, and red stripes with blue circle and yellow star emblem in center',
    ),
    'GA': AfricaClueData(
      nickname: 'The Land of the Surfing Hippos',
      famousLandmark: 'Lope National Park',
      famousPerson: 'Omar Bongo',
      flag: 'Horizontal green, yellow, and blue stripes of equal width',
    ),
    'GH': AfricaClueData(
      nickname: 'The Gateway to West Africa',
      famousLandmark: 'Cape Coast Castle',
      famousPerson: 'Kwame Nkrumah',
      flag:
          'Horizontal red, gold, and green stripes with black five-pointed star on gold stripe',
    ),
    'GM': AfricaClueData(
      nickname: 'The Smiling Coast of Africa',
      famousLandmark: 'Kunta Kinteh Island',
      famousPerson: 'Dawda Jawara',
      flag:
          'Horizontal red, blue, and green stripes separated by thin white borders',
    ),
    'GN': AfricaClueData(
      nickname: 'The Water Tower of West Africa',
      famousLandmark: 'Mount Nimba',
      famousPerson: 'Ahmed Sekou Toure',
      flag: 'Vertical red, yellow, and green stripes from hoist to fly',
    ),
    'GQ': AfricaClueData(
      nickname: 'The Land of Fernando Po',
      famousLandmark: 'Pico Basilé',
      famousPerson: 'Teodoro Obiang Nguema Mbasogo',
      flag:
          'Horizontal green, white, and red stripes with blue triangle at hoist and coat of arms on white',
    ),
    'GW': AfricaClueData(
      nickname: 'The Rivers Land',
      famousLandmark: 'Bijagos Archipelago',
      famousPerson: 'Amilcar Cabral',
      flag:
          'Vertical red stripe at hoist with black star, horizontal yellow and green stripes',
    ),
    'KE': AfricaClueData(
      nickname: 'The Safari Capital of the World',
      famousLandmark: 'Maasai Mara National Reserve',
      famousPerson: 'Wangari Maathai',
      flag:
          'Horizontal black, red, and green stripes separated by white edges with Maasai shield and spears in center',
    ),
    'KM': AfricaClueData(
      nickname: 'The Perfume Islands',
      famousLandmark: 'Mount Karthala',
      famousPerson: 'Ahmed Abdallah Abderemane',
      flag:
          'Green triangle at hoist with four horizontal stripes of yellow, white, red, blue and white crescent and stars',
    ),
    'LR': AfricaClueData(
      nickname: 'The Land of the Free',
      famousLandmark: 'Sapo National Park',
      famousPerson: 'Ellen Johnson Sirleaf',
      flag:
          'Eleven alternating red and white horizontal stripes with blue square and white star at upper hoist',
    ),
    'LS': AfricaClueData(
      nickname: 'The Kingdom in the Sky',
      famousLandmark: 'Maletsunyane Falls',
      famousPerson: 'Moshoeshoe I',
      flag:
          'Horizontal blue, white, and green stripes with black Basotho hat emblem on white stripe',
    ),
    'LY': AfricaClueData(
      nickname: 'The Mediterranean Gateway to Africa',
      famousLandmark: 'Leptis Magna',
      famousPerson: 'Omar Mukhtar',
      flag:
          'Horizontal red, black, and green stripes with white crescent and star on black stripe',
    ),
    'MA': AfricaClueData(
      nickname: 'The Gateway to Africa',
      famousLandmark: 'Hassan II Mosque',
      famousPerson: 'Ibn Battuta',
      flag: 'Red field with green five-pointed star outlined in center',
    ),
    'MG': AfricaClueData(
      nickname: 'The Great Red Island',
      famousLandmark: 'Avenue of the Baobabs',
      famousPerson: 'Philibert Tsiranana',
      flag:
          'White vertical stripe at hoist with horizontal red and green stripes',
    ),
    'ML': AfricaClueData(
      nickname: 'The Land of Gold',
      famousLandmark: 'Great Mosque of Djenne',
      famousPerson: 'Mansa Musa',
      flag: 'Vertical green, gold, and red stripes from hoist to fly',
    ),
    'MR': AfricaClueData(
      nickname: 'The Land of a Million Poets',
      famousLandmark: 'Richat Structure (Eye of the Sahara)',
      famousPerson: 'Mokhtar Ould Daddah',
      flag:
          'Green field with gold crescent and star and red stripes at top and bottom',
    ),
    'MU': AfricaClueData(
      nickname: 'The Star and Key of the Indian Ocean',
      famousLandmark: 'Le Morne Brabant',
      famousPerson: 'Seewoosagur Ramgoolam',
      flag: 'Four horizontal stripes of red, blue, yellow, and green',
    ),
    'MW': AfricaClueData(
      nickname: 'The Warm Heart of Africa',
      famousLandmark: 'Lake Malawi',
      famousPerson: 'Hastings Kamuzu Banda',
      flag:
          'Horizontal black, red, and green stripes with red rising sun on black stripe',
    ),
    'MZ': AfricaClueData(
      nickname: 'The Land of the Good People',
      famousLandmark: 'Bazaruto Archipelago',
      famousPerson: 'Samora Machel',
      flag:
          'Green, black, and yellow horizontal stripes with red triangle at hoist bearing star, book, and rifle',
    ),
    'NA': AfricaClueData(
      nickname: 'The Land of the Brave',
      famousLandmark: 'Sossusvlei Sand Dunes',
      famousPerson: 'Sam Nujoma',
      flag:
          'Diagonal blue and green halves separated by red-bordered white stripe with yellow sun at upper hoist',
    ),
    'NE': AfricaClueData(
      nickname: 'The Frying Pan of the World',
      famousLandmark: 'Agadez Mosque',
      famousPerson: 'Hamani Diori',
      flag:
          'Horizontal orange, white, and green stripes with orange circle on white center stripe',
    ),
    'NG': AfricaClueData(
      nickname: 'The Giant of Africa',
      famousLandmark: 'Zuma Rock',
      famousPerson: 'Wole Soyinka',
      flag: 'Vertical green, white, and green stripes',
    ),
    'RW': AfricaClueData(
      nickname: 'The Land of a Thousand Hills',
      famousLandmark: 'Volcanoes National Park',
      famousPerson: 'Paul Kagame',
      flag:
          'Blue, yellow, and green horizontal stripes with yellow sun emblem in upper right',
    ),
    'SC': AfricaClueData(
      nickname: 'The Islands of the Indian Ocean',
      famousLandmark: 'Vallee de Mai',
      famousPerson: 'France-Albert Rene',
      flag:
          'Five oblique bands radiating from lower hoist in blue, yellow, red, white, and green',
    ),
    'SD': AfricaClueData(
      nickname: 'The Land of the Nubians',
      famousLandmark: 'Meroe Pyramids',
      famousPerson: 'Mahdi Muhammad Ahmad',
      flag:
          'Horizontal red, white, and black stripes with green triangle at hoist',
    ),
    'SL': AfricaClueData(
      nickname: 'The Lion Mountain',
      famousLandmark: 'Tacugama Chimpanzee Sanctuary',
      famousPerson: 'Ahmad Tejan Kabbah',
      flag: 'Horizontal green, white, and blue stripes',
    ),
    'SN': AfricaClueData(
      nickname: 'The Gateway to Africa',
      famousLandmark: 'Goree Island',
      famousPerson: 'Leopold Sedar Senghor',
      flag:
          'Vertical green, yellow, and red stripes with green star on yellow stripe',
    ),
    'SO': AfricaClueData(
      nickname: 'The Land of Poets',
      famousLandmark: 'Laas Geel Cave Paintings',
      famousPerson: 'Iman Abdulmajid',
      flag: 'Light blue field with white five-pointed star in center',
    ),
    'SS': AfricaClueData(
      nickname: 'The Land of the Sudd',
      famousLandmark: 'Sudd Wetland',
      famousPerson: 'John Garang de Mabior',
      flag:
          'Horizontal black, red, and green stripes separated by white edges with blue triangle and yellow star at hoist',
    ),
    'ST': AfricaClueData(
      nickname: 'The Chocolate Islands',
      famousLandmark: 'Pico de Sao Tome',
      famousPerson: 'Manuel Pinto da Costa',
      flag:
          'Horizontal green, yellow, and green stripes with red triangle at hoist and two black stars on yellow',
    ),
    'SZ': AfricaClueData(
      nickname: 'The Switzerland of Africa',
      famousLandmark: 'Sibebe Rock',
      famousPerson: 'King Sobhuza II',
      flag:
          'Horizontal blue, yellow, and red stripes with black and white Nguni shield and spears on center red stripe',
    ),
    'TD': AfricaClueData(
      nickname: 'The Babel Tower of the World',
      famousLandmark: 'Zakouma National Park',
      famousPerson: 'Idriss Deby',
      flag: 'Vertical blue, yellow, and red stripes',
    ),
    'TG': AfricaClueData(
      nickname: 'The Slave Coast',
      famousLandmark: 'Koutammakou Landscape',
      famousPerson: 'Gnassingbe Eyadema',
      flag:
          'Five horizontal green and yellow stripes with red square and white star at upper hoist',
    ),
    'TN': AfricaClueData(
      nickname: 'The Green Country',
      famousLandmark: 'Amphitheatre of El Jem',
      famousPerson: 'Habib Bourguiba',
      flag:
          'Red field with white circle in center containing red crescent and star',
    ),
    'TZ': AfricaClueData(
      nickname: 'The Land of Kilimanjaro',
      famousLandmark: 'Mount Kilimanjaro',
      famousPerson: 'Julius Nyerere',
      flag:
          'Green and blue triangles separated by diagonal black stripe bordered in yellow',
    ),
    'UG': AfricaClueData(
      nickname: 'The Pearl of Africa',
      famousLandmark: 'Bwindi Impenetrable Forest',
      famousPerson: 'Idi Amin',
      flag:
          'Six horizontal stripes of black, yellow, and red repeated with white circle and grey crowned crane in center',
    ),
    'ZA': AfricaClueData(
      nickname: 'The Rainbow Nation',
      famousLandmark: 'Table Mountain',
      famousPerson: 'Nelson Mandela',
      flag:
          'Horizontal red and blue halves with green Y-shape bordered in white and gold from hoist, black triangle at hoist',
    ),
    'ZM': AfricaClueData(
      nickname: 'The Real Africa',
      famousLandmark: 'Victoria Falls',
      famousPerson: 'Kenneth Kaunda',
      flag:
          'Green field with orange eagle and vertical red, black, and orange stripes at lower fly',
    ),
    'ZW': AfricaClueData(
      nickname: 'The Jewel of Africa',
      famousLandmark: 'Great Zimbabwe Ruins',
      famousPerson: 'Robert Mugabe',
      flag:
          'Seven horizontal stripes of green, yellow, red, black, red, yellow, green with white triangle and red star and bird at hoist',
    ),
  };
}
