/// Canadian Province and Territory clue data for the regional game mode.
abstract class CanadaClues {
  static const Map<String, ProvinceClueData> data = {
    'ON': ProvinceClueData(
      flag:
          'Red ensign with Ontario shield featuring red cross and maple leaves',
      sportsTeams: [
        'Toronto Maple Leafs (NHL)',
        'Toronto Raptors (NBA)',
        'Toronto Blue Jays (MLB)',
      ],
      premier: 'Doug Ford',
      nickname: 'The Heartland Province',
      motto: 'Ut Incepit Fidelis Sic Permanet',
      famousLandmark: 'CN Tower',
    ),
    'QC': ProvinceClueData(
      flag: 'Blue field with white cross and four fleurs-de-lis (Fleurdelise)',
      sportsTeams: ['Montreal Canadiens (NHL)', 'CF Montreal (MLS)'],
      premier: 'Francois Legault',
      nickname: 'La Belle Province',
      motto: 'Je me souviens',
      famousLandmark: 'Chateau Frontenac',
    ),
    'BC': ProvinceClueData(
      flag: 'Union Jack above setting sun over blue and white wavy stripes',
      sportsTeams: [
        'Vancouver Canucks (NHL)',
        'Vancouver Whitecaps (MLS)',
        'BC Lions (CFL)',
      ],
      premier: 'David Eby',
      nickname: 'The Pacific Province',
      motto: 'Splendor sine occasu',
      famousLandmark: 'Stanley Park',
    ),
    'AB': ProvinceClueData(
      flag:
          'Blue field with Alberta shield featuring mountains, prairie, and wheat',
      sportsTeams: [
        'Calgary Flames (NHL)',
        'Edmonton Oilers (NHL)',
        'Calgary Stampeders (CFL)',
      ],
      premier: 'Danielle Smith',
      nickname: 'Wild Rose Country',
      motto: 'Fortis et Liber',
      famousLandmark: 'Banff National Park',
    ),
    'MB': ProvinceClueData(
      flag: 'Red ensign with Manitoba shield featuring bison',
      sportsTeams: ['Winnipeg Jets (NHL)', 'Winnipeg Blue Bombers (CFL)'],
      premier: 'Wab Kinew',
      nickname: 'Land of 100,000 Lakes',
      motto: 'Gloriosus et Liber',
      famousLandmark: 'The Forks',
    ),
    'SK': ProvinceClueData(
      flag:
          'Green and gold horizontal halves with Saskatchewan shield and western red lily',
      sportsTeams: ['Saskatchewan Roughriders (CFL)'],
      premier: 'Scott Moe',
      nickname: 'Land of the Living Skies',
      motto: 'Multis E Gentibus Vires',
      famousLandmark: 'Royal Saskatchewan Museum',
    ),
    'NS': ProvinceClueData(
      flag: 'Blue background with white saltire and Royal Arms of Scotland',
      sportsTeams: ['Halifax Mooseheads (QMJHL)'],
      premier: 'Tim Houston',
      nickname: "Canada's Ocean Playground",
      motto: 'Munit Haec et Altera Vincit',
      famousLandmark: 'Peggy\'s Cove Lighthouse',
    ),
    'NB': ProvinceClueData(
      flag: 'Gold lion above gold galley on red and gold field',
      sportsTeams: ['Moncton Wildcats (QMJHL)'],
      premier: 'Blaine Higgs',
      nickname: 'The Picture Province',
      motto: 'Spem Reduxit',
      famousLandmark: 'Bay of Fundy',
    ),
    'NL': ProvinceClueData(
      flag: 'Geometric design of blue, red, gold and white triangles',
      sportsTeams: ['St. John\'s Edge (NBLC)'],
      premier: 'Andrew Furey',
      nickname: 'The Rock',
      motto: 'Quaerite Prime Regnum Dei',
      famousLandmark: 'Signal Hill',
    ),
    'PE': ProvinceClueData(
      flag:
          'Provincial shield with large oak and three saplings, English lion above',
      sportsTeams: ['Charlottetown Islanders (QMJHL)'],
      premier: 'Dennis King',
      nickname: 'Birthplace of Confederation',
      motto: 'Parva Sub Ingenti',
      famousLandmark: 'Green Gables Heritage Place',
    ),
    'NT': ProvinceClueData(
      flag: 'Blue panels with white centre bearing the territorial shield',
      sportsTeams: <String>[],
      premier: 'R.J. Simpson',
      nickname: 'The Land of the Midnight Sun',
      motto: '',
      famousLandmark: 'Nahanni National Park Reserve',
    ),
    'YT': ProvinceClueData(
      flag:
          'Green, white and blue vertical stripes with territorial coat of arms',
      sportsTeams: <String>[],
      premier: 'Ranj Pillai',
      nickname: 'Canada\'s True North',
      motto: '',
      famousLandmark: 'Kluane National Park',
    ),
    'NU': ProvinceClueData(
      flag: 'Gold and white field with red inuksuk and blue star',
      sportsTeams: <String>[],
      premier: 'P.J. Akeeagok',
      nickname: 'Our Land',
      motto: 'Nunavut Sannginivut',
      famousLandmark: 'Auyuittuq National Park',
    ),
  };
}

class ProvinceClueData {
  const ProvinceClueData({
    required this.flag,
    required this.sportsTeams,
    required this.premier,
    required this.nickname,
    required this.motto,
    required this.famousLandmark,
  });

  final String flag;
  final List<String> sportsTeams;
  final String premier;
  final String nickname;
  final String motto;
  final String famousLandmark;
}
