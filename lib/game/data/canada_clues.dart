/// Canadian Province and Territory clue data for the regional game mode.
abstract class CanadaClues {
  static const Map<String, ProvinceClueData> data = {
    'ON': ProvinceClueData(
      flag:
          'This province\'s flag is a Red Ensign bearing the provincial shield, which features St George\'s Cross (the red cross of England) honouring Upper Canada\'s British colonial roots, and three golden maple leaves representing the province\'s three founding regions; the Red Ensign itself was the flag of Canada until 1965, retained here as a deliberate expression of loyalty to the Crown and British heritage',
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
      flag:
          'The Fleurdelisé derives from the ancient royal banner of France, honouring this province\'s founding as New France in 1608; the four fleurs-de-lis are symbols of French royalty and the Catholic faith brought by early settlers, while the white cross dividing the field reflects the Cross of Saint George adapted in the French tradition — adopted in 1948 as a defiant assertion of French-Canadian identity',
      sportsTeams: ['Montreal Canadiens (NHL)', 'CF Montreal (MLS)'],
      premier: 'Francois Legault',
      nickname: 'La Belle Province',
      motto: 'Je me souviens',
      famousLandmark: 'Chateau Frontenac',
    ),
    'BC': ProvinceClueData(
      flag:
          'The Union Jack in the upper canton honours BC\'s entry into Confederation in 1871 under the promise of a transcontinental railway; the golden half-sun setting over blue and white waves below represents the Pacific Ocean and BC\'s position as Canada\'s western gateway — the motto Splendor sine occasu (Splendour without diminishment) refers to this perpetual sunset, symbolising a province whose glory never fades',
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
          'This province\'s flag bears the provincial shield on a blue background, with the shield depicting St George\'s Cross at the top honouring British colonial heritage, the Rocky Mountains in the middle representing the dramatic western peaks that define the province, and rolling prairie with wheat below symbolising the agricultural wealth that drew settlers after 1905; the blue field evokes the vast sky celebrated by the province\'s motto Fortis et Liber (Strong and Free)',
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
      flag:
          'This province\'s Red Ensign bears the provincial shield showing St George\'s Cross above a golden bison standing on green ground; the bison honours the Plains Cree, Assiniboine, and Métis peoples whose way of life was built around the vast buffalo herds before European settlement, and it was chosen when this province joined Confederation in 1870 partly to recognise Louis Riel\'s Métis provisional government that negotiated the province\'s creation',
      sportsTeams: ['Winnipeg Jets (NHL)', 'Winnipeg Blue Bombers (CFL)'],
      premier: 'Wab Kinew',
      nickname: 'Land of 100,000 Lakes',
      motto: 'Gloriosus et Liber',
      famousLandmark: 'The Forks',
    ),
    'SK': ProvinceClueData(
      flag:
          'This province\'s flag is divided horizontally into green (upper) and gold (lower) — green representing the northern forest and agricultural land, gold celebrating the wheat fields and mineral wealth of the southern plains; the provincial shield on the left bears St George\'s Cross and three gold sheaves of wheat, while the western red lily on the right is the provincial flower chosen to honour the Indigenous peoples and early settlers who cultivated this grassland province',
      sportsTeams: ['Saskatchewan Roughriders (CFL)'],
      premier: 'Scott Moe',
      nickname: 'Land of the Living Skies',
      motto: 'Multis E Gentibus Vires',
      famousLandmark: 'Royal Saskatchewan Museum',
    ),
    'NS': ProvinceClueData(
      flag:
          'This province\'s flag is the oldest provincial flag in Canada, granted by King Charles I in 1625 — predating the province\'s formal British control; it bears the Royal Arms of Scotland (a gold lion on red) at the centre of a blue-and-white saltire (the Cross of Saint Andrew), directly inverting the Scottish flag\'s colours to create a distinctly local identity that honours the wave of Scottish Highland settlers who gave the province its Latin name meaning New Scotland',
      sportsTeams: ['Halifax Mooseheads (QMJHL)'],
      premier: 'Tim Houston',
      nickname: "Canada's Ocean Playground",
      motto: 'Munit Haec et Altera Vincit',
      famousLandmark: 'Peggy\'s Cove Lighthouse',
    ),
    'NB': ProvinceClueData(
      flag:
          'New Brunswick\'s flag bears the arms granted in 1868, showing a golden lion passant on red in the upper section — the lion of Brunswick from the German duchy whose Loyalist settlers flooded the province after the American Revolution — and a golden galley on blue waves below, honouring the shipbuilding industry that made Saint John one of the world\'s great wooden shipbuilding ports in the 19th century',
      sportsTeams: ['Moncton Wildcats (QMJHL)'],
      premier: 'Blaine Higgs',
      nickname: 'The Picture Province',
      motto: 'Spem Reduxit',
      famousLandmark: 'Bay of Fundy',
    ),
    'NL': ProvinceClueData(
      flag:
          'Newfoundland and Labrador\'s flag was designed by artist Christopher Pratt and adopted in 1980, replacing the Union Jack to assert a distinct identity 31 years after joining Canada; the geometric design in blue, red, gold, and white evokes the Union Jack\'s structure symbolically, with the blue representing the sea that defines the province, the red arrow pointing toward the future, the gold recognising the province\'s natural resources, and the white trident-like form honouring the fishing industry and the hardy people of The Rock',
      sportsTeams: ['St. John\'s Edge (NBLC)'],
      premier: 'Andrew Furey',
      nickname: 'The Rock',
      motto: 'Quaerite Prime Regnum Dei',
      famousLandmark: 'Signal Hill',
    ),
    'PE': ProvinceClueData(
      flag:
          'This province\'s flag bears the provincial arms granted in 1905, showing a large oak tree sheltering three smaller oak saplings on a grassy field — the large oak represents Britain and the three saplings its three counties (Prince, Queens, and Kings); a golden lion on red in the upper section honours England, while the motto Parva Sub Ingenti (The small under the protection of the great) captures the island\'s relationship with the Canadian Confederation it helped found in 1864',
      sportsTeams: ['Charlottetown Islanders (QMJHL)'],
      premier: 'Dennis King',
      nickname: 'Birthplace of Confederation',
      motto: 'Parva Sub Ingenti',
      famousLandmark: 'Green Gables Heritage Place',
    ),
    'NT': ProvinceClueData(
      flag:
          'The Northwest Territories flag has blue panels flanking a white centre, with the territorial shield at the heart; the blue represents the lakes and rivers that dominate the territory — including Great Slave Lake and the Mackenzie River — while the shield depicts a diagonal line of wavy blue on white representing these waterways, green below for the forests of the Mackenzie Valley, red above for the tundra of the barrens, and a gold bilaterally-symmetrical fox head honouring the fur trade that first drew European explorers into these vast lands',
      sportsTeams: <String>[],
      premier: 'R.J. Simpson',
      nickname: 'The Land of the Midnight Sun',
      motto: '',
      famousLandmark: 'Nahanni National Park Reserve',
    ),
    'YT': ProvinceClueData(
      flag:
          'Yukon\'s tricolour flag has green for the spruce forests, white for the snows and the Klondike Gold Rush stampede that transformed the territory in 1898, and blue for the rivers and lakes; at the centre sits the territorial coat of arms featuring a malamute dog on a red background above golden wavy lines for the Yukon River, with two vair roundels representing the fur trade history and a red Cross of Saint George honouring the North-West Mounted Police who kept order during the gold rush era',
      sportsTeams: <String>[],
      premier: 'Ranj Pillai',
      nickname: 'Canada\'s True North',
      motto: '',
      famousLandmark: 'Kluane National Park',
    ),
    'NU': ProvinceClueData(
      flag:
          'Nunavut\'s flag was adopted in 1999 when the territory was created, designed entirely to reflect Inuit identity; the red inuksuk at the centre is an ancient stone landmark built by Inuit across the Arctic to guide travellers and hunters — a symbol of community, direction, and the human presence in the landscape; the blue star above it is Niqirtsuituq, the North Star used for navigation, while gold and white represent the riches of the land and the Arctic light',
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
