/// Regional clue data for all 32 counties of Ireland (Republic + Northern Ireland)
library;

class CountyClueData {
  const CountyClueData({
    required this.province,
    required this.gaelicName,
    required this.famousPerson,
    required this.famousLandmark,
    required this.gaaTeam,
    required this.nickname,
    required this.flag,
  });

  final String province;
  final String gaelicName;
  final String famousPerson;
  final String famousLandmark;
  final String gaaTeam;
  final String nickname;
  final String flag;
}

abstract class IrelandClues {
  static const Map<String, CountyClueData> data = {
    // LEINSTER
    'D': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Baile Átha Cliath',
      famousPerson: 'James Joyce',
      famousLandmark: 'GPO on O\'Connell Street',
      gaaTeam: 'The Dubs (Sky Blue)',
      nickname: 'The Pale',
      flag:
          'Sky blue represents the ancient Gaelic kingdom of Leinster and the Virgin Mary, patron of Ireland; the navy echoes the heraldic colours of the Pale, the historic English-controlled region centred on Dublin since the Norman conquest',
    ),
    'WW': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Cill Mhantáin',
      famousPerson: 'Katie Taylor',
      famousLandmark: 'Glendalough Monastic Site',
      gaaTeam: 'The Garden County (Blue & Gold)',
      nickname: 'The Garden of Ireland',
      flag:
          'Blue and gold derive from the heraldic arms of the O\'Byrne and O\'Toole clans, the dominant Gaelic chieftains of Wicklow who fiercely resisted Norman and later English expansion into their mountain strongholds',
    ),
    'WX': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Loch Garman',
      famousPerson: 'John Barry, father of US Navy',
      famousLandmark: 'Hook Lighthouse',
      gaaTeam: 'The Model County (Purple & Gold)',
      nickname: 'The Model County',
      flag:
          'Purple and gold reflect the arms of the Roche family, Anglo-Norman lords of Wexford since the 12th century; purple was a colour of high nobility and ecclesiastical authority, honouring Wexford\'s long role as a centre of Norman church influence in Leinster',
    ),
    'KK': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Cill Chainnigh',
      famousPerson: 'Henry Shefflin',
      famousLandmark: 'Kilkenny Castle',
      gaaTeam: 'The Cats (Black & Amber)',
      nickname: 'The Marble City',
      flag:
          'Black and amber trace to the heraldic arms of the Butler dynasty, the Anglo-Norman Earls of Ormond who dominated Kilkenny from the 14th century; their castle still stands in the city and the colours became inseparable from Kilkenny\'s identity',
    ),
    'CW': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Ceatharlach',
      famousPerson: 'Pierce Brosnan',
      famousLandmark: 'Brownshill Dolmen',
      gaaTeam: 'The Scallion Eaters (Green, Red & Yellow)',
      nickname: 'The Dolmen County',
      flag:
          'Green, red, and yellow represent the three baronies of Carlow: Carlow, Rathvilly, and St Mullins; the colours also echo the arms of the MacMurrough Kavanagh dynasty, the powerful Gaelic kings of Leinster who held these lands before the Norman arrival',
    ),
    'KE': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Cill Dara',
      famousPerson: 'Christy Moore',
      famousLandmark: 'The Curragh Racecourse',
      gaaTeam: 'The Lilywhites (White)',
      nickname: 'The Thoroughbred County',
      flag:
          'The all-white flag gave Kildare GAA their nickname The Lilywhites; white in Irish heraldry signifies purity and spiritual devotion, befitting a county whose identity is rooted in the monastic tradition of Saint Brigid, who founded her famous abbey at Kildare in the 5th century',
    ),
    'MH': CountyClueData(
      province: 'Leinster',
      gaelicName: 'An Mhí',
      famousPerson: 'Pierce Brosnan',
      famousLandmark: 'Newgrange',
      gaaTeam: 'The Royals (Green & Gold)',
      nickname: 'The Royal County',
      flag:
          'Green and gold reflect the ancient royal heritage of Meath, seat of the High Kings of Ireland at the Hill of Tara; gold symbolises the sovereignty of the Ard Rí, while green stands for the sacred landscape of the Boyne Valley, cradle of Irish civilisation',
    ),
    'WH': CountyClueData(
      province: 'Leinster',
      gaelicName: 'An Iarmhí',
      famousPerson: 'Niall Horan',
      famousLandmark: 'Athlone Castle',
      gaaTeam: 'The Lake County (Maroon & White)',
      nickname: 'The Lake County',
      flag:
          'Maroon and white are drawn from the heraldic arms of the O\'Melaghlin (Malachy) dynasty, the ancient kings of Meath who once ruled Westmeath; maroon signified royal authority in Gaelic tradition, and the colours have endured as symbols of the lakeland county\'s Gaelic heritage',
    ),
    'LS': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Laois',
      famousPerson: 'Jack Charlton (lived there)',
      famousLandmark: 'Rock of Dunamase',
      gaaTeam: 'The O\'Moore County (Blue & White)',
      nickname: 'The O\'Moore County',
      flag:
          'Blue and white honour the O\'Moore clan, the Gaelic lords of Laois who led fierce resistance against the Plantation of Leix in the 16th century; their defiance gave the county its enduring name The O\'Moore County, and the heraldic blue and white recall their sept\'s colours',
    ),
    'OY': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Uíbh Fhailí',
      famousPerson: 'Shane Lowry',
      famousLandmark: 'Clonmacnoise',
      gaaTeam: 'The Faithful County (Green, White & Gold)',
      nickname: 'The Faithful County',
      flag:
          'Green, white, and gold reflect the colours of the O\'Connor clan, hereditary kings of Offaly; the combination echoes the broader Gaelic nationalist palette and honours the county\'s deep roots as a centre of early Christian monasticism at Clonmacnoise',
    ),
    'LD': CountyClueData(
      province: 'Leinster',
      gaelicName: 'An Longfort',
      famousPerson: 'Padraic Colum',
      famousLandmark: 'Corlea Trackway',
      gaaTeam: 'The Slashers (Blue & Gold)',
      nickname: 'The Midlands',
      flag:
          'Blue and gold derive from the arms of the O\'Farrell dynasty, the Gaelic lords who ruled Longford as part of the ancient kingdom of Annaly; gold represented their regal status while blue echoed the waterways of the Shannon that defined their territory',
    ),
    'LH': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Lú',
      famousPerson: 'Pierce Brosnan (born there)',
      famousLandmark: 'Proleek Dolmen',
      gaaTeam: 'The Wee County (Red)',
      nickname: 'The Wee County',
      flag:
          'Red and white reflect the heraldic arms of the de Verdun and later Bellew families, the Norman lords of Louth; red also symbolises the county\'s martial history as the smallest county in Ireland yet one of the most fiercely contested border territories between the Gaelic north and the English Pale',
    ),

    // MUNSTER
    'C': CountyClueData(
      province: 'Munster',
      gaelicName: 'Corcaigh',
      famousPerson: 'Michael Collins',
      famousLandmark: 'Blarney Castle',
      gaaTeam: 'The Rebels (Red & White)',
      nickname: 'The Rebel County',
      flag:
          'Red and white recall the arms of the MacCarthy Mór dynasty, the Gaelic kings of Munster who dominated Cork for centuries; their rebellion against English rule earned Cork the title The Rebel County, and the red stands for the blood of resistance that defines the county\'s fiercely independent character',
    ),
    'KY': CountyClueData(
      province: 'Munster',
      gaelicName: 'Ciarraí',
      famousPerson: 'Brendan Gleeson',
      famousLandmark: 'Gap of Dunloe',
      gaaTeam: 'The Kingdom (Green & Gold)',
      nickname: 'The Kingdom',
      flag:
          'Green and gold are the ancient colours of the Kingdom of Kerry, a proud title the county still carries; green honours the lush landscape of the southwest and the Gaelic heritage of the O\'Sullivan and Fitzgerald clans, while gold evokes the sunsets over the Atlantic that define this rugged peninsula',
    ),
    'L': CountyClueData(
      province: 'Munster',
      gaelicName: 'Luimneach',
      famousPerson: 'Richard Harris',
      famousLandmark: 'King John\'s Castle',
      gaaTeam: 'The Treaty County (Green & White)',
      nickname: 'The Treaty City',
      flag:
          'Green and white reflect the Treaty of Limerick of 1691, the peace agreement that ended the Williamite War in Ireland; the colours honour both the Gaelic O\'Brien heritage of the region and the hope for reconciliation embedded in that historic treaty, giving Limerick its enduring nickname The Treaty City',
    ),
    'CE': CountyClueData(
      province: 'Munster',
      gaelicName: 'An Clár',
      famousPerson: 'Edna O\'Brien',
      famousLandmark: 'Cliffs of Moher',
      gaaTeam: 'The Banner County (Saffron & Blue)',
      nickname: 'The Banner County',
      flag:
          'Saffron was the traditional colour of Gaelic Irish dress and symbolises the ancient Celtic culture of the O\'Brien kings who ruled Clare as part of Thomond; blue honours the county\'s connection to the sea and the Clare coastline, while saffron together with blue evokes the county\'s dual identity of Gaelic nobility and Atlantic wildness',
    ),
    'T': CountyClueData(
      province: 'Munster',
      gaelicName: 'Tiobraid Árann',
      famousPerson: 'Eamonn de Valera',
      famousLandmark: 'Rock of Cashel',
      gaaTeam: 'The Premier County (Blue & Gold)',
      nickname: 'The Premier County',
      flag: 'Blue and gold vertical stripes',
    ),
    'W': CountyClueData(
      province: 'Munster',
      gaelicName: 'Port Láirge',
      famousPerson: 'Val Doonican',
      famousLandmark: 'Waterford Crystal Factory',
      gaaTeam: 'The Déise (White & Blue)',
      nickname: 'The Déise',
      flag: 'White and blue vertical stripes',
    ),

    // CONNACHT
    'G': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Gaillimh',
      famousPerson: 'Noel Purcell',
      famousLandmark: 'Connemara National Park',
      gaaTeam: 'The Tribesmen (Maroon & White)',
      nickname: 'The City of the Tribes',
      flag: 'Maroon and white vertical stripes',
    ),
    'MO': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Maigh Eo',
      famousPerson: 'Michael Davitt',
      famousLandmark: 'Croagh Patrick',
      gaaTeam: 'The Green & Red',
      nickname: 'The Heather County',
      flag: 'Green and red vertical stripes',
    ),
    'SO': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Sligeach',
      famousPerson: 'W.B. Yeats',
      famousLandmark: 'Ben Bulben',
      gaaTeam: 'The Yeats County (Black & White)',
      nickname: 'The Yeats County',
      flag: 'Black and white vertical stripes',
    ),
    'RN': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Ros Comáin',
      famousPerson: 'Maureen O\'Sullivan',
      famousLandmark: 'Strokestown Park House',
      gaaTeam: 'The Rossies (Primrose & Blue)',
      nickname: 'The Rossies',
      flag: 'Primrose and blue vertical stripes',
    ),
    'LM': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Liatroim',
      famousPerson: 'Seán Mac Diarmada',
      famousLandmark: 'Glencar Waterfall',
      gaaTeam: 'Green & Gold',
      nickname: 'The Wild Rose County',
      flag: 'Green and gold vertical stripes',
    ),

    // ULSTER (Republic of Ireland)
    'DL': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Dún na nGall',
      famousPerson: 'Daniel O\'Donnell',
      famousLandmark: 'Slieve League Cliffs',
      gaaTeam: 'The Tír Chonaill (Green & Gold)',
      nickname: 'The Forgotten County',
      flag: 'Green and gold vertical stripes',
    ),
    'CN': CountyClueData(
      province: 'Ulster',
      gaelicName: 'An Cabhán',
      famousPerson: 'Percy French',
      famousLandmark: 'Cuilcagh Mountain',
      gaaTeam: 'The Breffni County (Blue & White)',
      nickname: 'The Breffni County',
      flag: 'Blue and white vertical stripes',
    ),
    'MN': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Muineachán',
      famousPerson: 'Patrick Kavanagh',
      famousLandmark: 'Rossmore Forest Park',
      gaaTeam: 'The Farney County (White & Blue)',
      nickname: 'The Farney County',
      flag: 'White and blue vertical stripes',
    ),

    // ULSTER (Northern Ireland)
    'ANT': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Aontroim',
      famousPerson: 'C.S. Lewis',
      famousLandmark: 'Giant\'s Causeway',
      gaaTeam: 'The Saffrons (Saffron & White)',
      nickname: 'The Glens',
      flag: 'Saffron and white vertical stripes',
    ),
    'ARM': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Ard Mhacha',
      famousPerson: 'Saint Patrick',
      famousLandmark: 'Navan Fort',
      gaaTeam: 'The Orchard County (Orange & White)',
      nickname: 'The Orchard County',
      flag: 'Orange and white vertical stripes',
    ),
    'DWN': CountyClueData(
      province: 'Ulster',
      gaelicName: 'An Dún',
      famousPerson: 'Van Morrison',
      famousLandmark: 'Mourne Mountains',
      gaaTeam: 'The Mourne County (Red & Black)',
      nickname: 'The Mourne County',
      flag: 'Red and black vertical stripes',
    ),
    'FRM': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Fear Manach',
      famousPerson: 'Adrian Dunbar',
      famousLandmark: 'Marble Arch Caves',
      gaaTeam: 'The Erne County (Green & White)',
      nickname: 'The Lakeland County',
      flag: 'Green and white vertical stripes',
    ),
    'LDY': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Doire',
      famousPerson: 'Seamus Heaney',
      famousLandmark: 'Derry City Walls',
      gaaTeam: 'The Oak Leaf County (Red & White)',
      nickname: 'The Maiden City',
      flag: 'Red and white vertical stripes',
    ),
    'TYR': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Tír Eoghain',
      famousPerson: 'Brian Friel',
      famousLandmark: 'Ulster American Folk Park',
      gaaTeam: 'The Red Hand County (White & Red)',
      nickname: 'The Red Hand County',
      flag: 'White and red vertical stripes',
    ),
  };
}
