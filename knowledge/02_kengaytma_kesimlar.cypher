// =====================================================================
//  02_kengaytma_kesimlar.cypher
//  QO'SHIMCHA (ixtiyoriy) QATLAM — rasmdagi ontologiyada yo'q, lekin
//  8-bandda talab qilinadigan kesimlarni (hudud, toifa, mulkchilik, davr)
//  saqlash uchun kerak. Faqat 01_..._core.cypher dan KEYIN ishga tushiring.
//  Yangi labellar: Region, ProducerCategory, Period, Observation
// =====================================================================

CREATE CONSTRAINT region_code    IF NOT EXISTS FOR (n:Region)           REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT category_code  IF NOT EXISTS FOR (n:ProducerCategory) REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT period_code    IF NOT EXISTS FOR (n:Period)           REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT obs_code       IF NOT EXISTS FOR (n:Observation)      REQUIRE n.code IS UNIQUE;

UNWIND [
  {code:"P_2026_H1", name:"2026 yil yanvar-iyun (II chorak, yil boshidan o‘sib boruvchi yakun)", yil:2026, turi:"osib_boruvchi", chorak:"II"},
  {code:"P_2025_H1", name:"2025 yil yanvar-iyun (bazis davr)", yil:2025, turi:"osib_boruvchi", chorak:"II"},
  {code:"P_2026_D1", name:"2026 yil I (yanvar-mart) — diskret chorak", yil:2026, turi:"diskret", chorak:"I"},
  {code:"P_2026_D2", name:"2026 yil II (aprel-iyun) — diskret chorak", yil:2026, turi:"diskret", chorak:"II"},
  {code:"P_2026_D3", name:"2026 yil III (iyul-sentabr) — diskret chorak", yil:2026, turi:"diskret", chorak:"III"},
  {code:"P_2026_D4", name:"2026 yil IV (oktabr-dekabr) — diskret chorak", yil:2026, turi:"diskret", chorak:"IV"}
] AS row
MERGE (n:Period {code: row.code}) SET n += row;

UNWIND [
  {code:"R_UZ", name:"O‘zbekiston Respublikasi", daraja:"respublika", qiymat_2026_mlrd_som:270952.3, osish_foiz:104.7, ulush_foiz:100.0},
  {code:"R_QQ", name:"Qoraqalpog‘iston Respublikasi", daraja:"respublika (tarkibiy)", qiymat_2026_mlrd_som:15131.0, osish_foiz:106.2, ulush_foiz:5.6},
  {code:"R_AND", name:"Andijon viloyati", daraja:"viloyat", qiymat_2026_mlrd_som:28099.1, osish_foiz:104.6, ulush_foiz:10.4},
  {code:"R_BUX", name:"Buxoro viloyati", daraja:"viloyat", qiymat_2026_mlrd_som:21668.9, osish_foiz:104.3, ulush_foiz:8.0},
  {code:"R_JIZ", name:"Jizzax viloyati", daraja:"viloyat", qiymat_2026_mlrd_som:18773.9, osish_foiz:105.5, ulush_foiz:6.9},
  {code:"R_QASH", name:"Qashqadaryo viloyati", daraja:"viloyat", qiymat_2026_mlrd_som:28589.1, osish_foiz:105.4, ulush_foiz:10.6},
  {code:"R_NAV", name:"Navoiy viloyati", daraja:"viloyat", qiymat_2026_mlrd_som:9845.4, osish_foiz:104.5, ulush_foiz:3.6},
  {code:"R_NAM", name:"Namangan viloyati", daraja:"viloyat", qiymat_2026_mlrd_som:21532.9, osish_foiz:104.9, ulush_foiz:7.9},
  {code:"R_SAM", name:"Samarqand viloyati", daraja:"viloyat", qiymat_2026_mlrd_som:28663.1, osish_foiz:104.5, ulush_foiz:10.6},
  {code:"R_SUR", name:"Surxondaryo viloyati", daraja:"viloyat", qiymat_2026_mlrd_som:22022.4, osish_foiz:104.2, ulush_foiz:8.1},
  {code:"R_SIR", name:"Sirdaryo viloyati", daraja:"viloyat", qiymat_2026_mlrd_som:8412.7, osish_foiz:104.2, ulush_foiz:3.1},
  {code:"R_TOSHV", name:"Toshkent viloyati", daraja:"viloyat", qiymat_2026_mlrd_som:24434.3, osish_foiz:104.6, ulush_foiz:9.0},
  {code:"R_FAR", name:"Farg‘ona viloyati", daraja:"viloyat", qiymat_2026_mlrd_som:30601.1, osish_foiz:104.6, ulush_foiz:11.3},
  {code:"R_XOR", name:"Xorazm viloyati", daraja:"viloyat", qiymat_2026_mlrd_som:13178.4, osish_foiz:104.4, ulush_foiz:4.9},
  {code:"R_TOSHSH", name:"Toshkent shahri", daraja:"shahar", qiymat_2026_mlrd_som:0.0, osish_foiz:null, ulush_foiz:0.0}
] AS row
MERGE (n:Region {code: row.code}) SET n += row;

