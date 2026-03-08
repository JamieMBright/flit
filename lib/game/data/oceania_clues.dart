/// Oceanian country clue data for the regional game mode.
/// Covers all 14 Oceanian nations.
library;

class OceaniaClueData {
  const OceaniaClueData({
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

abstract class OceaniaClues {
  static const Map<String, OceaniaClueData> data = {
    'AU': OceaniaClueData(
      nickname: 'The Land Down Under',
      famousLandmark: 'Sydney Opera House',
      famousPerson: 'Steve Irwin',
      flag:
          'Blue field with Union Jack at upper hoist, large white Commonwealth Star below, and five white stars of Southern Cross at fly',
    ),
    'FJ': OceaniaClueData(
      nickname: 'The Soft Coral Capital of the World',
      famousLandmark: 'Garden of the Sleeping Giant',
      famousPerson: 'Ratu Sir Lala Sukuna',
      flag:
          'Light blue field with Union Jack at upper hoist and coat of arms shield at fly',
    ),
    'FM': OceaniaClueData(
      nickname: 'The Land of the Small Islands',
      famousLandmark: 'Nan Madol',
      famousPerson: 'Tosiwo Nakayama',
      flag:
          'Blue field with four white five-pointed stars arranged in diamond pattern in center',
    ),
    'KI': OceaniaClueData(
      nickname: 'The Land of the Rising Sun in the Pacific',
      famousLandmark: 'Phoenix Islands Protected Area',
      famousPerson: 'Ieremia Tabai',
      flag:
          'Red upper half with gold frigatebird over gold rising sun, blue and white wavy lower half',
    ),
    'MH': OceaniaClueData(
      nickname: 'The Atoll Nation',
      famousLandmark: 'Bikini Atoll',
      famousPerson: 'Amata Kabua',
      flag:
          'Blue field with two diagonal stripes of orange and white widening toward fly and white star at upper hoist',
    ),
    'NR': OceaniaClueData(
      nickname: 'The Pleasant Island',
      famousLandmark: 'Buada Lagoon',
      famousPerson: 'Hammer DeRoburt',
      flag:
          'Blue field with yellow horizontal stripe across center and white twelve-pointed star below stripe at hoist',
    ),
    'NZ': OceaniaClueData(
      nickname: 'The Land of the Long White Cloud',
      famousLandmark: 'Milford Sound',
      famousPerson: 'Sir Edmund Hillary',
      flag:
          'Blue field with Union Jack at upper hoist and four red stars with white borders representing Southern Cross',
    ),
    'PG': OceaniaClueData(
      nickname: 'The Land of the Unexpected',
      famousLandmark: 'Kokoda Track',
      famousPerson: 'Michael Somare',
      flag:
          'Diagonally divided red and black halves with yellow bird of paradise on red and white Southern Cross on black',
    ),
    'PW': OceaniaClueData(
      nickname: 'The Pristine Paradise of the Pacific',
      famousLandmark: 'Jellyfish Lake',
      famousPerson: 'Haruo Remeliik',
      flag:
          'Light blue field with yellow full moon slightly offset from center toward hoist',
    ),
    'SB': OceaniaClueData(
      nickname: 'The Happy Isles',
      famousLandmark: 'Guadalcanal',
      famousPerson: 'Peter Kenilorea',
      flag:
          'Blue and green halves divided by yellow diagonal stripe with five white stars at upper hoist',
    ),
    'TO': OceaniaClueData(
      nickname: 'The Friendly Islands',
      famousLandmark: 'Ha\'amonga \'a Maui Trilithon',
      famousPerson: 'King George Tupou I',
      flag: 'Red field with white canton bearing red cross',
    ),
    'TV': OceaniaClueData(
      nickname: 'The Eight Standing Together',
      famousLandmark: 'Funafuti Conservation Area',
      famousPerson: 'Toaripi Lauti',
      flag:
          'Light blue field with Union Jack at upper hoist and nine yellow stars arranged in map pattern',
    ),
    'VU': OceaniaClueData(
      nickname: 'The Land of Eternal Happiness',
      famousLandmark: 'Mount Yasur Active Volcano',
      famousPerson: 'Walter Lini',
      flag:
          'Red and green halves separated by black triangle at hoist, yellow Y-shape, and yellow boar tusk emblem',
    ),
    'WS': OceaniaClueData(
      nickname: 'The Cradle of Polynesia',
      famousLandmark: 'To Sua Ocean Trench',
      famousPerson: 'Robert Louis Stevenson',
      flag:
          'Red field with blue canton bearing five white stars of the Southern Cross',
    ),
  };
}
