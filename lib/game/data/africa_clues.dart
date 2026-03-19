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
          'The red honours the blood shed during the independence struggle, the black represents Africa, and the gold machete and gear symbolise agricultural workers and industrial production — the half cogwheel and star echo socialist ideals from the independence movement',
    ),
    'BF': AfricaClueData(
      nickname: 'Land of Upright People',
      famousLandmark: 'Ruins of Loropeni',
      famousPerson: 'Thomas Sankara',
      flag:
          'The red represents the revolution that brought Thomas Sankara to power, the green symbolises agricultural abundance, and the central gold star represents the guiding light of the revolution — Pan-African colours uniting the nation',
    ),
    'BI': AfricaClueData(
      nickname: 'The Heart of Africa',
      famousLandmark: 'Source of the Nile',
      famousPerson: 'Louis Rwagasore',
      flag:
          'The white saltire (diagonal cross) represents peace, the red recalls the independence struggle, the green symbolises hope, and the three red six-pointed stars in the centre represent the three ethnic groups — Hutu, Tutsi, and Twa — and the national motto of unity, work, and progress',
    ),
    'BJ': AfricaClueData(
      nickname: 'The Birthplace of Voodoo',
      famousLandmark: 'Royal Palaces of Abomey',
      famousPerson: 'Angelique Kidjo',
      flag:
          'The green vertical stripe represents hope and revival, the yellow horizontal band symbolises the savanna in the north, and the red represents the courage of ancestors — Pan-African colours inspired by the Ethiopian flag',
    ),
    'BW': AfricaClueData(
      nickname: 'The Gem of Africa',
      famousLandmark: 'Okavango Delta',
      famousPerson: 'Seretse Khama',
      flag:
          'The light blue represents water and rain (Botswana means "land of the rains"), reflecting the nation\'s dependence on rainfall; the central black-and-white stripes symbolise racial harmony and the zebra, the national animal',
    ),
    'CD': AfricaClueData(
      nickname: 'The Congo',
      famousLandmark: 'Virunga National Park',
      famousPerson: 'Patrice Lumumba',
      flag:
          'The sky-blue field represents peace, the red diagonal stripe bordered in yellow symbolises the country\'s martyrs, and the yellow star in the corner represents the radiant future — drawing on symbols from the independence era',
    ),
    'CF': AfricaClueData(
      nickname: 'The Heart of Central Africa',
      famousLandmark: 'Dzanga-Sangha Reserve',
      famousPerson: 'Barthelemy Boganda',
      flag:
          'The four horizontal stripes — blue, white, green, and yellow — represent the sky, peace, forests, and savanna; the red vertical stripe symbolises the blood of the people; the yellow star in the blue canton represents independence and unity',
    ),
    'CG': AfricaClueData(
      nickname: 'The Land of the Emerald Forest',
      famousLandmark: 'Odzala-Kokoua National Park',
      famousPerson: 'Denis Sassou Nguesso',
      flag:
          'The green-yellow-red diagonal design uses Pan-African colours; green symbolises agriculture and forests, yellow represents friendship and the nobility of the Congolese people, and red honours those who struggled for independence',
    ),
    'CI': AfricaClueData(
      nickname: 'Land of the Elephants',
      famousLandmark: 'Basilica of Our Lady of Peace',
      famousPerson: 'Didier Drogba',
      flag:
          'The orange represents the savanna of the north, the white symbolises peace and unity, and the green represents the coastal forests of the south — modelled after the French Tricolore but with colours of the Ivorian landscape',
    ),
    'CM': AfricaClueData(
      nickname: 'Africa in Miniature',
      famousLandmark: 'Mount Cameroon',
      famousPerson: 'Samuel Eto\'o',
      flag:
          'The green-red-yellow vertical tricolour uses Pan-African colours; green represents the southern forests, red symbolises unity, and yellow represents the northern savanna; the central star is the "star of unity" for the Francophone and Anglophone regions',
    ),
    'CV': AfricaClueData(
      nickname: 'The Islands of Cape Verde',
      famousLandmark: 'Pico do Fogo Volcano',
      famousPerson: 'Cesaria Evora',
      flag:
          'The blue field represents the Atlantic Ocean and sky, the red and white stripes symbolise the road to nationhood, and the ten yellow stars arranged in a circle represent the ten main islands of the archipelago',
    ),
    'DJ': AfricaClueData(
      nickname: 'The Gateway to the Red Sea',
      famousLandmark: 'Lake Assal',
      famousPerson: 'Hassan Gouled Aptidon',
      flag:
          'The light blue represents the Issa Somali people and the sky, the green represents the Afar people and the earth, the white triangle symbolises peace, and the red star represents unity and the blood shed for independence',
    ),
    'DZ': AfricaClueData(
      nickname: 'The Land of Cherries and Dates',
      famousLandmark: 'Casbah of Algiers',
      famousPerson: 'Albert Camus',
      flag:
          'The green represents Islam and paradise, the white symbolises purity and peace, the red crescent and star are traditional symbols of Islam — adopted after independence from France in 1962 to reflect Algerian identity',
    ),
    'EG': AfricaClueData(
      nickname: 'The Land of the Pharaohs',
      famousLandmark: 'Great Pyramids of Giza',
      famousPerson: 'Cleopatra',
      flag:
          'The red-white-black horizontal tricolour uses Pan-Arab colours; red represents the period before the 1952 revolution, white symbolises the bloodless revolution, black recalls the end of British oppression, and the golden Eagle of Saladin is a symbol of Arab unity and strength',
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
          'The red triangle represents the blood shed for independence, the blue symbolises the Red Sea coast, the green represents agriculture and fertility, and the golden olive wreath (from the 1952 flag) symbolises peace and the 30-year armed struggle',
    ),
    'ET': AfricaClueData(
      nickname: 'The Roof of Africa',
      famousLandmark: 'Rock-Hewn Churches of Lalibela',
      famousPerson: 'Haile Selassie',
      flag:
          'The green-yellow-red horizontal tricolour is the oldest tricolour in Africa and inspired the Pan-African colour palette; green represents fertile land, yellow stands for peace and hope, red symbolises strength and sacrifice, and the blue disc with golden pentagram represents unity and diversity',
    ),
    'GA': AfricaClueData(
      nickname: 'The Land of the Surfing Hippos',
      famousLandmark: 'Lope National Park',
      famousPerson: 'Omar Bongo',
      flag:
          'The green represents the equatorial forests, the yellow symbolises the equator (which passes directly through Gabon), and the blue represents the Atlantic coastline — three colours capturing Gabon\'s geographic identity',
    ),
    'GH': AfricaClueData(
      nickname: 'The Gateway to West Africa',
      famousLandmark: 'Cape Coast Castle',
      famousPerson: 'Kwame Nkrumah',
      flag:
          'The red-gold-green horizontal tricolour with a black star was designed by Theodosia Okoh; the red represents those who died for independence, the gold symbolises mineral wealth, the green represents forests, and the black star is the lodestar of African freedom — inspiring other Pan-African flags',
    ),
    'GM': AfricaClueData(
      nickname: 'The Smiling Coast of Africa',
      famousLandmark: 'Kunta Kinteh Island',
      famousPerson: 'Dawda Jawara',
      flag:
          'The red represents the sun and savanna, the blue symbolises the River Gambia (the country\'s defining geographic feature), the green represents the forested areas, and the white stripes represent unity and peace',
    ),
    'GN': AfricaClueData(
      nickname: 'The Water Tower of West Africa',
      famousLandmark: 'Mount Nimba',
      famousPerson: 'Ahmed Sekou Toure',
      flag:
          'The red-yellow-green vertical tricolour mirrors the Pan-African colours in reverse; red represents the blood of martyrs, yellow symbolises the sun and mineral riches, and green represents the lush vegetation — adopted at independence from France in 1958',
    ),
    'GQ': AfricaClueData(
      nickname: 'The Land of Fernando Po',
      famousLandmark: 'Pico Basilé',
      famousPerson: 'Teodoro Obiang Nguema Mbasogo',
      flag:
          'The green represents natural resources, the white symbolises peace, the red honours those who fought for independence, the blue triangle represents the sea connecting the mainland and islands, and the silk-cotton tree on the coat of arms is a symbol of endurance',
    ),
    'GW': AfricaClueData(
      nickname: 'The Rivers Land',
      famousLandmark: 'Bijagos Archipelago',
      famousPerson: 'Amilcar Cabral',
      flag:
          'The red vertical stripe symbolises the blood shed during the independence struggle, the yellow represents the African sun, the green represents hope, and the black star draws from the Pan-African tradition established by Ghana — adopted at independence from Portugal in 1973',
    ),
    'KE': AfricaClueData(
      nickname: 'The Safari Capital of the World',
      famousLandmark: 'Maasai Mara National Reserve',
      famousPerson: 'Wangari Maathai',
      flag:
          'The black represents the Kenyan people, the red symbolises the blood shed for independence, the green represents the natural landscape, and the Maasai shield and crossed spears at the centre signify the defence of freedom — white stripes represent peace',
    ),
    'KM': AfricaClueData(
      nickname: 'The Perfume Islands',
      famousLandmark: 'Mount Karthala',
      famousPerson: 'Ahmed Abdallah Abderemane',
      flag:
          'The green field represents Islam, the crescent and four stars symbolise the four islands (Grande Comore, Mohéli, Anjouan, and Mayotte — still claimed), and the four horizontal stripes represent each island: yellow, white, red, and blue',
    ),
    'LR': AfricaClueData(
      nickname: 'The Land of the Free',
      famousLandmark: 'Sapo National Park',
      famousPerson: 'Ellen Johnson Sirleaf',
      flag:
          'Modelled closely on the American flag reflecting the country\'s founding by freed American slaves; the eleven red and white stripes represent the signatories of the Liberian Declaration of Independence, and the lone white star symbolises the first independent republic in Africa',
    ),
    'LS': AfricaClueData(
      nickname: 'The Kingdom in the Sky',
      famousLandmark: 'Maletsunyane Falls',
      famousPerson: 'Moshoeshoe I',
      flag:
          'The blue represents sky and rain, the white symbolises peace, the green represents prosperity, and the black Basotho hat (mokorotlo) in the centre is a traditional symbol of Lesotho\'s national identity and heritage',
    ),
    'LY': AfricaClueData(
      nickname: 'The Mediterranean Gateway to Africa',
      famousLandmark: 'Leptis Magna',
      famousPerson: 'Omar Mukhtar',
      flag:
          'The red-black-green horizontal tricolour with white crescent and star restores the flag of the Kingdom of Libya used before Gaddafi\'s rule; red represents the blood of martyrs, black represents Fezzan, and green represents Tripolitania',
    ),
    'MA': AfricaClueData(
      nickname: 'The Gateway to Africa',
      famousLandmark: 'Hassan II Mosque',
      famousPerson: 'Ibn Battuta',
      flag:
          'The red field dates back to the Alaouite dynasty and represents the descendants of the Prophet Muhammad; the green pentacle (five-pointed star) was added in 1915 as the Seal of Solomon, a traditional symbol of life, health, and wisdom in Islamic culture',
    ),
    'MG': AfricaClueData(
      nickname: 'The Great Red Island',
      famousLandmark: 'Avenue of the Baobabs',
      famousPerson: 'Philibert Tsiranana',
      flag:
          'The white vertical stripe represents purity and the Merina people (the island\'s largest ethnic group), the red horizontal band symbolises sovereignty and the Merina kingdom, and the green represents the coastal peoples (côtiers) and hope',
    ),
    'ML': AfricaClueData(
      nickname: 'The Land of Gold',
      famousLandmark: 'Great Mosque of Djenne',
      famousPerson: 'Mansa Musa',
      flag:
          'The green-yellow-red vertical tricolour uses Pan-African colours inspired by the Ethiopian flag; green represents nature, yellow symbolises purity and mineral wealth, and red represents the blood shed for independence from France',
    ),
    'MR': AfricaClueData(
      nickname: 'The Land of a Million Poets',
      famousLandmark: 'Richat Structure (Eye of the Sahara)',
      famousPerson: 'Mokhtar Ould Daddah',
      flag:
          'The green field represents Islam, the gold crescent and star are traditional Islamic symbols, and the red stripes at top and bottom (added in 2017) honour the blood of defenders of the nation — previously the flag was entirely green and gold',
    ),
    'MU': AfricaClueData(
      nickname: 'The Star and Key of the Indian Ocean',
      famousLandmark: 'Le Morne Brabant',
      famousPerson: 'Seewoosagur Ramgoolam',
      flag:
          'The four horizontal stripes represent: red for the struggle for independence, blue for the Indian Ocean, yellow for the golden sunshine, and green for the lush vegetation — designed to reflect the island nation\'s natural beauty and independence spirit',
    ),
    'MW': AfricaClueData(
      nickname: 'The Warm Heart of Africa',
      famousLandmark: 'Lake Malawi',
      famousPerson: 'Hastings Kamuzu Banda',
      flag:
          'The black represents the African people, the red symbolises the blood of the independence struggle, the green represents the natural environment, and the rising sun emblem represents the dawn of hope and freedom for Africa',
    ),
    'MZ': AfricaClueData(
      nickname: 'The Land of the Good People',
      famousLandmark: 'Bazaruto Archipelago',
      famousPerson: 'Samora Machel',
      flag:
          'The green represents agriculture, the black symbolises Africa, the yellow represents mineral wealth, the white represents peace, and the red represents the struggle for independence; the AK-47 and hoe on the emblem symbolise defence and agriculture',
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