MATCH (r:Region), (uz:Region {code:'R_UZ'}) WHERE r.code <> 'R_UZ'
MERGE (r)-[:PART_OF]->(uz);
MATCH (r:Region {code:'R_TOSHSH'}) SET r.izoh = 'A seksiya bo‘yicha 0 — hisobot davriga bog‘liq';

UNWIND [
  {code:"PC_FERMER", name:"Fermer xo‘jaliklari", daraja:"toifa", qiymat_2026_mlrd_som:63457.4, osish_foiz:107.7, izoh:"01-bo‘lim", asos_band:"8-band"},
  {code:"PC_FERMER_KICHIK", name:"Fermer — kichik korxona va mikrofirmalar", daraja:"guruh", qiymat_2026_mlrd_som:59704.8, osish_foiz:null, izoh:"01-bo‘lim", asos_band:"8-band"},
  {code:"PC_FERMER_YIRIK", name:"Fermer — yirik tashkilotlar", daraja:"guruh", qiymat_2026_mlrd_som:3752.6, osish_foiz:null, izoh:"01-bo‘lim", asos_band:"8-band"},
  {code:"PC_DEHQON", name:"Dehqon xo‘jaliklari", daraja:"toifa", qiymat_2026_mlrd_som:167705.7, osish_foiz:101.4, izoh:"01-bo‘lim", asos_band:"8-band"},
  {code:"PC_DEHQON_NORASMIY", name:"Dehqon xo‘jaliklari (norasmiy)", daraja:"guruh", qiymat_2026_mlrd_som:149093.4, osish_foiz:null, izoh:"01-bo‘lim", asos_band:"8-band"},
  {code:"PC_DEHQON_RASMIY", name:"Dehqon xo‘jaliklari (rasmiy)", daraja:"guruh", qiymat_2026_mlrd_som:18612.3, osish_foiz:396.5, izoh:"01-bo‘lim; 2025 y. bazasi 2 937,4 mlrd so‘m — rasmiylashtirish hisobiga", asos_band:"8-band"},
  {code:"PC_TASHKILOT", name:"Qishloq xo‘jaligi faoliyatini amalga oshiruvchi tashkilotlar", daraja:"toifa", qiymat_2026_mlrd_som:21891.1, osish_foiz:118.4, izoh:"01-bo‘lim", asos_band:"8-band"},
  {code:"PC_TASHKILOT_KICHIK", name:"Tashkilotlar — kichik korxona va mikrofirmalar", daraja:"guruh", qiymat_2026_mlrd_som:16404.8, osish_foiz:null, izoh:"01-bo‘lim", asos_band:"8-band"},
  {code:"PC_TASHKILOT_YIRIK", name:"Tashkilotlar — yirik tashkilotlar", daraja:"guruh", qiymat_2026_mlrd_som:5486.3, osish_foiz:null, izoh:"01-bo‘lim", asos_band:"8-band"},
  {code:"PC_BUDJET", name:"Budjet (nobozor xizmatlar)", daraja:"toifa", qiymat_2026_mlrd_som:1625.5, osish_foiz:128.5, izoh:"01-bo‘lim", asos_band:"8-band"},
  {code:"PC_A_YIRIK", name:"Yirik tashkilotlar", daraja:"A seksiya toifasi", qiymat_2026_mlrd_som:11988.3, osish_foiz:null, izoh:"A seksiya, ulush 4,4 %", asos_band:"8-band"},
  {code:"PC_A_KICHIK", name:"Kichik korxona va mikrofirmalar", daraja:"A seksiya toifasi", qiymat_2026_mlrd_som:79799.9, osish_foiz:null, izoh:"A seksiya, ulush 29,4 %", asos_band:"8-band"},
  {code:"PC_A_DEHQON", name:"Dehqon xo‘jaliklari", daraja:"A seksiya toifasi", qiymat_2026_mlrd_som:177349.2, osish_foiz:null, izoh:"A seksiya, ulush 65,5 % (norasmiy 158 736,9 / rasmiy 18 612,3)", asos_band:"8-band"},
  {code:"PC_A_BUDJET", name:"Budjet", daraja:"A seksiya toifasi", qiymat_2026_mlrd_som:1815.0, osish_foiz:null, izoh:"A seksiya, ulush 0,7 %", asos_band:"8-band"},
  {code:"PC_MULK_DAVLAT", name:"Davlat mulki", daraja:"mulkchilik shakli", qiymat_2026_mlrd_som:5120.6, osish_foiz:null, izoh:"2025: 4 551,0; ulush 1,9 %", asos_band:"8-band"},
  {code:"PC_MULK_NODAVLAT", name:"Nodavlat mulk", daraja:"mulkchilik shakli", qiymat_2026_mlrd_som:265831.7, osish_foiz:null, izoh:"2025: 226 795,6; ulush 98,1 %", asos_band:"8-band"}
] AS row
MERGE (n:ProducerCategory {code: row.code}) SET n += row;

