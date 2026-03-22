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
          'The Union Jack honours British colonial heritage, the Commonwealth Star beneath it has seven points for the six states and territories, and the Southern Cross constellation affirms the nation\'s location in the southern hemisphere',
    ),
    'FJ': OceaniaClueData(
      nickname: 'The Soft Coral Capital of the World',
      famousLandmark: 'Garden of the Sleeping Giant',
      famousPerson: 'Ratu Sir Lala Sukuna',
      flag:
          'The light blue represents the Pacific Ocean surrounding the islands, the Union Jack reflects the nation\'s history as a British colony, and the shield bears sugarcane, coconut palm, bananas, and a dove of peace — resources vital to the nation',
    ),
    'FM': OceaniaClueData(
      nickname: 'The Land of the Small Islands',
      famousLandmark: 'Nan Madol',
      famousPerson: 'Tosiwo Nakayama',
      flag:
          'The blue represents the Pacific Ocean, and the four stars symbolise the four federated states — Yap, Chuuk, Pohnpei, and Kosrae — united as one nation',
    ),
    'KI': OceaniaClueData(
      nickname: 'The Land of the Rising Sun in the Pacific',
      famousLandmark: 'Phoenix Islands Protected Area',
      famousPerson: 'Ieremia Tabai',
      flag:
          'The gold frigatebird flying over a rising sun represents freedom and the nation straddling the equator where the sun rises first, while the blue and white waves symbolise the Pacific Ocean that defines island life',
    ),
    'MH': OceaniaClueData(
      nickname: 'The Atoll Nation',
      famousLandmark: 'Bikini Atoll',
      famousPerson: 'Amata Kabua',
      flag:
          'The blue field represents the Pacific Ocean, the orange stripe symbolises courage and the Ralik chain, the white stripe represents peace and the Ratak chain, and the 24-pointed star honours the 24 municipalities, with four elongated rays for Majuro, Jaluit, Wotje, and Ebeye',
    ),
    'NR': OceaniaClueData(
      nickname: 'The Pleasant Island',
      famousLandmark: 'Buada Lagoon',
      famousPerson: 'Hammer DeRoburt',
      flag:
          'The blue represents the Pacific Ocean, the gold stripe symbolises the equator on which this island nation sits, and the twelve-pointed star below represents the island\'s twelve original tribes, placed in the southern hemisphere beneath the equator line',
    ),
    'NZ': OceaniaClueData(
      nickname: 'The Land of the Long White Cloud',
      famousLandmark: 'Milford Sound',
      famousPerson: 'Sir Edmund Hillary',
      flag:
          'The Union Jack honours the nation\'s ties to Britain, while the four red stars outlined in white depict the Southern Cross constellation — a navigational guide used by Polynesian and European explorers alike',
    ),
    'PG': OceaniaClueData(
      nickname: 'The Land of the Unexpected',
      famousLandmark: 'Kokoda Track',
      famousPerson: 'Michael Somare',
      flag:
          'The diagonal design was created by a 15-year-old student Susan Karike; the red panel bears a gold Raggiana bird-of-paradise (the national bird), while the black panel displays the Southern Cross, linking this nation to its Pacific neighbours',
    ),
    'PW': OceaniaClueData(
      nickname: 'The Pristine Paradise of the Pacific',
      famousLandmark: 'Jellyfish Lake',
      famousPerson: 'Haruo Remeliik',
      flag:
          'The light blue represents the ocean surrounding the islands, and the off-centre golden disc symbolises the full moon — considered the most auspicious time for traditional activities like fishing, planting, and harvesting',
    ),
    'SB': OceaniaClueData(
      nickname: 'The Happy Isles',
      famousLandmark: 'Guadalcanal',
      famousPerson: 'Peter Kenilorea',
      flag:
          'The blue represents the surrounding Pacific, the green symbolises the fertile land and forests, the yellow diagonal stripe represents sunshine, and the five white stars honour the five main island groups of this nation',
    ),
    'TO': OceaniaClueData(
      nickname: 'The Friendly Islands',
      famousLandmark: 'Ha\'amonga \'a Maui Trilithon',
      famousPerson: 'King George Tupou I',
      flag:
          'The red field represents the blood of Christ, reflecting the nation\'s deep Christian faith, while the white canton with a bold red cross directly symbolises Christianity — this being one of the Pacific\'s most devoutly Christian nations',
    ),
    'TV': OceaniaClueData(
      nickname: 'The Eight Standing Together',
      famousLandmark: 'Funafuti Conservation Area',
      famousPerson: 'Toaripi Lauti',
      flag:
          'The light blue represents the Pacific Ocean, the Union Jack reflects British colonial ties, and the nine yellow stars are arranged in the geographic pattern of this nation\'s nine islands — the country\'s name means "eight standing together" plus the later addition of Niulakita',
    ),
    'VU': OceaniaClueData(
      nickname: 'The Land of Eternal Happiness',
      famousLandmark: 'Mount Yasur Active Volcano',
      famousPerson: 'Walter Lini',
      flag:
          'The red symbolises the blood of the people and the boar\'s tusk (a traditional symbol of prosperity), the green represents the richness of the islands, the black triangle honours the Melanesian people, and the golden Y-shape depicts the archipelago\'s island chain layout',
    ),
    'WS': OceaniaClueData(
      nickname: 'The Cradle of Polynesia',
      famousLandmark: 'To Sua Ocean Trench',
      famousPerson: 'Robert Louis Stevenson',
      flag:
          'The red represents courage, the blue canton symbolises freedom, and the five white stars of the Southern Cross reflect the nation\'s position in the southern Pacific — the flag\'s simplicity echoes the national motto meaning "founded on God"',
    ),
  };
}
