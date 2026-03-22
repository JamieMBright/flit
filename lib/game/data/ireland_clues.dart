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
          'Sky blue represents the ancient Gaelic kingdom of Leinster and the Virgin Mary, patron of Ireland; the navy echoes the heraldic colours of the Pale, the historic English-controlled region centred on this county since the Norman conquest',
    ),
    'WW': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Cill Mhantáin',
      famousPerson: 'Katie Taylor',
      famousLandmark: 'Glendalough Monastic Site',
      gaaTeam: 'The Garden County (Blue & Gold)',
      nickname: 'The Garden of Ireland',
      flag:
          'Blue and gold derive from the heraldic arms of the O\'Byrne and O\'Toole clans, the dominant Gaelic chieftains of this county who fiercely resisted Norman and later English expansion into their mountain strongholds',
    ),
    'WX': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Loch Garman',
      famousPerson: 'John Barry, father of US Navy',
      famousLandmark: 'Hook Lighthouse',
      gaaTeam: 'The Model County (Purple & Gold)',
      nickname: 'The Model County',
      flag:
          'Purple and gold reflect the arms of the Roche family, Anglo-Norman lords of this county since the 12th century; purple was a colour of high nobility and ecclesiastical authority, honouring this county\'s long role as a centre of Norman church influence in Leinster',
    ),
    'KK': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Cill Chainnigh',
      famousPerson: 'Henry Shefflin',
      famousLandmark: 'Kilkenny Castle',
      gaaTeam: 'The Cats (Black & Amber)',
      nickname: 'The Marble City',
      flag:
          'Black and amber trace to the heraldic arms of the Butler dynasty, the Anglo-Norman Earls of Ormond who dominated this county from the 14th century; their castle still stands in the city and the colours became inseparable from this county\'s identity',
    ),
    'CW': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Ceatharlach',
      famousPerson: 'Pierce Brosnan',
      famousLandmark: 'Brownshill Dolmen',
      gaaTeam: 'The Scallion Eaters (Green, Red & Yellow)',
      nickname: 'The Dolmen County',
      flag:
          'Green, red, and yellow represent the three baronies of this county; the colours also echo the arms of the MacMurrough Kavanagh dynasty, the powerful Gaelic kings of Leinster who held these lands before the Norman arrival',
    ),
    'KE': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Cill Dara',
      famousPerson: 'Christy Moore',
      famousLandmark: 'The Curragh Racecourse',
      gaaTeam: 'The Lilywhites (White)',
      nickname: 'The Thoroughbred County',
      flag:
          'The all-white flag gave this county\'s GAA team their nickname The Lilywhites; white in Irish heraldry signifies purity and spiritual devotion, befitting a county whose identity is rooted in the monastic tradition of Saint Brigid, who founded her famous abbey here in the 5th century',
    ),
    'MH': CountyClueData(
      province: 'Leinster',
      gaelicName: 'An Mhí',
      famousPerson: 'Pierce Brosnan',
      famousLandmark: 'Newgrange',
      gaaTeam: 'The Royals (Green & Gold)',
      nickname: 'The Royal County',
      flag:
          'Green and gold reflect the ancient royal heritage of this county, seat of the High Kings of Ireland at the Hill of Tara; gold symbolises the sovereignty of the Ard Rí, while green stands for the sacred landscape of the Boyne Valley, cradle of Irish civilisation',
    ),
    'WH': CountyClueData(
      province: 'Leinster',
      gaelicName: 'An Iarmhí',
      famousPerson: 'Niall Horan',
      famousLandmark: 'Athlone Castle',
      gaaTeam: 'The Lake County (Maroon & White)',
      nickname: 'The Lake County',
      flag:
          'Maroon and white are drawn from the heraldic arms of the O\'Melaghlin (Malachy) dynasty, the ancient kings of Meath who once ruled this county; maroon signified royal authority in Gaelic tradition, and the colours have endured as symbols of this lakeland county\'s Gaelic heritage',
    ),
    'LS': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Laois',
      famousPerson: 'Jack Charlton (lived there)',
      famousLandmark: 'Rock of Dunamase',
      gaaTeam: 'The O\'Moore County (Blue & White)',
      nickname: 'The O\'Moore County',
      flag:
          'Blue and white honour the O\'Moore clan, the Gaelic lords of this county who led fierce resistance against the Plantation of Leix in the 16th century; their defiance gave the county its enduring name The O\'Moore County, and the heraldic blue and white recall their sept\'s colours',
    ),
    'OY': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Uíbh Fhailí',
      famousPerson: 'Shane Lowry',
      famousLandmark: 'Clonmacnoise',
      gaaTeam: 'The Faithful County (Green, White & Gold)',
      nickname: 'The Faithful County',
      flag:
          'Green, white, and gold reflect the colours of the O\'Connor clan, hereditary kings of this county; the combination echoes the broader Gaelic nationalist palette and honours the county\'s deep roots as a centre of early Christian monasticism at Clonmacnoise',
    ),
    'LD': CountyClueData(
      province: 'Leinster',
      gaelicName: 'An Longfort',
      famousPerson: 'Padraic Colum',
      famousLandmark: 'Corlea Trackway',
      gaaTeam: 'The Slashers (Blue & Gold)',
      nickname: 'The Midlands',
      flag:
          'Blue and gold derive from the arms of the O\'Farrell dynasty, the Gaelic lords who ruled this county as part of the ancient kingdom of Annaly; gold represented their regal status while blue echoed the waterways of the Shannon that defined their territory',
    ),
    'LH': CountyClueData(
      province: 'Leinster',
      gaelicName: 'Lú',
      famousPerson: 'Pierce Brosnan (born there)',
      famousLandmark: 'Proleek Dolmen',
      gaaTeam: 'The Wee County (Red)',
      nickname: 'The Wee County',
      flag:
          'Red and white reflect the heraldic arms of the de Verdun and later Bellew families, the Norman lords of this county; red also symbolises the county\'s martial history as the smallest county in Ireland yet one of the most fiercely contested border territories between the Gaelic north and the English Pale',
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
          'Red and white recall the arms of the MacCarthy Mór dynasty, the Gaelic kings of Munster who dominated this county for centuries; their rebellion against English rule earned this county the title The Rebel County, and the red stands for the blood of resistance that defines the county\'s fiercely independent character',
    ),
    'KY': CountyClueData(
      province: 'Munster',
      gaelicName: 'Ciarraí',
      famousPerson: 'Brendan Gleeson',
      famousLandmark: 'Gap of Dunloe',
      gaaTeam: 'The Kingdom (Green & Gold)',
      nickname: 'The Kingdom',
      flag:
          'Green and gold are the ancient colours of the ancient kingdom here, a proud title this county still carries; green honours the lush landscape of the southwest and the Gaelic heritage of the O\'Sullivan and Fitzgerald clans, while gold evokes the sunsets over the Atlantic that define this rugged peninsula',
    ),
    'L': CountyClueData(
      province: 'Munster',
      gaelicName: 'Luimneach',
      famousPerson: 'Richard Harris',
      famousLandmark: 'King John\'s Castle',
      gaaTeam: 'The Treaty County (Green & White)',
      nickname: 'The Treaty City',
      flag:
          'Green and white reflect the historic treaty of 1691, the peace agreement that ended the Williamite War in Ireland; the colours honour both the Gaelic O\'Brien heritage of the region and the hope for reconciliation embedded in that historic treaty, giving this county its enduring nickname The Treaty City',
    ),
    'CE': CountyClueData(
      province: 'Munster',
      gaelicName: 'An Clár',
      famousPerson: 'Edna O\'Brien',
      famousLandmark: 'Cliffs of Moher',
      gaaTeam: 'The Banner County (Saffron & Blue)',
      nickname: 'The Banner County',
      flag:
          'Saffron was the traditional colour of Gaelic Irish dress and symbolises the ancient Celtic culture of the O\'Brien kings who ruled this county as part of Thomond; blue honours the county\'s connection to the sea and the local coastline, while saffron together with blue evokes the county\'s dual identity of Gaelic nobility and Atlantic wildness',
    ),
    'T': CountyClueData(
      province: 'Munster',
      gaelicName: 'Tiobraid Árann',
      famousPerson: 'Eamonn de Valera',
      famousLandmark: 'Rock of Cashel',
      gaaTeam: 'The Premier County (Blue & Gold)',
      nickname: 'The Premier County',
      flag:
          'Blue and gold derive from the arms of the Butler earls of Ormond, who also held great sway in this county; gold reflects the county\'s rich agricultural land and its status as the Premier County, the finest hurling territory in Ireland, while blue nods to the great Rock of Cashel that once served as the seat of Munster\'s kings',
    ),
    'W': CountyClueData(
      province: 'Munster',
      gaelicName: 'Port Láirge',
      famousPerson: 'Val Doonican',
      famousLandmark: 'Waterford Crystal Factory',
      gaaTeam: 'The Déise (White & Blue)',
      nickname: 'The Déise',
      flag:
          'White and blue recall the colours of the Déise, the ancient Gaelic tribal group who gave this county its name; the Déise were expelled from Meath in early medieval times and settled in Munster, their proud tribal identity surviving in the county\'s GAA nickname and enduring in white and blue for over a millennium',
    ),

    // CONNACHT
    'G': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Gaillimh',
      famousPerson: 'Noel Purcell',
      famousLandmark: 'Connemara National Park',
      gaaTeam: 'The Tribesmen (Maroon & White)',
      nickname: 'The City of the Tribes',
      flag:
          'Maroon and white honour the fourteen tribes of this county, the merchant families who dominated the walled city from the 13th century onward; maroon was the colour of nobility and civic authority, and the Tribes — including the Lynches, Blakes, and Kirwans — gave the city its proud identity as a prosperous Norman trading port on the Atlantic',
    ),
    'MO': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Maigh Eo',
      famousPerson: 'Michael Davitt',
      famousLandmark: 'Croagh Patrick',
      gaaTeam: 'The Green & Red',
      nickname: 'The Heather County',
      flag:
          'Green and red reflect the colours of the MacHale and Burke clans who dominated this county, with green honouring the Gaelic Connacht tradition and red drawing from the heraldic arms of the de Burgo (Burke) Norman lords; together they represent the fusion of Gaelic and Norman identities that shaped this county\'s turbulent medieval history',
    ),
    'SO': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Sligeach',
      famousPerson: 'W.B. Yeats',
      famousLandmark: 'Ben Bulben',
      gaaTeam: 'The Yeats County (Black & White)',
      nickname: 'The Yeats County',
      flag:
          'Black and white are associated with the O\'Connor and MacDonagh clans, the Gaelic chieftains of this county; the starkness of black and white also echoes the dramatic landscape of the county — the austere limestone plateau of Ben Bulben rising against pale skies — so beloved of W.B. Yeats, who made this county the spiritual heart of his poetry',
    ),
    'RN': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Ros Comáin',
      famousPerson: 'Maureen O\'Sullivan',
      famousLandmark: 'Strokestown Park House',
      gaaTeam: 'The Rossies (Primrose & Blue)',
      nickname: 'The Rossies',
      flag:
          'Primrose and blue are the colours of the O\'Connor Roe dynasty, the Gaelic kings of Connacht who ruled this county; primrose yellow signified royalty in the western Gaelic tradition, while blue echoed the rivers and lakes of this landlocked province, and together the colours preserved the memory of this county\'s once-powerful Gaelic kingdoms',
    ),
    'LM': CountyClueData(
      province: 'Connacht',
      gaelicName: 'Liatroim',
      famousPerson: 'Seán Mac Diarmada',
      famousLandmark: 'Glencar Waterfall',
      gaaTeam: 'Green & Gold',
      nickname: 'The Wild Rose County',
      flag:
          'Green and gold honour Seán Mac Diarmada, a native signatory of the 1916 Proclamation who was executed after the Easter Rising; green is the colour of Irish republicanism while gold represents the spiritual sacrifices of those who gave their lives for independence, making this county\'s flag a quiet memorial to Ireland\'s revolutionary generation',
    ),

    // ULSTER (Republic of Ireland)
    'DL': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Dún na nGall',
      famousPerson: 'Daniel O\'Donnell',
      famousLandmark: 'Slieve League Cliffs',
      gaaTeam: 'The Tír Chonaill (Green & Gold)',
      nickname: 'The Forgotten County',
      flag:
          'Green and gold represent Tír Chonaill, the ancient Gaelic territory of this county ruled by the O\'Donnell dynasty; the O\'Donnells were among the most powerful Gaelic lords in Ulster, and their alliance with the O\'Neills during the Nine Years\' War made this county a last stronghold of Gaelic Ireland before the Flight of the Earls in 1607',
    ),
    'CN': CountyClueData(
      province: 'Ulster',
      gaelicName: 'An Cabhán',
      famousPerson: 'Percy French',
      famousLandmark: 'Cuilcagh Mountain',
      gaaTeam: 'The Breffni County (Blue & White)',
      nickname: 'The Breffni County',
      flag:
          'Blue and white recall the O\'Reilly clan, the Gaelic lords of Breifne who ruled this county for centuries; the name Breffni County derives from their ancient kingdom of Breifne, and blue and white in the Gaelic heraldic tradition signified loyalty and purity — qualities the O\'Reillys embodied as one of the most enduring dynasties in Ulster',
    ),
    'MN': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Muineachán',
      famousPerson: 'Patrick Kavanagh',
      famousLandmark: 'Rossmore Forest Park',
      gaaTeam: 'The Farney County (White & Blue)',
      nickname: 'The Farney County',
      flag:
          'White and blue honour the MacMahon clan, the Gaelic lords of this county and rulers of Airghialla; their sept colours have endured through the centuries as a reminder that this was one of the last counties to be planted during the Ulster Plantation of 1610, when Gaelic land ownership was systematically dismantled',
    ),

    // ULSTER (Northern Ireland)
    'ANT': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Aontroim',
      famousPerson: 'C.S. Lewis',
      famousLandmark: 'Giant\'s Causeway',
      gaaTeam: 'The Saffrons (Saffron & White)',
      nickname: 'The Glens',
      flag:
          'Saffron and white reflect the Gaelic heritage of the McDonnell clan, the Lords of the Glens who came from the Scottish Western Isles; saffron was the traditional colour of Gaelic Irish and Scottish dress, representing this county\'s unique position as a bridge between Gaelic Ireland and the Hebrides, closest point to Scotland across the North Channel',
    ),
    'ARM': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Ard Mhacha',
      famousPerson: 'Saint Patrick',
      famousLandmark: 'Navan Fort',
      gaaTeam: 'The Orchard County (Orange & White)',
      nickname: 'The Orchard County',
      flag:
          'Orange and white recall the ecclesiastical authority of this county, home to the primatial see of all Ireland founded by Saint Patrick in the 5th century; orange in heraldry signified harvest, abundance, and religious devotion, appropriate for a county whose spiritual pre-eminence dates to the very origins of Christianity in Ireland at the ancient site of Navan Fort',
    ),
    'DWN': CountyClueData(
      province: 'Ulster',
      gaelicName: 'An Dún',
      famousPerson: 'Van Morrison',
      famousLandmark: 'Mourne Mountains',
      gaaTeam: 'The Mourne County (Red & Black)',
      nickname: 'The Mourne County',
      flag:
          'Red and black derive from the arms of the Magennis clan, the Gaelic lords of Iveagh who ruled this county for centuries; red signified martial courage while black was associated with the solemn responsibilities of lordship — fitting for a clan that defended the drumlin country here against successive waves of colonisation during the Ulster Plantation era',
    ),
    'FRM': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Fear Manach',
      famousPerson: 'Adrian Dunbar',
      famousLandmark: 'Marble Arch Caves',
      gaaTeam: 'The Erne County (Green & White)',
      nickname: 'The Lakeland County',
      flag:
          'Green and white honour the Maguire clan, the Gaelic lords of this county who ruled the Erne lakeland with great independence; the Maguires were celebrated as patrons of Gaelic learning and art, and their clan colours reflect the lush green of the island-dotted lough country and the purity associated with the monastic traditions of the region',
    ),
    'LDY': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Doire',
      famousPerson: 'Seamus Heaney',
      famousLandmark: 'Derry City Walls',
      gaaTeam: 'The Oak Leaf County (Red & White)',
      nickname: 'The Maiden City',
      flag:
          'Red and white recall the Oak Leaf of the O\'Cahan and O\'Neill clans, with the oak being the sacred tree of the Gaelic Doire (Derry), meaning oak grove; red symbolises the defiance of the city\'s famous 105-day siege of 1689, when the Protestant citizens held out against James II\'s Jacobite army — the Maiden City never having been taken',
    ),
    'TYR': CountyClueData(
      province: 'Ulster',
      gaelicName: 'Tír Eoghain',
      famousPerson: 'Brian Friel',
      famousLandmark: 'Ulster American Folk Park',
      gaaTeam: 'The Red Hand County (White & Red)',
      nickname: 'The Red Hand County',
      flag:
          'White and red centre on the Red Hand of Ulster, the ancient symbol of the O\'Neill dynasty who ruled this county as kings of Ulster; legend holds that the first man to touch the shore of Ulster would win it, and a warrior cut off his own hand and threw it to claim the prize — the red hand endures as Ulster\'s most potent heraldic emblem',
    ),
  };
}