UNWIND [
  {g:'PC_FERMER_KICHIK', t:'PC_FERMER'}, {g:'PC_FERMER_YIRIK', t:'PC_FERMER'},
  {g:'PC_DEHQON_NORASMIY', t:'PC_DEHQON'}, {g:'PC_DEHQON_RASMIY', t:'PC_DEHQON'},
  {g:'PC_TASHKILOT_KICHIK', t:'PC_TASHKILOT'}, {g:'PC_TASHKILOT_YIRIK', t:'PC_TASHKILOT'}
] AS row
MATCH (g:ProducerCategory {code: row.g}), (t:ProducerCategory {code: row.t})
MERGE (g)-[:PART_OF]->(t);

// Observation — kesim bo'yicha haqiqiy kuzatuv qiymatlari
UNWIND [
  {code:"OBS_R_UZ_2026H1", qiymat:270952.3, birlik:"mlrd so‘m", osish_foiz:104.7, ulush_foiz:100.0, kesim:"hudud", ind:"IND_X", reg:"R_UZ", per:"P_2026_H1", cat:null},
  {code:"OBS_R_QQ_2026H1", qiymat:15131.0, birlik:"mlrd so‘m", osish_foiz:106.2, ulush_foiz:5.6, kesim:"hudud", ind:"IND_X", reg:"R_QQ", per:"P_2026_H1", cat:null},
  {code:"OBS_R_AND_2026H1", qiymat:28099.1, birlik:"mlrd so‘m", osish_foiz:104.6, ulush_foiz:10.4, kesim:"hudud", ind:"IND_X", reg:"R_AND", per:"P_2026_H1", cat:null},
  {code:"OBS_R_BUX_2026H1", qiymat:21668.9, birlik:"mlrd so‘m", osish_foiz:104.3, ulush_foiz:8.0, kesim:"hudud", ind:"IND_X", reg:"R_BUX", per:"P_2026_H1", cat:null},
  {code:"OBS_R_JIZ_2026H1", qiymat:18773.9, birlik:"mlrd so‘m", osish_foiz:105.5, ulush_foiz:6.9, kesim:"hudud", ind:"IND_X", reg:"R_JIZ", per:"P_2026_H1", cat:null},
  {code:"OBS_R_QASH_2026H1", qiymat:28589.1, birlik:"mlrd so‘m", osish_foiz:105.4, ulush_foiz:10.6, kesim:"hudud", ind:"IND_X", reg:"R_QASH", per:"P_2026_H1", cat:null},
  {code:"OBS_R_NAV_2026H1", qiymat:9845.4, birlik:"mlrd so‘m", osish_foiz:104.5, ulush_foiz:3.6, kesim:"hudud", ind:"IND_X", reg:"R_NAV", per:"P_2026_H1", cat:null},
  {code:"OBS_R_NAM_2026H1", qiymat:21532.9, birlik:"mlrd so‘m", osish_foiz:104.9, ulush_foiz:7.9, kesim:"hudud", ind:"IND_X", reg:"R_NAM", per:"P_2026_H1", cat:null},
  {code:"OBS_R_SAM_2026H1", qiymat:28663.1, birlik:"mlrd so‘m", osish_foiz:104.5, ulush_foiz:10.6, kesim:"hudud", ind:"IND_X", reg:"R_SAM", per:"P_2026_H1", cat:null},
  {code:"OBS_R_SUR_2026H1", qiymat:22022.4, birlik:"mlrd so‘m", osish_foiz:104.2, ulush_foiz:8.1, kesim:"hudud", ind:"IND_X", reg:"R_SUR", per:"P_2026_H1", cat:null},
  {code:"OBS_R_SIR_2026H1", qiymat:8412.7, birlik:"mlrd so‘m", osish_foiz:104.2, ulush_foiz:3.1, kesim:"hudud", ind:"IND_X", reg:"R_SIR", per:"P_2026_H1", cat:null},
  {code:"OBS_R_TOSHV_2026H1", qiymat:24434.3, birlik:"mlrd so‘m", osish_foiz:104.6, ulush_foiz:9.0, kesim:"hudud", ind:"IND_X", reg:"R_TOSHV", per:"P_2026_H1", cat:null},
  {code:"OBS_R_FAR_2026H1", qiymat:30601.1, birlik:"mlrd so‘m", osish_foiz:104.6, ulush_foiz:11.3, kesim:"hudud", ind:"IND_X", reg:"R_FAR", per:"P_2026_H1", cat:null},
  {code:"OBS_R_XOR_2026H1", qiymat:13178.4, birlik:"mlrd so‘m", osish_foiz:104.4, ulush_foiz:4.9, kesim:"hudud", ind:"IND_X", reg:"R_XOR", per:"P_2026_H1", cat:null},
  {code:"OBS_R_TOSHSH_2026H1", qiymat:0.0, birlik:"mlrd so‘m", osish_foiz:null, ulush_foiz:0.0, kesim:"hudud", ind:"IND_X", reg:"R_TOSHSH", per:"P_2026_H1", cat:null},
  {code:"OBS_PC_FERMER_2026H1", qiymat:63457.4, birlik:"mlrd so‘m", osish_foiz:107.7, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_VII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_FERMER"},
  {code:"OBS_PC_FERMER_KICHIK_2026H1", qiymat:59704.8, birlik:"mlrd so‘m", osish_foiz:null, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_VII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_FERMER_KICHIK"},
  {code:"OBS_PC_FERMER_YIRIK_2026H1", qiymat:3752.6, birlik:"mlrd so‘m", osish_foiz:null, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_VII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_FERMER_YIRIK"},
  {code:"OBS_PC_DEHQON_2026H1", qiymat:167705.7, birlik:"mlrd so‘m", osish_foiz:101.4, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_VII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_DEHQON"},
  {code:"OBS_PC_DEHQON_NORASMIY_2026H1", qiymat:149093.4, birlik:"mlrd so‘m", osish_foiz:null, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_VII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_DEHQON_NORASMIY"},
  {code:"OBS_PC_DEHQON_RASMIY_2026H1", qiymat:18612.3, birlik:"mlrd so‘m", osish_foiz:396.5, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_VII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_DEHQON_RASMIY"},
  {code:"OBS_PC_TASHKILOT_2026H1", qiymat:21891.1, birlik:"mlrd so‘m", osish_foiz:118.4, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_VII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_TASHKILOT"},
  {code:"OBS_PC_TASHKILOT_KICHIK_2026H1", qiymat:16404.8, birlik:"mlrd so‘m", osish_foiz:null, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_VII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_TASHKILOT_KICHIK"},
  {code:"OBS_PC_TASHKILOT_YIRIK_2026H1", qiymat:5486.3, birlik:"mlrd so‘m", osish_foiz:null, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_VII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_TASHKILOT_YIRIK"},
  {code:"OBS_PC_BUDJET_2026H1", qiymat:1625.5, birlik:"mlrd so‘m", osish_foiz:128.5, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_VII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_BUDJET"},
  {code:"OBS_PC_A_YIRIK_2026H1", qiymat:11988.3, birlik:"mlrd so‘m", osish_foiz:null, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_X", reg:"R_UZ", per:"P_2026_H1", cat:"PC_A_YIRIK"},
  {code:"OBS_PC_A_KICHIK_2026H1", qiymat:79799.9, birlik:"mlrd so‘m", osish_foiz:null, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_X", reg:"R_UZ", per:"P_2026_H1", cat:"PC_A_KICHIK"},
  {code:"OBS_PC_A_DEHQON_2026H1", qiymat:177349.2, birlik:"mlrd so‘m", osish_foiz:null, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_X", reg:"R_UZ", per:"P_2026_H1", cat:"PC_A_DEHQON"},
  {code:"OBS_PC_A_BUDJET_2026H1", qiymat:1815.0, birlik:"mlrd so‘m", osish_foiz:null, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_X", reg:"R_UZ", per:"P_2026_H1", cat:"PC_A_BUDJET"},
  {code:"OBS_PC_MULK_DAVLAT_2026H1", qiymat:5120.6, birlik:"mlrd so‘m", osish_foiz:null, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_X", reg:"R_UZ", per:"P_2026_H1", cat:"PC_MULK_DAVLAT"},
  {code:"OBS_PC_MULK_NODAVLAT_2026H1", qiymat:265831.7, birlik:"mlrd so‘m", osish_foiz:null, ulush_foiz:null, kesim:"ishlab chiqaruvchilar toifasi", ind:"IND_X", reg:"R_UZ", per:"P_2026_H1", cat:"PC_MULK_NODAVLAT"},
  {code:"OBS_02_YIRIK", qiymat:2586.2, birlik:"mlrd so‘m", osish_foiz:123.8, ulush_foiz:null, kesim:"bo‘lim × toifa", ind:"IND_VIII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_A_YIRIK"},
  {code:"OBS_02_KICHIK", qiymat:2031.0, birlik:"mlrd so‘m", osish_foiz:260.0, ulush_foiz:null, kesim:"bo‘lim × toifa", ind:"IND_VIII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_A_KICHIK"},
  {code:"OBS_02_DEHQON", qiymat:9531.6, birlik:"mlrd so‘m", osish_foiz:91.7, ulush_foiz:null, kesim:"bo‘lim × toifa", ind:"IND_VIII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_A_DEHQON"},
  {code:"OBS_02_BUDJET", qiymat:189.5, birlik:"mlrd so‘m", osish_foiz:93.0, ulush_foiz:null, kesim:"bo‘lim × toifa", ind:"IND_VIII", reg:"R_UZ", per:"P_2026_H1", cat:"PC_A_BUDJET"},
  {code:"OBS_03_YIRIK", qiymat:163.2, birlik:"mlrd so‘m", osish_foiz:291.9, ulush_foiz:null, kesim:"bo‘lim × toifa", ind:"IND_IX", reg:"R_UZ", per:"P_2026_H1", cat:"PC_A_YIRIK"},
  {code:"OBS_03_KICHIK", qiymat:1659.3, birlik:"mlrd so‘m", osish_foiz:133.2, ulush_foiz:null, kesim:"bo‘lim × toifa", ind:"IND_IX", reg:"R_UZ", per:"P_2026_H1", cat:"PC_A_KICHIK"},
  {code:"OBS_03_DEHQON", qiymat:112.0, birlik:"mlrd so‘m", osish_foiz:96.0, ulush_foiz:null, kesim:"bo‘lim × toifa", ind:"IND_IX", reg:"R_UZ", per:"P_2026_H1", cat:"PC_A_DEHQON"}
] AS row
MERGE (n:Observation {code: row.code}) SET n += row;

// Observation bog'lanishlari
MATCH (o:Observation), (i:Indicator {code: o.ind})   MERGE (o)-[:OF_INDICATOR]->(i);
MATCH (o:Observation), (r:Region {code: o.reg})      MERGE (o)-[:IN_REGION]->(r);
MATCH (o:Observation), (p:Period {code: o.per})      MERGE (o)-[:FOR_PERIOD]->(p);
MATCH (o:Observation) WHERE o.cat IS NOT NULL
MATCH (c:ProducerCategory {code: o.cat})             MERGE (o)-[:BY_CATEGORY]->(c);

// Hisob-kitob kesimlari 8-bandga asoslanadi
MATCH (p:Paragraph {number:8})
MATCH (n) WHERE n:Region OR n:ProducerCategory
MERGE (n)-[:DEFINED_IN]->(p);
