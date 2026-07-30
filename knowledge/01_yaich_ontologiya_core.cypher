// =====================================================================
//  QISHLOQ, O'RMON VA BALIQCHILIK XO'JALIGI YALPI ISHLAB CHIQARISHI (YaICh)
//  BILIM GRAFI (Knowledge Graph) — Neo4j / Cypher
// ---------------------------------------------------------------------
//  Manbalar:
//   1) Statistika agentligining 30.04.2024 y. 86-son buyrug'i bilan
//      tasdiqlangan "Uslubiy nizom" (8 bob, 82 band, 7 ilova)  -> Buyruq_86.docx
//   2) "YaICh hisoblash arxitekturasi" interaktiv hujjati
//      (2026 y. yanvar-iyun haqiqiy natijalari)                -> ...TOLIQ.html
//  Ontologiya: rasmda ko'rsatilgan 15 ta node label + 11 ta relationship
//  Fayl: 01_ontologiya_core.cypher
//  Ishga tushirish:  cat 01_ontologiya_core.cypher | cypher-shell -u neo4j -p <parol>
// =====================================================================

// ---------------------------------------------------------------------
// 0. TOZALASH (kerak bo'lsa izohdan chiqaring)
// ---------------------------------------------------------------------
// MATCH (n) DETACH DELETE n;

// ---------------------------------------------------------------------
// 1. CONSTRAINT VA INDEKSLAR
// ---------------------------------------------------------------------
CREATE CONSTRAINT indicator_code     IF NOT EXISTS FOR (n:Indicator)     REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT methodology_code   IF NOT EXISTS FOR (n:Methodology)   REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT formula_code       IF NOT EXISTS FOR (n:Formula)       REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT paragraph_number   IF NOT EXISTS FOR (n:Paragraph)     REQUIRE n.number IS UNIQUE;
CREATE CONSTRAINT table_code         IF NOT EXISTS FOR (n:Table)         REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT appendix_code      IF NOT EXISTS FOR (n:Appendix)      REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT column_code        IF NOT EXISTS FOR (n:Column)        REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT source_code        IF NOT EXISTS FOR (n:Source)        REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT report_code        IF NOT EXISTS FOR (n:Report)        REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT price_code         IF NOT EXISTS FOR (n:Price)         REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT unit_code          IF NOT EXISTS FOR (n:Unit)          REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT organization_code  IF NOT EXISTS FOR (n:Organization)  REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT department_code    IF NOT EXISTS FOR (n:Department)    REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT system_code        IF NOT EXISTS FOR (n:System)        REQUIRE n.code IS UNIQUE;
CREATE CONSTRAINT legaldocument_code IF NOT EXISTS FOR (n:LegalDocument) REQUIRE n.code IS UNIQUE;

CREATE INDEX indicator_name IF NOT EXISTS FOR (n:Indicator) ON (n.name);
CREATE INDEX indicator_soha IF NOT EXISTS FOR (n:Indicator) ON (n.soha);
CREATE FULLTEXT INDEX ft_paragraph IF NOT EXISTS FOR (n:Paragraph) ON EACH [n.text, n.title];
CREATE FULLTEXT INDEX ft_indicator IF NOT EXISTS FOR (n:Indicator) ON EACH [n.name, n.izoh];

// ---------------------------------------------------------------------
// 2. LegalDocument — huquqiy hujjatlar (Buyruq, Qonun, Qaror)
// ---------------------------------------------------------------------
UNWIND [
  {code:'LD_BUYRUQ_86', turi:'Buyruq',   raqam:'86-son', sana:date('2024-04-30'),
   name:'Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblash bo‘yicha uslubiy nizomni tasdiqlash to‘g‘risida',
   qabul_qilgan:'O‘zbekiston Respublikasi Prezidenti huzuridagi Statistika agentligi', holati:'amalda'},
  {code:'LD_QONUN_RS', turi:'Qonun', raqam:'O‘RQ', sana:null,
   name:'O‘zbekiston Respublikasining "Rasmiy statistika to‘g‘risida"gi Qonuni',
   qabul_qilgan:'Oliy Majlis', holati:'amalda'},
  {code:'LD_PQ_114', turi:'Prezident qarori', raqam:'PQ-114', sana:date('2024-03-04'),
   name:'O‘zbekiston Respublikasi Prezidenti huzuridagi Statistika agentligi faoliyatini tashkil etish chora-tadbirlari to‘g‘risida',
   qabul_qilgan:'O‘zbekiston Respublikasi Prezidenti', holati:'amalda'},
  {code:'LD_STAT_DASTUR', turi:'Dastur', raqam:null, sana:null,
   name:'"Statistika dasturi" va "Statistika ishlarini ishlab chiqish dasturi"',
   qabul_qilgan:'Statistika agentligi', holati:'amalda'},
  {code:'LD_QAROR_26_2021', turi:'Qaror', raqam:'26-son', sana:date('2021-07-28'),
   name:'Davlat statistika qo‘mitasining oldingi uslubiy nizomni tasdiqlash to‘g‘risidagi qarori',
   qabul_qilgan:'O‘zbekiston Respublikasi Davlat statistika qo‘mitasi', holati:'kuchini yo‘qotgan (86-son buyruqning 2-bandi)'}
] AS row
MERGE (d:LegalDocument {code: row.code}) SET d += row;

// ---------------------------------------------------------------------
// 3. Methodology — Uslubiy nizom
// ---------------------------------------------------------------------
MERGE (m:Methodology {code:'MET_YAICH'})
SET m.name       = 'Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblash bo‘yicha Uslubiy nizom',
    m.qisqa_nom  = 'YaICh Uslubiy nizomi',
    m.soha       = 'IFUT-2, A seksiya — Qishloq, o‘rmon va baliqchilik xo‘jaligi',
    m.boblar     = 8,
    m.bandlar    = 82,
    m.ilovalar   = 7,
    m.standart   = ['GSBPM','GSIM'],
    m.tasdiqlangan_sana = date('2024-04-30'),
    m.izoh       = 'FAO, MDH Davlatlararo statistika qo‘mitasi tavsiyalari va milliy me’yoriy hujjatlar asosida ishlab chiqilgan (81, 82-bandlar)';

// REGULATED_BY : Methodology -> LegalDocument
MATCH (m:Methodology {code:'MET_YAICH'})
MATCH (d:LegalDocument) WHERE d.code IN ['LD_BUYRUQ_86','LD_QONUN_RS','LD_PQ_114','LD_STAT_DASTUR']
MERGE (m)-[r:REGULATED_BY]->(d)
SET r.rol = CASE d.code
              WHEN 'LD_BUYRUQ_86'   THEN 'tasdiqlovchi hujjat'
              WHEN 'LD_QONUN_RS'    THEN 'qonuniy asos'
              WHEN 'LD_PQ_114'      THEN 'ijro asosi'
              ELSE 'muddat va tartib asosi' END;

MATCH (yangi:LegalDocument {code:'LD_BUYRUQ_86'}), (eski:LegalDocument {code:'LD_QAROR_26_2021'})
MERGE (yangi)-[:REPLACES]->(eski);

// ---------------------------------------------------------------------
// 4. Appendix — Uslubiy nizom ilovalari
// ---------------------------------------------------------------------
UNWIND [
  {code:"APP_1", name:"1-ilova", title:"Qishloq xo‘jaligi mahsulotlarining fizik hajmini shakllantirish", asos:"9-13, 73-bandlar"},
  {code:"APP_2", name:"2-ilova", title:"YaICh ni joriy narxlarda hisoblash sxemasi", asos:"31-band"},
  {code:"APP_3", name:"3-ilova", title:"YaICh ni taqqoslama narxlarda hisoblash sxemasi", asos:"47-band"},
  {code:"APP_4", name:"4-ilova", title:"Asosiy turdagi mahsulotlar guruhiga kiritilmagan boshqa turdagi qishloq xo‘jaligi mahsulotlari ro‘yxati", asos:"19, 20-bandlar"},
  {code:"APP_5", name:"5-ilova", title:"Sabzavot ekinlari turlari bo‘yicha choraklik hajmlarni yillik ulush asosida hisoblash", asos:"61-band"},
  {code:"APP_6", name:"6-ilova", title:"Qo‘shimcha mahsulotlarning taxminiy me’yorlari", asos:"62-band"},
  {code:"APP_7", name:"7-ilova", title:"Mahsulot va qiymatlarni diskret choraklar asosida shakllantirish", asos:"73-band"}
] AS row
MERGE (a:Appendix {code: row.code}) SET a += row;

MATCH (a:Appendix), (m:Methodology {code:'MET_YAICH'})
MERGE (a)-[:PART_OF]->(m);

// ---------------------------------------------------------------------
// 5. Paragraph — Uslubiy nizomning 82 ta bandi
// ---------------------------------------------------------------------
UNWIND [
  {number:1, code:"BAND_1", chapter:1, chapter_title:"Umumiy qoidalar", section:null, title:"Uslubiy nizom GSBPM ning shakllantirish, yig‘ish, qayta ishlash, tahlil qilish va baholash bosqichlari doirasida ma’lumotlarni yig‘ish mexanizmi, qayta ishlash ", text:"Uslubiy nizom GSBPM ning shakllantirish, yig‘ish, qayta ishlash, tahlil qilish va baholash bosqichlari doirasida ma’lumotlarni yig‘ish mexanizmi, qayta ishlash va tahlil komponentlari, ishlab chiqarish jarayonlarini tartibga solish va ishga tushirish, tanlanmani shakllantirish, kuzatuvni tashkil etish, amalga oshirish va yakunlash, tasniflash va kodlashtirish, xatoliklarni tekshirish, tahrirlash va imputatsiyalash, ulush (vazn)larni hisob-kitob qilish, umumlashtirish, qayta ishlashni yakunlash, dastlabki materiallarni tayyorlash, validatsiya qilish, tahliliy ishlarni yakunlash, baholash uchun ma’lumot yig‘ish kabi jarayonlarini o‘z ichiga oladi."},
  {number:2, code:"BAND_2", chapter:1, chapter_title:"Umumiy qoidalar", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblash respublika va hududiy darajada tegishli yil uchun “Statistika", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblash respublika va hududiy darajada tegishli yil uchun “Statistika dasturi”da va “Statistika ishlarini ishlab chiqish dasturi”da belgilangan muddatlarda amalga oshiriladi."},
  {number:3, code:"BAND_3", chapter:1, chapter_title:"Umumiy qoidalar", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi faoliyatini umumlashtirilgan holda tavsiflash uchun o‘zaro bog‘liq bo‘lgan natura va qiymat ko‘rsatkichlari tizimidan f", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi faoliyatini umumlashtirilgan holda tavsiflash uchun o‘zaro bog‘liq bo‘lgan natura va qiymat ko‘rsatkichlari tizimidan foydalaniladi. Ko‘rsatkichlar tizimida asosiy o‘rinni, qishloq xo‘jaligi statistikasida mahsulotlarning aniq turlari yetishtirilishini tavsiflash uchun foydalaniladigan natura ko‘rsatkichlari egallaydi. Lekin, bu ko‘rsatkichlar har xil turdagi mahsulotlar bo‘yicha jamlanma natijalarni olish imkoniyatini bermaydi. Qishloq, o‘rmon va baliqchilik xo‘jaligi faoliyatining jamlanma tavsifi, soha faoliyatining jamlanma yakuniy natijalarini olishga imkon beradigan har xil turdagi mahsulotlarning taqqoslanishini ta’minlaydigan qiymat ko‘rsatkichlaridan foydalanilgan holdagina mumkin bo‘ladi. Qishloq xo‘jaligi statistikasida asosiy jamlanma qiymat ko‘rsatkichi qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishi hisoblanadi."},
  {number:4, code:"BAND_4", chapter:1, chapter_title:"Umumiy qoidalar", section:null, title:"Mazkur Uslubiy nizomda quyidagi muhim tushunchalar qo‘llaniladi: qishloq xo‘jaligi ‒ dehqonchilik va chorvachilik mahsulotlarini yetishtirish bilan bog‘liq bo‘l", text:"Mazkur Uslubiy nizomda quyidagi muhim tushunchalar qo‘llaniladi: qishloq xo‘jaligi ‒ dehqonchilik va chorvachilik mahsulotlarini yetishtirish bilan bog‘liq bo‘lgan soha; dehqonchilik ‒ qishloq xo‘jaligi ekinlarini o‘stirish va yetishtirish bilan bog‘liq bo‘lgan qishloq xo‘jaligi sohasi. Dehqonchilik mahsulotlarini yetishtirish bir - ikki va ko‘p yillik ekinlarni, shuningdek, urug‘lik va ko‘chat materiallarini o‘stirish va yetishtirishni o‘z ichiga oladi; chorvachilik ‒ qishloq xo‘jaligi hayvonlari, parrandalari, asalarilari va ipak qurtini o‘stirish va urchitish bilan bog‘liq bo‘lgan qishloq xo‘jaligi sohasi; o‘rmon xo‘jaligi ‒ faoliyat turi o‘rmon resurslarini takror ishlab chiqarish va o‘rmon resurslaridan foydalanish, xususan o‘rmonchilik, o‘rmonzorlarni barpo etish va yog‘ochni qayta ishlash tarmoqlari uchun binokorlik dumaloq yog‘ochlarini yetishtirish, shuningdek, yovvoyi holda o‘suvchi o‘rmon mahsulotlarini yig‘ish bilan bog‘liq bo‘lgan soha. O‘rmon xo‘jaligi faoliyati tabiiy o‘rmonlar yoki sun’iy o‘rmonzorlar doirasida amalga oshiriladi; o‘rmonchilik va o‘rmonzorlarni barpo etish ‒ imoratbop yog‘och-taxta o‘rmon daraxtlarini o‘tqazish, qayta o‘tqazish, ko‘chirib o‘tqazish, shuningdek, yoqilg‘i yog‘ochlarni qo‘shgan holda, novdadan o‘tqazilgan yosh o‘rmonlarni o‘stirish, o‘rmon va o‘rmonning daraxt kesish uchun ajratilgan uchastkasini siyraklashtirish va muhofaza qilish bilan bog‘liq bo‘lgan o‘rmon xo‘jaligi faoliyati sohasi. O‘rmonchilik faoliyati, shuningdek, o‘rmon daraxtlari ko‘chatlarini ko‘paytirish va ularni parvarish qilish bilan ham bog‘liq; yog‘och tayyorlash ‒ yog‘ochni qayta ishlash tarmog‘i uchun dumaloq binokorlik yog‘ochlarini yetishtirish, shuningdek, yoqilg‘i yog‘och – yog‘och ko‘mir, yog‘och parchalari va boshqalarni yig‘ish va ishlab chiqarish bilan bog‘liq bo‘lgan o‘rmon xo‘jaligi faoliyati turi; yog‘och bo‘lmagan o‘rmon mahsulotlari ‒ o‘rmon xo‘jaliklari tomonidan odamlar yoki hayvonlar uchun oziq-ovqat, shuningdek, boshqa foydalanish maqsadlarida dorivor yoki kosmetik o‘simliklar sifatida yetishtiriladigan yovvoyi holda o‘suvchi o‘simliklar guruhi; baliqchilik xo‘jaligi ‒ baliq ovlash va suv bioresurslarini, akvakulturani saqlash, suv bioresurslaridan olinadigan baliq va boshqa mahsulotlarni yetishtirish va sotish bo‘yicha faoliyat turi; qishloq, o‘rmon va baliqchilik xo‘jaligi ‒ qishloq xo‘jaligi ekinlarini yetishtirish, qishloq xo‘jaligi hayvonlarini, parrandalarini, asalarilarini, ipak qurtini, baliqlarni saqlash va ko‘paytirish, yog‘och, yog‘och bo‘lmagan yovvoyi holda o‘suvchi o‘rmon xo‘jaligi mahsulotlarni olish, suv organizmlarini ovlashni o‘z ichiga oladi; qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishi ‒ sohada o‘z iste’moli va sotish uchun yaratilgan mahsulot va xizmatlarning umumiy qiymati. Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishi dehqonchilik va chorvachilik mahsulot (xizmat)lari yalpi ishlab chiqarishi, ovchilik xo‘jaligida, o‘rmonchilik va yog‘och tayyorlash, baliq ovlash va akvakultura sohasida yetishtirilgan mahsulot (xizmat)lar qiymati asosida shakllantiriladi; dehqonchilik va chorvachilik mahsulot (xizmat)lari yalpi ishlab chiqarishi ‒ dehqonchilikda tugallanmagan ishlab chiqarish qiymatlarining o‘zgarishini hisobga olgan holda, yetishtirilgan dehqonchilik va chorvachilik mahsulotlari, shuningdek, ushbu sohalarda ko‘rsatilgan xizmatlar qiymatlarining umumiy yig‘indisini o‘zida ifodalaydi; yetishtirilgan dehqonchilik mahsulotlarining qiymati ‒ joriy yil hosilidan olingan barcha qishloq xo‘jaligi ekinlarining don, texnik ekinlar, kartoshka, sabzavotlar va poliz ekinlari, mevalar va rezavorlar, uzum, ozuqa ekinlari, urug‘lik va o‘tqaziladigan ko‘chat materiallari, shuningdek, dehqonchilikda tugallanmagan ishlab chiqarish, dehqonchilikning boshqa turdagi mahsulotlari qiymatlarini o‘z ichiga oladi; dehqonchilikda tugallanmagan ishlab chiqarish qiymatlari ‒ kelgusi yil hosili uchun joriy yil xarajatlarini, yerlarga ishlov berish va yerlarni shudgor qilish bo‘yicha xizmatlarni, kuzgi ekinlarni ekish uchun yerlarni tayyorlash, ko‘p yillik daraxtlarni o‘tqazish va xo‘jalikda foydalanish yoshigacha o‘stirish xarajatlarini o‘z ichiga oladi; ishlab chiqarilgan chorvachilik mahsulotlarining qiymati ‒ qishloq xo‘jaligi hayvonlarini, parrandalarini, asalarilarni, ipak qurtini o‘stirish natijasida olingan mahsulotlar (go‘sht, sut, tuxum, jun, qorako‘l, asal, pilla, mo‘yna, shuningdek, chorvachilikning boshqa turdagi mahsulotlari) qiymatlarini o‘z ichiga oladi. Chorvachilik mahsulotlarini yetishtirish xarajatlari yil davomida bir maromda amalga oshiriladi va chorvachilikning hisobot yilidagi barcha xarajatlari, odatda joriy yil mahsulotlari tannarxi tarkibiga qo‘shiladi, shuning uchun aralash yillar xarajatlarining hisobida ular tugallanmagan ishlab chiqarish sifatida ajratilmaydi; dehqonchilik va chorvachilik sohasidagi xizmatlar qiymati ‒ hosilni yig‘ib olish, yerlarni yaxshilash bo‘yicha xizmatlar, tuproqni kimyolashtirish, o‘g‘itlarni tayyorlash va solish bo‘yicha xizmatlar, qishloq xo‘jaligi ekinlarini kasalliklardan va zararkunandalardan himoya qilish bo‘yicha xizmatlar, agromeliorativ ishlarni o‘tkazish bo‘yicha xizmatlar, suv xo‘jaligi tashkilotlarining irrigatsion va meliorativ tizimlarni ekspluatatsiya qilish bo‘yicha xizmatlari, qishloq xo‘jaligi hayvonlarini, parrandalarini, asalarilarni, ipak qurtini ko‘paytirish bo‘yicha qo‘shimcha xizmatlar, qishloq xo‘jaligiga zootexniya xizmati ko‘rsatish va boshqalar qiymatini o‘z ichiga oladi; joriy narxlar ‒ ko‘rib chiqilayotgan davrda amal qiladigan narxlar; taqqoslama narxlar ‒ turli davrlar uchun mahsulot ishlab yetishtirishning fizik hajmini qiymat ko‘rinishida taqqoslashda shartli ravishda baza sifatida qabul qilinadigan ma’lum bir yil yoki davr narxlari; ekstrapolyatsiya ‒ joriy narxlardagi bazis davr ma’lumotlarini fizik hajm indeksiga yoki tegishli iqtisodiy ko‘rsatkichlar dinamikasini aks ettiruvchi natural indikatorga ko‘paytirish."},
  {number:5, code:"BAND_5", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:null, title:"O‘zbekiston Respublikasi iqtisodiy faoliyat turlari umumdavlat tasniflagichi (IFUT-2)ga muvofiq, A seksiya “Qishloq, o‘rmon va baliqchilik xo‘jaligi” 3 ta bo‘li", text:"O‘zbekiston Respublikasi iqtisodiy faoliyat turlari umumdavlat tasniflagichi (IFUT-2)ga muvofiq, A seksiya “Qishloq, o‘rmon va baliqchilik xo‘jaligi” 3 ta bo‘limdan, ya’ni, dehqonchilik va chorvachilik, ovchilik va bu sohalarda xizmat ko‘rsatish (01- bo‘lim), o‘rmonchilik va yog‘och tayyorlash (02- bo‘lim), baliq ovlash va akvakulturadan (03 bo‘lim) tashkil topgan."},
  {number:6, code:"BAND_6", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishining qiymat ko‘rinishidagi hajmi, barcha ishlab chiqaruvchilar tomonidan y", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishining qiymat ko‘rinishidagi hajmi, barcha ishlab chiqaruvchilar tomonidan yetishtirilgan dehqonchilik, chorvachilik, ovchilik, o‘rmonchilik va baliqchilik mahsulot (xizmat)lari yig‘indisi sifatida shakllanadi."},
  {number:7, code:"BAND_7", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblash joriy va taqqoslama narxlarda choraklik asosda tezkor ma’lumo", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblash joriy va taqqoslama narxlarda choraklik asosda tezkor ma’lumotlar bo‘yicha (joriy hisoblashlar) va yillik asosda yakuniy ma’lumotlar bo‘yicha (yillik hisoblashlar) amalga oshiriladi. Hisoblash yil boshidan o‘sib boruvchi yakunda amalga oshiriladi."},
  {number:8, code:"BAND_8", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblash qishloq xo‘jaligi ishlab chiqaruvchilari toifalari, shu jumla", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblash qishloq xo‘jaligi ishlab chiqaruvchilari toifalari, shu jumladan fermer, dehqon va tomorqa xo‘jaliklari, qishloq xo‘jaligi faoliyatini amalga oshiruvchi tashkilotlar va boshqalar darajasida, Qoraqalpog‘iston Respublikasi, viloyatlar va Toshkent shahri kesimida, tumanlar va shaharlar bo‘yicha, shuningdek, mahsulot turlari bo‘yicha amalga oshiriladi. Shundan so‘ng, olingan ma’lumotlar O‘zbekiston Respublikasi bo‘yicha yaxlit holda umumlashtiriladi."},
  {number:9, code:"BAND_9", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"1-§. Mahsulotlarning fizik hajmini aniqlash", title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblash mahsulotlarning fizik hajmini aniqlashdan boshlanadi", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblash mahsulotlarning fizik hajmini aniqlashdan boshlanadi. Hisoblash uchun mahsulot yetishtirishning fizik hajmi barcha ishlab chiqaruvchilar tomonidan yaratilgan dehqonchilik, chorvachilik, ovchlilik, o‘rmon va baliqchilik xo‘jaligi mahsulotlari, xizmatlar sifatida shakllantiriladi (1-ilova)."},
  {number:10, code:"BAND_10", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"1-§. Mahsulotlarning fizik hajmini aniqlash", title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulotlari yetishtirish hajmlari mahsulot turlari bo‘yicha fizik o‘lchov birligi (tonna, dona)da hisobga olinadi (1-2", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulotlari yetishtirish hajmlari mahsulot turlari bo‘yicha fizik o‘lchov birligi (tonna, dona)da hisobga olinadi (1-2 va 3-ilovalar)."},
  {number:11, code:"BAND_11", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"1-§. Mahsulotlarning fizik hajmini aniqlash", title:"Ishlab chiqarishning fizik hajmiga ishlab chiqarish jarayoni natijasida yetishtirilgan barcha mahsulotlar, jumladan ishlab chiqaruvchilar tomonidan o‘z shaxsiy ", text:"Ishlab chiqarishning fizik hajmiga ishlab chiqarish jarayoni natijasida yetishtirilgan barcha mahsulotlar, jumladan ishlab chiqaruvchilar tomonidan o‘z shaxsiy iste’moli uchun foydalanilgan mahsulotlar hajmi kiritiladi."},
  {number:12, code:"BAND_12", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"1-§. Mahsulotlarning fizik hajmini aniqlash", title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulotlarini yetishtirishning fizik hajmlarini aniqlash uchun axborot manbalari bo‘lib, 7-bobda keltirilgan manbalar ", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulotlarini yetishtirishning fizik hajmlarini aniqlash uchun axborot manbalari bo‘lib, 7-bobda keltirilgan manbalar xizmat qiladi."},
  {number:13, code:"BAND_13", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"1-§. Mahsulotlarning fizik hajmini aniqlash", title:"Mahsulotlarning fizik hajmi aniqlanganidan so‘ng ularni qiymat ko‘rinishida baholash amalga oshiriladi", text:"Mahsulotlarning fizik hajmi aniqlanganidan so‘ng ularni qiymat ko‘rinishida baholash amalga oshiriladi."},
  {number:14, code:"BAND_14", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 2. IFUT-2, A seksiyaning 01 bo‘limi bo‘yicha dehqonchilik va chorvachilik, ovchilik mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"Yetishtirilgan dehqonchilik va chorvachilik mahsulotlarining qiymatlarini amaldagi, joriy narxlarda hisoblash, hisobot davrida yetishtirilgan barcha qishloq xo‘", text:"Yetishtirilgan dehqonchilik va chorvachilik mahsulotlarining qiymatlarini amaldagi, joriy narxlarda hisoblash, hisobot davrida yetishtirilgan barcha qishloq xo‘jaligi mahsulotlarini ularning o‘rtacha sotish narxlari bo‘yicha to‘g‘ridan-to‘g‘ri baholash yo‘li bilan, mahsulot turlari va har bir qishloq xo‘jaligi ishlab chiqaruvchilari toifalari bo‘yicha alohida quyidagi formuladan foydalangan holda amalga oshiriladi, bunda, yetishtirilgan mahsulotning fizik hajmi uning o‘rtacha sotish narxiga ko‘paytiriladi (2-ilova): , bu yerda, ‒ yetishtirilgan -turdagi dehqonchilik va chorvachilik mahsulotining joriy narxlardagi qiymati; ‒ hisobot davrida yetishtirilgan -turdagi mahsulotning fizik hajmi; ‒ -turdagi mahsulotning hisobot davridagi o‘rtacha sotish narxi; Masalan, hisobot davrida yil boshidan 100 tonna don ekinlari yetishtirilgan, uning 1 tonnasining joriy narxlardagi sotish narxi 200 ming so‘mni tashkil qiladi. = 100 / 1000000 = 20 mln. so‘m. Demak, hisoblash yakunlariga ko‘ra, don ekinlarining joriy narxlardagi qiymati baholashga ko‘ra 20 mln. so‘mni tashkil qiladi."},
  {number:15, code:"BAND_15", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 2. IFUT-2, A seksiyaning 01 bo‘limi bo‘yicha dehqonchilik va chorvachilik, ovchilik mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"Boshqa dehqonchilik va chorvachilik mahsulotlarining qiymatlari ham shu kabi hisoblanadi va har bir mahsulot (i) turi bo‘yicha olingan ma’lumotlar jami dehqonch", text:"Boshqa dehqonchilik va chorvachilik mahsulotlarining qiymatlari ham shu kabi hisoblanadi va har bir mahsulot (i) turi bo‘yicha olingan ma’lumotlar jami dehqonchilik va chorvachilik mahsulotlari qiymati sifatida jamlanadi."},
  {number:16, code:"BAND_16", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 2. IFUT-2, A seksiyaning 01 bo‘limi bo‘yicha dehqonchilik va chorvachilik, ovchilik mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"Shunday qilib, jami dehqonchilik va chorvachilik mahsulotlari qiymatlarini hisoblashni quyidagi formula bilan ifodalash mumkin: bu yerda, ‒ yetishtirilgan jami ", text:"Shunday qilib, jami dehqonchilik va chorvachilik mahsulotlari qiymatlarini hisoblashni quyidagi formula bilan ifodalash mumkin: bu yerda, ‒ yetishtirilgan jami dehqonchilik va chorvachilik mahsulotlarining joriy narxlardagi qiymati; ‒ yetishtirilgan i turdagi mahsulotning fizik hajmi; ‒ i turdagi mahsulotning hisobot davridagi o‘rtacha sotish narxi;"},
  {number:17, code:"BAND_17", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 2. IFUT-2, A seksiyaning 01 bo‘limi bo‘yicha dehqonchilik va chorvachilik, ovchilik mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"Hisoblashda dehqonchilik va chorvachilik mahsulotlari asosiy va boshqa turlar bo‘yicha guruhlanadi", text:"Hisoblashda dehqonchilik va chorvachilik mahsulotlari asosiy va boshqa turlar bo‘yicha guruhlanadi. Asosiy turdagi mahsulotlar ‒ oziq-ovqat mahsulotlarini va qayta ishlash tarmoqlari uchun qishloq xo‘jaligi xomashyosini yetishtirish bo‘yicha katta ahamiyatga ega bo‘lgan mahsulot turlari. Boshqa turdagi mahsulotlar ‒ aholi uchun oziq-ovqat mahsulotlari va qayta ishlash tarmoqlari uchun qishloq xo‘jaligi xom-ashyosi sifatida kam ahamiyatga ega bo‘lgan mahsulot turlari."},
  {number:18, code:"BAND_18", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 2. IFUT-2, A seksiyaning 01 bo‘limi bo‘yicha dehqonchilik va chorvachilik, ovchilik mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"Dehqonchilikda asosiy turdagi mahsulotlarga don ekinlari, paxta xom ashyosi, kartoshka, sabzavot va poliz ekinlari, mevalar, rezavorlar va uzum, chorvachilikda ", text:"Dehqonchilikda asosiy turdagi mahsulotlarga don ekinlari, paxta xom ashyosi, kartoshka, sabzavot va poliz ekinlari, mevalar, rezavorlar va uzum, chorvachilikda esa ‒ tirik vaznda go‘sht, sut, tuxum, asal, jun, qorako‘l teri va pilla yetishtirish kiradi."},
  {number:19, code:"BAND_19", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 2. IFUT-2, A seksiyaning 01 bo‘limi bo‘yicha dehqonchilik va chorvachilik, ovchilik mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"Dehqonchilikda boshqa turdagi mahsulotlarga tamaki, dorivor ekinlar, kanop, qand lavlagi, kungaboqar, soya, kunjut, maxsar, yeryong‘oq, sabzavot ko‘chatlari, sa", text:"Dehqonchilikda boshqa turdagi mahsulotlarga tamaki, dorivor ekinlar, kanop, qand lavlagi, kungaboqar, soya, kunjut, maxsar, yeryong‘oq, sabzavot ko‘chatlari, sabzavot va poliz ekinlari urug‘lari, gullar, gul ko‘chatlari, poxol, somon, don ekinlari poyasi, tut bargi, g‘o‘zapoya yetishtirish, shuningdek, ko‘p yillik yosh ko‘chatlarni o‘stirish va tugallanmagan ishlab chiqarish qiymatlari kiradi (4-ilova)."},
  {number:20, code:"BAND_20", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 2. IFUT-2, A seksiyaning 01 bo‘limi bo‘yicha dehqonchilik va chorvachilik, ovchilik mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"Chorvachilikda boshqa turdagi mahsulotlarga yetishtirilgan asalari mumi, gul changi, ona asalari suti, propolis, asalari zahri, asalari uyalari, ipak qurti tuxu", text:"Chorvachilikda boshqa turdagi mahsulotlarga yetishtirilgan asalari mumi, gul changi, ona asalari suti, propolis, asalari zahri, asalari uyalari, ipak qurti tuxumi (grena), mo‘ynali hayvonlar mahsulotlarini, par, pat, go‘ng, axlat, shuningdek, olingan nasl, qishloq xo‘jaligi hayvonlarining spermasi (maniy) va embrionlari qiymati kiradi (4-ilova)."},
  {number:21, code:"BAND_21", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 2. IFUT-2, A seksiyaning 01 bo‘limi bo‘yicha dehqonchilik va chorvachilik, ovchilik mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"Dehqonchilikda tugallanmagan ishlab chiqarish qiymati kelgusi yil hosili uchun joriy yilning kuzida ekilgan kuzgi ekinlarning turlari bo‘yicha 1 gektariga bo‘lg", text:"Dehqonchilikda tugallanmagan ishlab chiqarish qiymati kelgusi yil hosili uchun joriy yilning kuzida ekilgan kuzgi ekinlarning turlari bo‘yicha 1 gektariga bo‘lgan xarajatlarni ularning jami ekin maydoniga ko‘paytirish yo‘li bilan quyidagi formula yordamida aniqlanadi: bu yerda, – dehqonchilikda tugallanmagan ishlab chiqarish qiymati; kelgusi yil hosili uchun joriy yilning kuzida ekilgan kuzgi ekinlarning 1 gektariga bo‘lgan xarajatlar; ‒ kelgusi yil hosili uchun joriy yilning kuzida ekilgan kuzgi ekinlarning umumiy maydoni."},
  {number:22, code:"BAND_22", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 2. IFUT-2, A seksiyaning 01 bo‘limi bo‘yicha dehqonchilik va chorvachilik, ovchilik mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"Hisoblashda oldin asosiy turdagi dehqonchilik va chorvachilik mahsulotlarining qiymatlari aniqlanadi, keyin ularga yuqorida 13 va 15-bandlardagi formula bo‘yich", text:"Hisoblashda oldin asosiy turdagi dehqonchilik va chorvachilik mahsulotlarining qiymatlari aniqlanadi, keyin ularga yuqorida 13 va 15-bandlardagi formula bo‘yicha hisoblangan boshqa turdagi mahsulotlar qiymatlari qo‘shiladi."},
  {number:23, code:"BAND_23", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 2. IFUT-2, A seksiyaning 01 bo‘limi bo‘yicha dehqonchilik va chorvachilik, ovchilik mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"Dehqonchilik va chorvachilik sohasida ko‘rsatilgan xizmatlar qiymatlarini hisoblash quyidagi formula bo‘yicha amalga oshiriladi: bu yerda, ‒ dehqonchilik va cho", text:"Dehqonchilik va chorvachilik sohasida ko‘rsatilgan xizmatlar qiymatlarini hisoblash quyidagi formula bo‘yicha amalga oshiriladi: bu yerda, ‒ dehqonchilik va chorvachilik sohasidagi xizmatlar qiymatlari; bozor xizmati qiymatlari; davlat bujeti mablag‘laridan moliyalashtiriladigan nobozor xizmat qiymatlari."},
  {number:24, code:"BAND_24", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 2. IFUT-2, A seksiyaning 01 bo‘limi bo‘yicha dehqonchilik va chorvachilik, ovchilik mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"Shunday qilib, dehqonchilik va chorvachilik mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblashni quyidagi formula bilan ifodalalash mumkin: bu yerda, ‒ d", text:"Shunday qilib, dehqonchilik va chorvachilik mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblashni quyidagi formula bilan ifodalalash mumkin: bu yerda, ‒ dehqonchilik va chorvachilik mahsulot (xizmat)lari yalpi ishlab chiqarishi; ‒ dehqonchilik mahsulotlari qiymati; ‒ dehqonchilikda tugallanmagan ishlab chiqarish qiymatlari; ‒ chorvachilik mahsulotlari qiymati; ‒ dehqonchilik va chorvachilik sohasidagi xizmatlar qiymati."},
  {number:25, code:"BAND_25", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 2. IFUT-2, A seksiyaning 01 bo‘limi bo‘yicha dehqonchilik va chorvachilik, ovchilik mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"Ov xo‘jaligida yetishtirilgan mahsulot (xizmat)lar qiymati ov natijasida olingan yovvoyi va yirtqich hayvonlar qiymatlarini, yovvoyi hayvonlarni muhofaza qilish", text:"Ov xo‘jaligida yetishtirilgan mahsulot (xizmat)lar qiymati ov natijasida olingan yovvoyi va yirtqich hayvonlar qiymatlarini, yovvoyi hayvonlarni muhofaza qilish, ularning sonini hisobga olish va joylashtirish, ovchilikni tashkil etish va ov iqtisodiy kuzatuvlari, ovchilik hamda yovvoyi hayvonlar va yirtqich hayvonlarni ovlash va ko‘paytirish sohasida ko‘rsatilgan xizmatlar qiymatlari kabi ovchilik xo‘jaligini yuritish xarajatlarini o‘z ichiga oladi."},
  {number:26, code:"BAND_26", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 2. IFUT-2, A seksiyaning 01 bo‘limi bo‘yicha dehqonchilik va chorvachilik, ovchilik mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"A seksiya 01 bo‘lim bo‘yicha, dehqonchilik, chorvachilik va ovchilik sohasi mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda yakuniy hisoblashni ", text:"A seksiya 01 bo‘lim bo‘yicha, dehqonchilik, chorvachilik va ovchilik sohasi mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda yakuniy hisoblashni quyidagi formula bilan ifodalash mumkin: bu yerda, A seksiya 01 bo‘lim, dehqonchilik, chorvachilik va ov sohasidagi mahsulot (xizmat)lari yalpi ishlab chiqarishi; ‒ dehqonchilik va chorvachilik mahsulot (xizmat)lari yalpi ishlab chiqarishi; ov xo‘jaligida yetishtirilgan mahsulot (xizmat)lari qiymati."},
  {number:27, code:"BAND_27", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 3. IFUT-2, A seksiyasining 02 bo‘limi bo‘yicha o‘rmonchilik va yog‘och tayyorlash sohasida mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"O‘rmonchilik va yog‘och tayyorlash sohasida yetishtirilgan mahsulot (xizmat)lar qiymati, asosiy foydalanish uchun kesish paytida tayyorlangan o‘tinlar va o‘rmon", text:"O‘rmonchilik va yog‘och tayyorlash sohasida yetishtirilgan mahsulot (xizmat)lar qiymati, asosiy foydalanish uchun kesish paytida tayyorlangan o‘tinlar va o‘rmonlarni parvarish qilish, kesish, o‘rmon daraxtlarini rekonstruksiya qilish va tanlanma sanitariya kesish, o‘rmonlarni o‘stirish, o‘rmonlarni qayta tiklash va o‘rmon xo‘jaligini yuritish xarajatlari, o‘rmonchilik va yog‘och tayyorlash bilan bog‘liq ko‘rsatilgan texnik xizmatlarning joriy narxlardagi qiymatlarini o‘z ichiga oladi."},
  {number:28, code:"BAND_28", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 3. IFUT-2, A seksiyasining 02 bo‘limi bo‘yicha o‘rmonchilik va yog‘och tayyorlash sohasida mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"O‘rmonchilik va yog‘och tayyorlash sohasida yetishtirilgan mahsulot (xizmatlar)lar qiymatlariga davlat budjetini bajarish to‘g‘risidagi hisobot ma’lumotlari bo‘", text:"O‘rmonchilik va yog‘och tayyorlash sohasida yetishtirilgan mahsulot (xizmatlar)lar qiymatlariga davlat budjetini bajarish to‘g‘risidagi hisobot ma’lumotlari bo‘yicha hisoblangan nobozor xizmatlari hajmi ham qo‘shiladi."},
  {number:29, code:"BAND_29", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 4. IFUT-2, A seksiyaning 03 bo‘limi bo‘yicha baliq ovlash va akvakultura sohasida mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash", title:"Baliq ovlash va akvakultura sohasida yetishtirilgan mahsulot (xizmat)lar qiymati ovlangan baliqlar, olingan dengiz mahsulotlari qiymatlarini, dengiz va daryo or", text:"Baliq ovlash va akvakultura sohasida yetishtirilgan mahsulot (xizmat)lar qiymati ovlangan baliqlar, olingan dengiz mahsulotlari qiymatlarini, dengiz va daryo organizmlarini va o‘simliklarini ko‘paytirish xarajatlarini, shuningdek, baliq ovlash va baliqchilik bilan bog‘liq bo‘lgan xizmatlarning joriy narxlardagi qiymatlarini o‘z ichiga oladi."},
  {number:30, code:"BAND_30", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 5. A seksiya bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda yakuniy hisoblash", title:"A seksiya bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda yakuniy hisoblashni quyidagi formula", text:"A seksiya bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda yakuniy hisoblashni quyidagi formula bilan ifodalash mumkin: bu yerda, ‒ qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishi; A seksiyaning 01 bo‘limi, dehqonchilik, chorvachilik va ov sohasidagi mahsulot (xizmat)lar yalpi ishlab chiqarishi; A seksiyaning 02 bo‘limi, o‘rmonchilik va yog‘och tayyorlash sohasidagi mahsulot (xizmat)lar yalpi ishlab chiqarishi; A seksiyaning 03 bo‘limi, baliq ovlash va akvakultura sohasidagi mahsulot (xizmat)lar yalpi ishlab chiqarishi."},
  {number:31, code:"BAND_31", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 5. A seksiya bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda yakuniy hisoblash", title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash sxemasi Uslubiy nizomning 2-ilovasida ko‘rsat", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash sxemasi Uslubiy nizomning 2-ilovasida ko‘rsatilgan."},
  {number:32, code:"BAND_32", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Joriy narxlarda baholash qishloq, o‘rmon va baliqchilik xo‘jaligi sohasida yetishtirilgan mahsulotlar fizik hajmining o‘zgarishini to‘g‘ridan to‘g‘ri baholashga", text:"Joriy narxlarda baholash qishloq, o‘rmon va baliqchilik xo‘jaligi sohasida yetishtirilgan mahsulotlar fizik hajmining o‘zgarishini to‘g‘ridan to‘g‘ri baholashga imkon bermaydi."},
  {number:33, code:"BAND_33", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Shu maqsadda, qishloq, o‘rmon va baliqchilik xo‘jaligi sohasida yetishtirilgan mahsulotlar hajmini taqqoslama narxlarda baholash amalga oshiriladi", text:"Shu maqsadda, qishloq, o‘rmon va baliqchilik xo‘jaligi sohasida yetishtirilgan mahsulotlar hajmini taqqoslama narxlarda baholash amalga oshiriladi."},
  {number:34, code:"BAND_34", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Taqqoslama narxlarda komponentlarni baholashning asosiy usuli to‘g‘ridan-to‘g‘ri qayta baholash usuli hisoblanadi", text:"Taqqoslama narxlarda komponentlarni baholashning asosiy usuli to‘g‘ridan-to‘g‘ri qayta baholash usuli hisoblanadi. Ko‘rsatkichlarni taqqoslama narxlarda to‘g‘ridan to‘g‘ri qayta baholash usulida, qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishi, mahsulot turlari va har bir ishlab chiqaruvchilar toifasi bo‘yicha alohida, hisobot davrida yetishtirilgan mahsulotlar hajmini mos ravishda o‘tgan yil narxlariga ko‘paytirish yo‘li bilan quyidagi formuladan foydalangan holda hisoblanadi: bu yerda, yetishtirilgan i-turdagi mahsulotning taqqoslama narxlardagi qiymati; ‒ hisobot davrida yetishtirilgan i-turdagi mahsulotning fizik hajmi; ‒ i-turdagi mahsulotning o‘tgan yilning hisobot davridagi o‘rtacha sotish narxi, ya’ni taqqoslama narx. Masalan, hisobot davrida yil boshidan 100 tonna don ekinlari yetishtirilgan, uning 1 tonnasi uchun o‘rtacha taqqoslama narxlardagi sotish narxi 150 ming so‘mni tashkil qiladi: = 100 /1000000 = 15 mln. so‘m. Demak, hisoblash yakuniga ko‘ra, don ekinlarining taqqoslama narxlardagi qiymati baholashga ko‘ra 15 mln. so‘mni tashkil qiladi."},
  {number:35, code:"BAND_35", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Boshqa dehqonchilik va chorvachilik mahsulotlarining qiymatlari ham shu kabi hisoblanadi va uning har bir turi bo‘yicha olingan ma’lumotlar jami dehqonchilik va", text:"Boshqa dehqonchilik va chorvachilik mahsulotlarining qiymatlari ham shu kabi hisoblanadi va uning har bir turi bo‘yicha olingan ma’lumotlar jami dehqonchilik va chorvachilik mahsulotlarining qiymati sifatida jamlanadi."},
  {number:36, code:"BAND_36", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Shunday qilib, jami dehqonchilik va chorvachilik mahsulotlarining qiymatini hisoblashni quyidagi formula bilan ifodalash mumkin: bu yerda, ‒ yetishtirilgan dehq", text:"Shunday qilib, jami dehqonchilik va chorvachilik mahsulotlarining qiymatini hisoblashni quyidagi formula bilan ifodalash mumkin: bu yerda, ‒ yetishtirilgan dehqonchilik va chorvachilik mahsulotlarining taqqoslama narxlardagi qiymati; ‒ hisobot davrida yetishtirilgan i-turdagi mahsulotning fizik hajmi; ‒ i-turdagi mahsulotning o‘tgan yilning hisobot davridagi o‘rtacha sotish narxi, ya’ni taqqoslama narx."},
  {number:37, code:"BAND_37", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Qishloq xo‘jaligi mahsulotlarining fizik hajmi indeksi (FHI) hisobot davridagi mahsulotlar hajmining o‘tgan yilning mos davriga nisbatan taqqoslama narxlardagi ", text:"Qishloq xo‘jaligi mahsulotlarining fizik hajmi indeksi (FHI) hisobot davridagi mahsulotlar hajmining o‘tgan yilning mos davriga nisbatan taqqoslama narxlardagi o‘zgarishi sur’atini o‘zida ifodalaydi. Fizik hajm indeksi (FHI) sohada taqqoslanayotgan davrlarda ishlab chiqarish hajmining o‘zgarishini tavsiflovchi nisbiy ko‘rsatkich hisoblanadi. U mahsulotlarning fizik hajmi dinamikasini tahlil qilishda foydalaniladi."},
  {number:38, code:"BAND_38", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Taqqoslama narx sifatida o‘tgan yilning mos davridagi joriy narxlar qabul qilinadi", text:"Taqqoslama narx sifatida o‘tgan yilning mos davridagi joriy narxlar qabul qilinadi. Fizik hajm indeksini tuzishdan asosiy maqsad, mahsulot yetishtirish darajasidagi nisbiy o‘zgarishlarni obyektiv aks ettiradigan umumiy indeksni ishlab chiqishdan iborat. Bunday umumiy indeks Paashe indeksi hisoblanadi. bu yerda, mahsulot yetishtirish fizik hajmi indeksi; –hisobot davridagi mahsulot yetishtirish fizik hajmi; bazis davrdagi mahsulot yetishtirish fizik hajmi; bazis davrdagi narx."},
  {number:39, code:"BAND_39", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Har bir mahsulot turi bo‘yicha fizik hajm individual indeksi va dehqonchilik, chorvachilik va butun qishloq xo‘jaligi bo‘yicha umumiy indeks hisoblanadi", text:"Har bir mahsulot turi bo‘yicha fizik hajm individual indeksi va dehqonchilik, chorvachilik va butun qishloq xo‘jaligi bo‘yicha umumiy indeks hisoblanadi."},
  {number:40, code:"BAND_40", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Fizik hajm individual indeksini hisoblash uchun hisobot davrida yetishtirilgan har bir turdagi mahsulotlar taqqoslama narxlarda baholanadi", text:"Fizik hajm individual indeksini hisoblash uchun hisobot davrida yetishtirilgan har bir turdagi mahsulotlar taqqoslama narxlarda baholanadi."},
  {number:41, code:"BAND_41", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Fizik hajm umumiy indeksini hisoblash uchun tegishli mahsulotlar qiymati jamlanadi", text:"Fizik hajm umumiy indeksini hisoblash uchun tegishli mahsulotlar qiymati jamlanadi. Joriy davrda olingan qiymat agregati (jamlanma qiymat) bazis davr qiymat agregatiga bo‘linadi va 100 ga ko‘paytiriladi."},
  {number:42, code:"BAND_42", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Yetishtirilgan boshqa turdagi mahsulotlar hajmlari to‘g‘risidagi ma’lumotlar mavjud bo‘lmagan boshqa turdagi mahsulotlar qiymatini taqqoslama narxlarda qayta hi", text:"Yetishtirilgan boshqa turdagi mahsulotlar hajmlari to‘g‘risidagi ma’lumotlar mavjud bo‘lmagan boshqa turdagi mahsulotlar qiymatini taqqoslama narxlarda qayta hisoblashda, har-bir asosiy turdagi dehqonchilik va chorvachilik mahsulotlari bo‘yicha alohida hisoblangan fizik hajmi o‘zgarishining xuddi shunday indeksi qo‘llaniladi."},
  {number:43, code:"BAND_43", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Dehqonchilikda tugallanmagan ishlab chiqarish qiymatlarining taqqoslama narxlardagi qiymatining o‘zgarishi o‘tgan yilda ko‘rsatilgan qishloq xo‘jaligi ishlab ch", text:"Dehqonchilikda tugallanmagan ishlab chiqarish qiymatlarining taqqoslama narxlardagi qiymatining o‘zgarishi o‘tgan yilda ko‘rsatilgan qishloq xo‘jaligi ishlab chiqaruvchilarining ekin maydonlariga va mahsulotlar birligiga bo‘lgan joriy xarajatlarning o‘rtacha darajasidan kelib chiqqan holda aniqlanadi."},
  {number:44, code:"BAND_44", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Qishloq xo‘jaligi sohasidagi xizmatlar va ov xo‘jaligi mahsulot (xizmat)larining taqqoslama narxlardagi yillik qiymatini baholash bazis davrdagi ma’lumotlarni b", text:"Qishloq xo‘jaligi sohasidagi xizmatlar va ov xo‘jaligi mahsulot (xizmat)larining taqqoslama narxlardagi yillik qiymatini baholash bazis davrdagi ma’lumotlarni bandlar sonining o‘zgarishi indeksi orqali ekstrapolyatsiya qilish yo‘li bilan amalga oshiriladi. Choraklik qayta hisoblashda taqqoslama narxlarning ekstrapolyatori sifatida yuzaga kelgan dehqonchilik va chorvachilik mahsulotlarining fizik hajmi indeksi qo‘llaniladi."},
  {number:45, code:"BAND_45", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"O‘rmonchilik va yog‘och tayyorlash sohasida yetishtirilgan mahsulot (xizmat)lar qiymatini taqqoslama narxlarda yillik qayta hisoblashda o‘rmon daraxtlari maydon", text:"O‘rmonchilik va yog‘och tayyorlash sohasida yetishtirilgan mahsulot (xizmat)lar qiymatini taqqoslama narxlarda yillik qayta hisoblashda o‘rmon daraxtlari maydonining o‘zgarishi indeksi bo‘yicha ekstrapolyatsiya usulidan foydalaniladi. Taqqoslama narxlarda choraklik baholashda tayanch (bazis) davridagi hajmlarni bandlar sonining o‘zgarishi indeksi orqali ekstrapolyatsiya qilish yo‘li bilan amalga oshiriladi."},
  {number:46, code:"BAND_46", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Baliq ovlash va akvakultura sohasida yetishtirilgan mahsulot (xizmat)lar qiymatini taqqoslama narxlarda yillik va choraklik qayta baholash baliq ovlash hajminin", text:"Baliq ovlash va akvakultura sohasida yetishtirilgan mahsulot (xizmat)lar qiymatini taqqoslama narxlarda yillik va choraklik qayta baholash baliq ovlash hajmining fizik indeksi bo‘yicha ekstrapolyatsiya qilish yo‘li bilan amalga oshiriladi."},
  {number:47, code:"BAND_47", chapter:2, chapter_title:"IFUT-2, A seksiyasi bo‘yicha YaICh ni yil boshidan o‘sib boruvchi yakunda hisoblash", section:"§ 6. IFUT-2, A seksiyasi bo‘yicha qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash, fizik hajm indeksini aniqlash", title:"Uslubiy nizomning 3-ilovasida qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash sxemasi ke", text:"Uslubiy nizomning 3-ilovasida qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash sxemasi keltirilgan."},
  {number:48, code:"BAND_48", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini choraklik hisoblash, hisobot davrida sohadagi joriy holatni dastlabki b", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini choraklik hisoblash, hisobot davrida sohadagi joriy holatni dastlabki baholash maqsadida ishlab chiqiladi. Hisobot yili davomida har chorakda dastlab ovchilik va ushbu sohalarda ko‘rsatilgan xizmatlarsiz 01 bo‘lim bo‘yicha dehqonchilik va chorvachilik mahsulot (xizmat)lari yalpi ishlab chiqarishi hisoblanadi. Shundan so‘ng, dehqonchilik va chorvachilik mahsulot (xizmat)lari yalpi ishlab chiqarishiga mos ravishda ovchilik xo‘jaligi, 02 va 03 - o‘rmonchilik va yog‘och tayyorlash, baliq ovlash va akvakultura bo‘limlarlari mahsulot (xizmat)lari yalpi ishlab chiqarishi hajmlari bo‘yicha hisoblangan (baholangan) ma’lumotlar qo‘shiladi."},
  {number:49, code:"BAND_49", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Yillik hisoblashlar asosiy hisoblashlar bo‘lib, unda mavsumiylik omillari yumshatiladi va ishlab chiqarish ko‘rsatkichlarining eng yuqori barqarorligiga erishil", text:"Yillik hisoblashlar asosiy hisoblashlar bo‘lib, unda mavsumiylik omillari yumshatiladi va ishlab chiqarish ko‘rsatkichlarining eng yuqori barqarorligiga erishiladi."},
  {number:50, code:"BAND_50", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Yil yakuni bo‘yicha yillik yakuniy statistik kuzatuvlar ma’lumotlariga asoslanib, to‘liq A seksiya bo‘yicha yakuniy yalpi ishlab chiqarish aniqlanadi", text:"Yil yakuni bo‘yicha yillik yakuniy statistik kuzatuvlar ma’lumotlariga asoslanib, to‘liq A seksiya bo‘yicha yakuniy yalpi ishlab chiqarish aniqlanadi. Yillik yakuniy hisoblashlar yakunlanganidan so‘ng unga asosan choraklik hisoblashlarga aniqlik kiritiladi va qayta hisoblanadi."},
  {number:51, code:"BAND_51", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Yilning birinchi choragida dehqonchilik sohasi bo‘yicha hisoblash (baholash) asosan yopiq yerlardagi tayyor mahsulotlar, bundan tashqari kam miqdorda ochiq yerl", text:"Yilning birinchi choragida dehqonchilik sohasi bo‘yicha hisoblash (baholash) asosan yopiq yerlardagi tayyor mahsulotlar, bundan tashqari kam miqdorda ochiq yerlardagi sabzavot ekinlari, kartoshka, mevalar va rezavorlar bo‘yicha amalga oshiriladi, dehqonchilik bo‘yicha qolgan ko‘rsatkichlar mazkur chorakda tugallanmagan ishlab chiqarish hisoblanadi."},
  {number:52, code:"BAND_52", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Hisobot yilining ikkinchi choragidan qishloq xo‘jaligi ekinlari, mevalar, rezavorlar, uzum va boshqalarning erta pishar turlari va navlari hosilini yig‘ib olish", text:"Hisobot yilining ikkinchi choragidan qishloq xo‘jaligi ekinlari, mevalar, rezavorlar, uzum va boshqalarning erta pishar turlari va navlari hosilini yig‘ib olish boshlanadi. Lekin, bu davrda paxta xom-ashyosi, sholi va ayrim kechpishar qishloq xo‘jaligi ekinlari, mevalar, rezavorlar va uzum turlari va navlari tugallanmagan ishlab chiqarish hisoblanadi."},
  {number:53, code:"BAND_53", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Hisobot yilining uchinchi choragi aksariyat qishloq xo‘jaligi ekinlari, mevalar, rezavorlar, uzum va boshqalarning hosili yoppasiga yig‘ib olinadigan davr hisob", text:"Hisobot yilining uchinchi choragi aksariyat qishloq xo‘jaligi ekinlari, mevalar, rezavorlar, uzum va boshqalarning hosili yoppasiga yig‘ib olinadigan davr hisoblanadi. Lekin, bu holatda ham ayrim kechpishar qishloq xo‘jaligi ekinlari, mevalar, rezavorlar va uzum turlari va navlari tugallanmagan ishlab chiqarish hisoblanadi. Bu davrda kelgusi yil hosili uchun kuzgi ekinlarning ekilishi boshlanadi, ular ham joriy yil uchun tugallanmagan ishlab chiqarish hisoblanadi."},
  {number:54, code:"BAND_54", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Hisobot yilining to‘rtinchi choragi oxiriga borib, yopiq yerlardan tashqari, barcha qishloq xo‘jaligi ekinlari, mevalar, rezavorlar, uzumlar hosili to‘liq yig‘i", text:"Hisobot yilining to‘rtinchi choragi oxiriga borib, yopiq yerlardan tashqari, barcha qishloq xo‘jaligi ekinlari, mevalar, rezavorlar, uzumlar hosili to‘liq yig‘ib olinadi. Lekin, shuningdek, kelgusi yil hosili uchun bu davrda ekilgan kuzgi ekinlar joriy yil uchun tugallanmagan ishlab chiqarish hisoblanadi."},
  {number:55, code:"BAND_55", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Dehqonchilikda tugallanmagan ishlab chiqarishni choraklar bo‘yicha hisoblashda, o‘tgan yilning mos davrlaridagi tugallanmagan ishlab chiqarish qiymatining dehqo", text:"Dehqonchilikda tugallanmagan ishlab chiqarishni choraklar bo‘yicha hisoblashda, o‘tgan yilning mos davrlaridagi tugallanmagan ishlab chiqarish qiymatining dehqonchilik mahsulot (xizmat)lari yalpi ishlab chiqarishi umumiy qiymatiga nisbatan ulushidan foydalaniladi. Masalan, o‘tgan yilning birinchi choragida dehqonchilikda tugallanmagan ishlab chiqarish qiymatining dehqonchilik mahsulot (xizmat)lari yalpi ishlab chiqarishi umumiy qiymatiga nisbatan ulushi 1,4 % ni tashkil qiladi va bunda joriy hisoblashlar uchun 1,4 % lik koeffitsiyent qabul qilinadi. Bunday hisoblashlar har bir chorak bo‘yicha alohida amalga oshiriladi."},
  {number:56, code:"BAND_56", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Boshqa turdagi dehqonchilik va chorvachilik mahsulotlarini choraklik hisoblashda ularning har bir chorak bo‘yicha alohida yillik hisoblashdagi umumiy dehqonchil", text:"Boshqa turdagi dehqonchilik va chorvachilik mahsulotlarini choraklik hisoblashda ularning har bir chorak bo‘yicha alohida yillik hisoblashdagi umumiy dehqonchilik va chorvachilik mahsulot (xizmat)lari yalpi ishlab chiqarishi qiymatiga bo‘lgan o‘rtacha nisbatidan foydalaniladi. Hisoblash dehqonchilikda tugallanmagan ishlab chiqarish qiymatlarini hisobga olgan holda, ishlab chiqarilgan dehqonchilik va chorvachilik mahsulotlari qiymatlari aniqlanganidan keyin ushbu formula bo‘yicha amalga oshiriladi: bu yerda, i-turdagi boshqa mahsulotning hisobot davridagi qiymati; – yillik hisoblashdagi i-turdagi boshqa mahsulot qiymatining yetishtirilgan dehqonchilik va chorvachilik mahsulotlarining umumiy hajmi qiymatidagi o‘rtacha ulushi (%); – joriy yilning hisobot davrida yetishtirilgan dehqonchilik va chorvachilik mahsulotlarining joriy narxlardagi qiymati. Shuningdek, shu yo‘l bilan va yuqorida keltirilgan formuladan foydalanib, har chorakda dehqonchilik va chorvachilik sohasida ko‘rsatilgan xizmatlar qiymatlari ham hisoblanadi."},
  {number:57, code:"BAND_57", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Yetishtirilgan pilla hajmlari va qiymatlarini shakllantirishda tegishli statistika kuzatuvi ma’lumotlaridan foydalaniladi (7-bob)", text:"Yetishtirilgan pilla hajmlari va qiymatlarini shakllantirishda tegishli statistika kuzatuvi ma’lumotlaridan foydalaniladi (7-bob)."},
  {number:58, code:"BAND_58", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Yetishtirilgan don ekinlari hajmlari va qiymatlarini shakllantirish bo‘yicha axborot manbalari bo‘lib, tegishli statistika kuzatuvi ma’lumotlari xizmat qiladi (", text:"Yetishtirilgan don ekinlari hajmlari va qiymatlarini shakllantirish bo‘yicha axborot manbalari bo‘lib, tegishli statistika kuzatuvi ma’lumotlari xizmat qiladi (7-bob). Yetishtirilgan don ekinlarining qiymatini hisoblashda ishlab chiqaruvchilar narxlaridan foydalaniladi. Hisoblashlar tayyorlangan va yetishtirilgan don ekinlari hajmlari bo‘yicha alohida amalga oshiriladi."},
  {number:59, code:"BAND_59", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Yetishtirilgan paxta xomashyosi hajmlari va qiymatlarini shakllantirish bo‘yicha axborotlar manbai bo‘lib, tegishli statistika kuzatuvi ma’lumotlari hisoblanadi", text:"Yetishtirilgan paxta xomashyosi hajmlari va qiymatlarini shakllantirish bo‘yicha axborotlar manbai bo‘lib, tegishli statistika kuzatuvi ma’lumotlari hisoblanadi (7-bob)."},
  {number:60, code:"BAND_60", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Boshqa hollarda yetishtirilgan mahsulotlar qiymati 5bozor narxlari blankasi “Dehqon bozorlarida narxlarni ro‘yxatga olish blankasi” statistik so‘rovnoma shakli ", text:"Boshqa hollarda yetishtirilgan mahsulotlar qiymati 5bozor narxlari blankasi “Dehqon bozorlarida narxlarni ro‘yxatga olish blankasi” statistik so‘rovnoma shakli ma’lumotlari asosida shakllantiriladi (7-bob)."},
  {number:61, code:"BAND_61", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Choraklik kuzatuvlarda don, texnik, sabzavot, poliz ekinlari, mevalar, rezavorlar, go‘sht tirik vaznda va boshqa mahsulotlarning turlari bo‘yicha ko‘rsatkichlar", text:"Choraklik kuzatuvlarda don, texnik, sabzavot, poliz ekinlari, mevalar, rezavorlar, go‘sht tirik vaznda va boshqa mahsulotlarning turlari bo‘yicha ko‘rsatkichlar mavjud emas. Bunday hollarda, yillik hisoblashdagi ushbu mahsulotlarning turlari bo‘yicha ularning umumiy hajmiga nisbatan ulushidan choraklik hisoblashlarda foydalaniladi. Sabzavot ekinlari misolida hisoblash mazkur nizomning 5-ilovasida keltirilgan."},
  {number:62, code:"BAND_62", chapter:3, chapter_title:"Choraklik va yillik hisoblashlarning o‘ziga xosligi", section:null, title:"Hisoblashda, ularning hajmlaridan foydalaniladigan ayrim ko‘rsatkichlar qishloq xo‘jaligi bo‘yicha statistika hisobotlarida o‘z aksini topmagan", text:"Hisoblashda, ularning hajmlaridan foydalaniladigan ayrim ko‘rsatkichlar qishloq xo‘jaligi bo‘yicha statistika hisobotlarida o‘z aksini topmagan. Masalan, pilla qurtini oziqlantirish uchun tut bargi, qishloq xo‘jaligi hayvonlari va parrandalaridan go‘ng va axlat, pat, par, asalari mumi, gul changi, ona asalari suti, propolis, asalari zahari va boshqalar chiqimi. Hisoblashlar uchun ularning taxminiy me’yoriy chiqimlari 6-ilovada keltirilgan."},
  {number:63, code:"BAND_63", chapter:4, chapter_title:"Ishlab chiqarishning mavsumiyligi", section:null, title:"Tabiiy omillar ‒ iqtisodiy jarayonlarning mavsumiy davrlari shakllanishida muhim omillardan biri hisoblanadi", text:"Tabiiy omillar ‒ iqtisodiy jarayonlarning mavsumiy davrlari shakllanishida muhim omillardan biri hisoblanadi. Mavsumiy dinamikani shakllantirishda ob-havo omilining tutgan o‘rni biologik maromlarga bog‘liq."},
  {number:64, code:"BAND_64", chapter:4, chapter_title:"Ishlab chiqarishning mavsumiyligi", section:null, title:"Iqlim sharoitining mavsumiy almashinuvi ‒ mavsumiy tavsiflarning muhim sabablaridan biri hisoblanib, qishloq, o‘rmon va baliqchilik xo‘jaligida sodir bo‘ladigan", text:"Iqlim sharoitining mavsumiy almashinuvi ‒ mavsumiy tavsiflarning muhim sabablaridan biri hisoblanib, qishloq, o‘rmon va baliqchilik xo‘jaligida sodir bo‘ladigan har qanday o‘zgarishlar muqarrar ravishda iqtisodiyotning boshqa tarmoqlarida tegishli o‘zgarishlarga olib keladi."},
  {number:65, code:"BAND_65", chapter:4, chapter_title:"Ishlab chiqarishning mavsumiyligi", section:null, title:"Ishlab chiqarishning mavsumiyligi iqtisodiyotning ko‘plab tarmoqlariga xosdir, ammo agrar sektorda to‘la quvvat bilan namoyon bo‘ladi va shuning uchun u iqtisod", text:"Ishlab chiqarishning mavsumiyligi iqtisodiyotning ko‘plab tarmoqlariga xosdir, ammo agrar sektorda to‘la quvvat bilan namoyon bo‘ladi va shuning uchun u iqtisodiyotning aksariyat sohalaridagi mavsumiylikka sabab bo‘ladi."},
  {number:66, code:"BAND_66", chapter:4, chapter_title:"Ishlab chiqarishning mavsumiyligi", section:null, title:"Ishlab chiqarish, ishlar va xizmatlar dinamikasini aniqlashda mavsumiy omillarni hisobga olish iqtisodiy siyosatni amalga oshirish, iqtisodiy siklni tahlil qili", text:"Ishlab chiqarish, ishlar va xizmatlar dinamikasini aniqlashda mavsumiy omillarni hisobga olish iqtisodiy siyosatni amalga oshirish, iqtisodiy siklni tahlil qilish, modellashtirish uchun zarur, bunda qishloq xo‘jaligi statistikasi ma’lumotlari muhim vosita hisoblanadi."},
  {number:67, code:"BAND_67", chapter:4, chapter_title:"Ishlab chiqarishning mavsumiyligi", section:null, title:"Agrar sektorda ishlab chiqarishning mavsumiyligi yil davomida ishlab chiqarishning mavsum bilan bog‘liq bo‘lgan notekisligi, yilning ma’lum davrlarida ishlab ch", text:"Agrar sektorda ishlab chiqarishning mavsumiyligi yil davomida ishlab chiqarishning mavsum bilan bog‘liq bo‘lgan notekisligi, yilning ma’lum davrlarida ishlab chiqarishning o‘sishi, qisqarishi yoki to‘liq to‘xtashida ifodalanadi va quyidagi omillar ta’sirida yuzaga keladi: - ishlab chiqarish siklining uzoq davomiyligi; - mablag‘lar aylanmasining sekinlashuvi; - tugallanmagan ishlab chiqarish hajmlarining ko‘pligi; - qo‘yilma mablag‘larning uzoq muddatda qoplanishi; - sotishdan tushgan tushumning yil davomidagi notekisligi; - daromad va xarajatlar oqimining mos kelmasligi; - ishlab chiqarish davrining ish davri bilan mos kelmasligi; - yil davomida resurslardan notekis foydalanish; - ishlab chiqarishning tabiiy iqlim sharoitiga uzviy bog‘liqligi; - ishlab chiqarish siklining yil mavsumlariga bog‘liqligi; - ish davri va ishlab chiqarish davri o‘rtasidagi uzilish va boshqalar. Agrar ishlab chiqarishdagi mavsumiylik omillarini o‘rganish qishloq, o‘rmon va baliqchilik xo‘jaligida diskret asosda ishlab chiqilgan statistik ko‘rsatkichlarning mavsumiy yumshatilishini o‘tkazish uchun algoritmini tasvirlab berishdan iborat."},
  {number:68, code:"BAND_68", chapter:4, chapter_title:"Ishlab chiqarishning mavsumiyligi", section:null, title:"Agrar ishlab chiqarishdagi mavsumiylik omillarini o‘rganish qishloq, o‘rmon va baliqchilik xo‘jaligida diskret asosda ishlab chiqilgan statistik ko‘rsatkichlarn", text:"Agrar ishlab chiqarishdagi mavsumiylik omillarini o‘rganish qishloq, o‘rmon va baliqchilik xo‘jaligida diskret asosda ishlab chiqilgan statistik ko‘rsatkichlarning mavsumiy yumshatilishini o‘tkazish uchun algoritmini tasvirlab berishdan iborat. [Izoh: manba hujjatda ushbu band raqamsiz berilgan]"},
  {number:69, code:"BAND_69", chapter:5, chapter_title:"YaICh ni diskret choraklar asosida hisoblash", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini yil boshidan o‘sib boruvchi yakunda hisoblashdan tashqari, ularni diskr", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini yil boshidan o‘sib boruvchi yakunda hisoblashdan tashqari, ularni diskret choraklar asosida hisoblash ham amalga oshiriladi."},
  {number:70, code:"BAND_70", chapter:5, chapter_title:"YaICh ni diskret choraklar asosida hisoblash", section:null, title:"Diskret choraklar asosida hisoblash natijasida olingan ma’lumotlar choraklar bo‘yicha dinamik qatordagi har bir chorakni o‘tgan chorak, o‘tgan yilning mos chora", text:"Diskret choraklar asosida hisoblash natijasida olingan ma’lumotlar choraklar bo‘yicha dinamik qatordagi har bir chorakni o‘tgan chorak, o‘tgan yilning mos choragi va har qanday boshqa chorak bilan taqqoslash imkonini beradi."},
  {number:71, code:"BAND_71", chapter:5, chapter_title:"YaICh ni diskret choraklar asosida hisoblash", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini diskret yoki sof choraklar asosida hisoblashda I chorak yanvar-mart, II", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini diskret yoki sof choraklar asosida hisoblashda I chorak yanvar-mart, II aprel-iyun, III iyul-sentabr va IV oktabr-dekabr oylarini qamrab oladi. I chorak yoki yanvar-mart uchun davr yil boshidan o‘sib boruvchi va diskret chorak hisoblanadi."},
  {number:72, code:"BAND_72", chapter:5, chapter_title:"YaICh ni diskret choraklar asosida hisoblash", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini diskret choraklar asosida hisoblash prinsiplari yil boshidan o‘sib boru", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini diskret choraklar asosida hisoblash prinsiplari yil boshidan o‘sib boruvchi yakunda hisoblash usulidan deyarli farq qilmaydi."},
  {number:73, code:"BAND_73", chapter:5, chapter_title:"YaICh ni diskret choraklar asosida hisoblash", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini diskret choraklar asosida hisoblash uchun barcha birlamchi axborotlar d", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini diskret choraklar asosida hisoblash uchun barcha birlamchi axborotlar diskret, ya’ni sof choraklar bo‘yicha shakllantiriladi (1, 2, 3, 4 va 7-ilovalar). Masalan, viloyat bo‘yicha yanvar-mart oylarida yoki I chorakda tirik vaznda 100 tonna, aprel-iyun yoki II chorakda 130 tonna, iyul-sentabr yoki III chorakda 150 tonna, oktabr-dekabr yoki IV chorakda 120 tonna go‘sht yetishtirilgan. Bunda yil davomida, ya’ni yanvar-dekabr oylari uchun go‘sht yetishtirish hajmi diskret choraklar yig‘indisi sifatida hisoblanadi yoki yil davomida tirik vaznda 500 tonna go‘sht yetishtirilgan deb qabul qilinadi (7-ilova)."},
  {number:74, code:"BAND_74", chapter:5, chapter_title:"YaICh ni diskret choraklar asosida hisoblash", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblash diskret choraklar asosida va yillik asosda yil boshidan o‘sib", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblash diskret choraklar asosida va yillik asosda yil boshidan o‘sib boruvchi yakunda joriy va taqqoslama narxlarda amalga oshiriladi (2 va 3-ilovalar)."},
  {number:75, code:"BAND_75", chapter:5, chapter_title:"YaICh ni diskret choraklar asosida hisoblash", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblashda ko‘rib chiqilayotgan davrdagi diskret chora", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblashda ko‘rib chiqilayotgan davrdagi diskret choraklar bo‘yicha amaldagi narxlardan foydalaniladi."},
  {number:76, code:"BAND_76", chapter:5, chapter_title:"YaICh ni diskret choraklar asosida hisoblash", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblashda ko‘rib chiqilayotgan davrdagi diskret ", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblashda ko‘rib chiqilayotgan davrdagi diskret choraklar bo‘yicha o‘tgan yilning amaldagi narxlaridan foydalaniladi."},
  {number:77, code:"BAND_77", chapter:5, chapter_title:"YaICh ni diskret choraklar asosida hisoblash", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini diskret choraklar asosida hisoblashda axborotlar manbai bo‘lib, 7-bobda", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini diskret choraklar asosida hisoblashda axborotlar manbai bo‘lib, 7-bobda keltirilgan manbalar xizmat qiladi."},
  {number:78, code:"BAND_78", chapter:6, chapter_title:"Choraklik hajm va indekslarga tuzatishlar kiritish", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulotlarini ishlab chiqarish ko‘rsatkichlari oqimli ko‘rsatkichlar qatoriga kiradi", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulotlarini ishlab chiqarish ko‘rsatkichlari oqimli ko‘rsatkichlar qatoriga kiradi. Bunday yuqori chastotali ko‘rsatkichlarning dinamikasi kalendar va mavsumiy omillar ta’siriga uchragan bo‘ladi. Iqtisodiy dinamikalarning o‘zgarishlarini standart usullarga muvofiq tahlil qilishda kalendar va mavsumiy tebranishlarga axborotga ega bo‘lmagan ko‘rsatkichlar sifatida qaraladi va ular tahlil qilinadigan vaqtinchalik qatorlardan olib tashlanishi zarur. Shu maqsadda vaqtinchalik qatorlarga kalendar va mavsumiy tuzatishlar kiritish qabul qilingan."},
  {number:79, code:"BAND_79", chapter:6, chapter_title:"Choraklik hajm va indekslarga tuzatishlar kiritish", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulotlarining choraklik hajmlari va indekslari hisob kitoblariga tuzatishlar kiritish hisobot yili uchun yakuniy his", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulotlarining choraklik hajmlari va indekslari hisob kitoblariga tuzatishlar kiritish hisobot yili uchun yakuniy hisob-kitoblari olinganidan so‘ng amalga oshiriladi."},
  {number:80, code:"BAND_80", chapter:7, chapter_title:"Axborot ta’minoti", section:null, title:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblashda zarur bo‘ladigan axborotlar manbalari bo‘lib quyidagi stati", text:"Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini hisoblashda zarur bo‘ladigan axborotlar manbalari bo‘lib quyidagi statistika kuzatuvlari shakllari ma’lumotlari xizmat qiladi (quyidagi statistika hisobotlari va kuzatuvlarining abbreviaturasi yoki nomi o‘zgargan taqdirda, ushbu statistika hisobotlari va kuzatuvlari asosida shakllantiriladi): - 4 fx shakli “Fermer xo‘jaligi faoliyati to‘g‘risida hisobot”; - 4 dx shakli “Dehqon va tomorqa xo‘jaliklari faoliyati to‘g‘risida hisobot”; - 4 qx (tashkilot) shakli “Qishloq xo‘jaligi faoliyati to‘g‘risida hisobot”; - 3 pilla shakli “Pilla xaridi to‘g‘risida hisobot”; - 3 don shakli “Don ekinlarini tayyorlash to‘g‘risida hisobot”; - 3 paxta shakli “Paxta xomashyosini tayyorlash to‘g‘risida hisobot”; - 1 fx shakli “Fermer xo‘jaligi faoliyati to‘g‘risida hisobot”; - 1 qx (tashkilot) shakli “Qishloq xo‘jaligi faoliyati to‘g‘risida hisobot”; - 1 kb (qx) (1 kb shakliga ilova) shakli “Mikrofirma va kichik korxonaning qishloq xo‘jaligi faoliyati to‘g‘risida hisobot”; - 1 ox (ovchilik) shakli “Ovchilik xo‘jaligi faoliyati to‘g‘risida hisobot”; - 1 o‘x (o‘rmon) shakli “O‘rmon parvarishi ishlarini o‘tkazish to‘g‘risida hisobot”; - 5 bozor narxlari blankasi “Dehqon bozorlarida narxlarni ro‘yxatga olish blankasi”; - tarmoq boshqarmalarining tegishli ma’lumotlari; - ma’muriy manbalar ma’lumotlari, ya’ni, davlat budjetini bajarish to‘g‘risidagi hisobot ma’lumotlari, vazirlik va idoralar ma’lumotlari."},
  {number:81, code:"BAND_81", chapter:8, chapter_title:"Yakuniy qoidalar", section:null, title:"Mazkur uslubiy nizomni ishlab chiqishda, O‘zbekiston Respublikasining qishloq xo‘jaligi sohasidagi me’yoriy-huquqiy hujjatlaridan, BMTning Oziq-ovqat va qishloq", text:"Mazkur uslubiy nizomni ishlab chiqishda, O‘zbekiston Respublikasining qishloq xo‘jaligi sohasidagi me’yoriy-huquqiy hujjatlaridan, BMTning Oziq-ovqat va qishloq xo‘jaligi tashkiloti (FAO), Mustaqil Davlatlar Hamdo‘stligi Davlatlararo statistika qo‘mitasi (MDH statistika qo‘mitasi)ning metodologik tavsiyalaridan, shuningdek, MDH davlatlarining tajribalaridan foydalanilgan."},
  {number:82, code:"BAND_82", chapter:8, chapter_title:"Yakuniy qoidalar", section:null, title:"Mazkur uslubiy hujjatni ishlab chiqish, kelishish, tasdiqlash va amaliyotga joriy qilish bosqichlari “Statistik ma’lumotlarni taqdim etishning universal modeli”", text:"Mazkur uslubiy hujjatni ishlab chiqish, kelishish, tasdiqlash va amaliyotga joriy qilish bosqichlari “Statistik ma’lumotlarni taqdim etishning universal modeli” (GSIM – Generic Statistical Information Model) talablari asosida ishlab chiqilgan “Statistika sohasida tasniflar, metodologiyalar va kuzatuv shakllarini ishlab chiqish va tasdiqlash bo‘yicha namunaviy uslubiy qo‘llanma”ga muvofiq amalga oshirilgan. Qishloq xo‘jaligi mahsulotlarining fizik hajmini shakllantirish Izoh: 1. Qishloq xo‘jaligi mahsulotlari hajmi I (yanvar-mart), II (yanvar-iyun), III (yanvar-sentabr), IV (yanvar-dekabr) choraklar uchun alohida yil boshidan o‘sib boruvchi yakunda shakllantiriladi. 2. Qishloq xo‘jaligi mahsulotlari hajmi I (yanvar-mart), II (aprel-iyun), III (iyul-sentabr), IV (oktabr-dekabr) choraklar uchun alohida diskret choraklar asosida shakllantiriladi. Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini joriy narxlarda hisoblash sxemasi Izoh: 1. Hisoblash sxemasi fermer, dehqon va tomorqa xo‘jaliklari, qishloq xo‘jaligi faoliyatini amalga oshiruvchi tashkilotlar va barcha toifadagi xo‘jaliklar bo‘yicha I (yanvar-mart), II (yanvar-iyun), III (yanvar-sentabr), IV (yanvar-dekabr) choraklar uchun alohida yil boshidan o‘sib boruvchi yakunda shakllantiriladi. 2. Hisoblash sxemasi fermer, dehqon va tomorqa xo‘jaliklari, qishloq xo‘jaligi faoliyatini amalga oshiruvchi tashkilotlar va barcha toifadagi xo‘jaliklar bo‘yicha I (yanvar-mart), II (aprel-iyun), III (iyul-sentabr), IV (oktabr-dekabr) choraklar uchun alohida diskret choraklar asosida shakllantiriladi. Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishini taqqoslama narxlarda hisoblash sxemasi Izoh: 1. Hisoblash sxemasi fermer, dehqon va tomorqa xo‘jaliklari, qishloq xo‘jaligi faoliyatini amalga oshiruvchi tashkilotlar va barcha toifadagi xo‘jaliklar bo‘yicha I (yanvar-mart), II (yanvar-iyun), III (yanvar-sentabr), IV (yanvar-dekabr) choraklar uchun alohida yil boshidan o‘sib boruvchi yakunda shakllantiriladi. 2. Hisoblash sxemasi fermer, dehqon va tomorqa xo‘jaliklari, qishloq xo‘jaligi faoliyatini amalga oshiruvchi tashkilotlar va barcha toifadagi xo‘jaliklar bo‘yicha I (yanvar-mart), II (aprel-iyun), III (iyul-sentabr), IV (oktabr-dekabr) choraklar uchun alohida diskret choraklar asosida shakllantiriladi. Asosiy turdagi mahsulotlar guruhiga kiritilmagan boshqa turdagi qishloq xo‘jaligi mahsulotlari ro‘yxati Izoh: 1. Ro‘yxat fermer, dehqon va tomorqa xo‘jaliklari, qishloq xo‘jaligi faoliyatini amalga oshiruvchi tashkilotlar va barcha toifadagi xo‘jaliklar bo‘yicha I (yanvar-mart), II (yanvar-iyun), III (yanvar-sentabr), IV (yanvar-dekabr) choraklar uchun alohida yil boshidan o‘sib boruvchi yakunda shakllantiriladi. 2. Ro‘yxat fermer, dehqon va tomorqa xo‘jaliklari, qishloq xo‘jaligi faoliyatini amalga oshiruvchi tashkilotlar va barcha toifadagi xo‘jaliklar bo‘yicha I (yanvar-mart), II (aprel-iyun), III (iyul-sentabr), IV (oktabr-dekabr) choraklar uchun alohida diskret choraklar asosida shakllantiriladi. Sabzavot ekinlarining turlari bo‘yicha choraklik hajmlarini ularning yillik umumiy hajmiga nisbatan ulushi asosida choraklik hisoblash Misol shartli 1) Izoh: 1) jadval boshqa qishloq xo‘jaligi mahsulotlari bo‘yicha ham alohida tuziladi; 2) ulushi bo‘yicha koeffitsiyentlarga muvofiq mos ravishda hisoblangan ma’lumotlar; 3) statistika kuzatuvlari asosida olingan ma’lumotlar. Qishloq xo‘jaligi ekinlari, hayvonlari, parrandalari, asalarilar va boshqalardan foydalanishda chiqadigan qo‘shimcha mahsulotlarning taxminiy me’yorlari 6.1. Bitta hayvondan o‘rtacha chiqadigan go‘ngning taxminiy me’yorlari 6.2. Bitta asalari oilasidan o‘rtacha olinadigan qo‘shimcha mahsulotlarning taxminiy me’yorlari 6.3. Poxol va chori, boshoqli don ishlab chiqarish hajmidan 100 %. 6.4. G‘o‘zapoya, 1 gektar g‘o‘za ekilgan maydondan 10 - 15 tonna. 6.5. Tut bargi chiqimi ‒ ishlab chiqarilgan pilla miqdorini 20 koeffitsiyentiga ko‘paytirish yo‘li bilan hisoblanadi (pilla qurtini o‘stirishda 1 kg pilla uchun 20 kg tut bargi sarflanadi). 6.6. Pilla qurti tuxumi (grena) chiqimi ‒ 1 korobka hisobiga = 19 - 29 gr. Qishloq xo‘jaligi mahsulotlari va qiymatlarini Diskret choraklar asosida shakllantirish (tirik vazndagi go‘sht asosida) Misol shartli Izoh: Hisoblash jadvali dehqonchilik va chorvachilikning har bir turdagi mahsuloti bo‘yicha alohida shakllantiriladi."}
] AS row
MERGE (p:Paragraph {number: row.number}) SET p += row;

// BELONGS_TO : Paragraph -> Methodology
MATCH (p:Paragraph), (m:Methodology {code:'MET_YAICH'})
MERGE (p)-[:BELONGS_TO]->(m);
// ---------------------------------------------------------------------
// 6. Unit — o'lchov birliklari
// ---------------------------------------------------------------------
UNWIND [
  {code:"U_TONNA", name:"tonna", turi:"massa"},
  {code:"U_MING_TONNA", name:"ming tonna", turi:"massa"},
  {code:"U_KG", name:"kilogramm", turi:"massa"},
  {code:"U_DONA", name:"dona", turi:"miqdor"},
  {code:"U_MING_DONA", name:"ming dona", turi:"miqdor"},
  {code:"U_MLN_DONA", name:"mln dona", turi:"miqdor"},
  {code:"U_SOM", name:"so‘m", turi:"qiymat"},
  {code:"U_MING_SOM", name:"ming so‘m", turi:"qiymat"},
  {code:"U_MLN_SOM", name:"mln so‘m", turi:"qiymat"},
  {code:"U_MLRD_SOM", name:"mlrd so‘m", turi:"qiymat"},
  {code:"U_SOM_KG", name:"so‘m/kg", turi:"narx"},
  {code:"U_SOM_TONNA", name:"so‘m/tonna", turi:"narx"},
  {code:"U_GEKTAR", name:"gektar", turi:"maydon"},
  {code:"U_FOIZ", name:"foiz (%)", turi:"nisbat"},
  {code:"U_GRAMM", name:"gramm", turi:"massa"},
  {code:"U_KOROBKA", name:"korobka", turi:"miqdor"}
] AS row
MERGE (n:Unit {code: row.code}) SET n += row;

// ---------------------------------------------------------------------
// 7. Price — narx turlari
// ---------------------------------------------------------------------
UNWIND [
  {code:"PRICE_JORIY", name:"Joriy narx (p1)", belgi:"p1", tarif:"Ko‘rib chiqilayotgan davrda amal qiladigan narxlar", asos_band:"4, 14-bandlar", turi:"joriy"},
  {code:"PRICE_TAQQOSLAMA", name:"Taqqoslama narx (p0)", belgi:"p0", tarif:"O‘tgan yilning mos davridagi joriy narxlar bazis sifatida qabul qilinadi", asos_band:"4, 34, 38-bandlar", turi:"taqqoslama"},
  {code:"PRICE_ORT_SOTISH", name:"O‘rtacha sotish narxi", belgi:"p_sot", tarif:"Mahsulotning hisobot davridagi o‘rtacha sotish narxi", asos_band:"14-band", turi:"joriy"},
  {code:"PRICE_ISHLAB_CHIQ", name:"Ishlab chiqaruvchi narxi", belgi:"p_ich", tarif:"Don ekinlari va paxta xomashyosi qiymatini hisoblashda qo‘llaniladi", asos_band:"58, 59-bandlar", turi:"joriy"},
  {code:"PRICE_BOZOR", name:"Dehqon bozori narxi", belgi:"p_boz", tarif:"\"5 bozor narxlari\" blankasi ma’lumotlari asosida shakllantiriladi", asos_band:"60-band", turi:"joriy"}
] AS row
MERGE (n:Price {code: row.code}) SET n += row;

// ---------------------------------------------------------------------
// 8. Formula — hisoblash formulalari reestri
// ---------------------------------------------------------------------
UNWIND [
  {code:"F_14", name:"Si1 = ki1 × pi1", ifoda:"Si1 = ki1 × pi1", mazmun:"i-turdagi mahsulotning joriy narxlardagi qiymati", asos_band:14, turi:"joriy narx"},
  {code:"F_16", name:"S(joriy) = Σ (ki1 × pi1)", ifoda:"S(joriy) = Σ (ki1 × pi1)", mazmun:"Jami dehqonchilik va chorvachilik mahsulotlari qiymati", asos_band:16, turi:"joriy narx"},
  {code:"F_21", name:"N(deh) = z(kuz) × pl(kuz)", ifoda:"N(deh) = z(kuz) × pl(kuz)", mazmun:"Dehqonchilikda tugallanmagan ishlab chiqarish qiymati", asos_band:21, turi:"joriy narx"},
  {code:"F_23", name:"S(xiz) = S(bozor) + S(nobozor)", ifoda:"S(xiz) = S(bozor) + S(nobozor)", mazmun:"Dehqonchilik va chorvachilik sohasidagi xizmatlar qiymati", asos_band:23, turi:"joriy narx"},
  {code:"F_24", name:"Vv(deh/chor) = (S deh + N deh) + S chor + S xiz", ifoda:"Vv(deh/chor) = (S deh + N deh) + S chor + S xiz", mazmun:"Dehqonchilik va chorvachilik YaICh", asos_band:24, turi:"joriy narx"},
  {code:"F_26", name:"Vv(01) = Vv(deh/chor) + S(ov)", ifoda:"Vv(01) = Vv(deh/chor) + S(ov)", mazmun:"A seksiya 01-bo‘lim bo‘yicha yakuniy hisob", asos_band:26, turi:"joriy narx"},
  {code:"F_30", name:"Vv(A) = Vv(01) + Vv(02) + Vv(03)", ifoda:"Vv(A) = Vv(01) + Vv(02) + Vv(03)", mazmun:"A seksiya bo‘yicha jami yalpi ishlab chiqarish", asos_band:30, turi:"joriy narx"},
  {code:"F_34", name:"Si(taqqos) = ki1 × pi0", ifoda:"Si(taqqos) = ki1 × pi0", mazmun:"Taqqoslama narxlarda to‘g‘ridan-to‘g‘ri qayta baholash", asos_band:34, turi:"taqqoslama narx"},
  {code:"F_36", name:"S(taqqos) = Σ (ki1 × pi0)", ifoda:"S(taqqos) = Σ (ki1 × pi0)", mazmun:"Jami qiymat taqqoslama narxlarda", asos_band:36, turi:"taqqoslama narx"},
  {code:"F_38", name:"Iq = Σ q1p0 / Σ q0p0", ifoda:"Iq = Σ q1p0 / Σ q0p0", mazmun:"Fizik hajm indeksi — Paashe indeksi", asos_band:38, turi:"indeks"},
  {code:"F_41", name:"FHI = (Σ q1p0 / Σ q0p0) × 100", ifoda:"FHI = (Σ q1p0 / Σ q0p0) × 100", mazmun:"Fizik hajm umumiy indeksi, % da", asos_band:41, turi:"indeks"},
  {code:"F_43", name:"N(taqqos) = o‘tgan yil ekin maydoni × birlik xarajatlarining o‘rtacha darajasi", ifoda:"N(taqqos) = o‘tgan yil ekin maydoni × birlik xarajatlarining o‘rtacha darajasi", mazmun:"Tugallanmagan i/ch ni taqqoslama narxlarda baholash", asos_band:43, turi:"taqqoslama narx"},
  {code:"F_44", name:"S(taqqos) = S(bazis) × I(bandlar soni)", ifoda:"S(taqqos) = S(bazis) × I(bandlar soni)", mazmun:"Xizmatlar va ovchilikni ekstrapolyatsiya qilish", asos_band:44, turi:"ekstrapolyatsiya"},
  {code:"F_45", name:"S(taqqos) = S(bazis) × I(o‘rmon daraxtlari maydoni)", ifoda:"S(taqqos) = S(bazis) × I(o‘rmon daraxtlari maydoni)", mazmun:"O‘rmonchilikni ekstrapolyatsiya qilish (choraklikda — bandlar soni indeksi)", asos_band:45, turi:"ekstrapolyatsiya"},
  {code:"F_46", name:"S(taqqos) = S(bazis) × I(baliq ovlash hajmi)", ifoda:"S(taqqos) = S(bazis) × I(baliq ovlash hajmi)", mazmun:"Baliqchilikni ekstrapolyatsiya qilish", asos_band:46, turi:"ekstrapolyatsiya"},
  {code:"F_55", name:"N(chorak) = d(o‘tgan yil mos chorak) × V(dehqonchilik)", ifoda:"N(chorak) = d(o‘tgan yil mos chorak) × V(dehqonchilik)", mazmun:"Tugallanmagan i/ch ni choraklarga taqsimlash (ulush koeffitsiyenti)", asos_band:55, turi:"choraklik"},
  {code:"F_56", name:"Si(boshq) = d(yil) × V1(chorak) / (1,0 − d(yil))", ifoda:"Si(boshq) = d(yil) × V1(chorak) / (1,0 − d(yil))", mazmun:"Boshqa turdagi mahsulotlarni choraklik hisoblash", asos_band:56, turi:"choraklik"},
  {code:"F_61", name:"V(tur, chorak) = V(jami chorak) × d(tur, yillik)", ifoda:"V(tur, chorak) = V(jami chorak) × d(tur, yillik)", mazmun:"Mahsulot turlarini yillik ulush bo‘yicha choraklarga taqsimlash", asos_band:61, turi:"choraklik"},
  {code:"F_73", name:"V(yillik) = Σ V(I..IV diskret chorak)", ifoda:"V(yillik) = Σ V(I..IV diskret chorak)", mazmun:"Diskret choraklar yig‘indisi sifatida yillik hajm", asos_band:73, turi:"diskret"},
  {code:"F_DEFLYATOR", name:"Deflyator = (Σ q1p1 / Σ q1p0) × 100", ifoda:"Deflyator = (Σ q1p1 / Σ q1p0) × 100", mazmun:"Joriy va taqqoslama baholash nisbati", asos_band:null, turi:"indeks"},
  {code:"F_NOMINAL", name:"I(nominal) = FHI × Deflyator = (Σ q1p1 / Σ q0p0) × 100", ifoda:"I(nominal) = FHI × Deflyator = (Σ q1p1 / Σ q0p0) × 100", mazmun:"Nominal o‘zgarish — tekshiruv ayniyati", asos_band:null, turi:"indeks"},
  {code:"F_TUT_BARGI", name:"Tut bargi = pilla miqdori × 20", ifoda:"Tut bargi = pilla miqdori × 20", mazmun:"6-ilova normativi: 1 kg pilla uchun 20 kg tut bargi", asos_band:62, turi:"normativ"},
  {code:"F_POXOL", name:"Poxol = boshoqli don ishlab chiqarish hajmining 100 %", ifoda:"Poxol = boshoqli don ishlab chiqarish hajmining 100 %", mazmun:"6-ilova normativi", asos_band:62, turi:"normativ"},
  {code:"F_GOZAPOYA", name:"G‘o‘zapoya = ekin maydoni (ga) × 10–15 tonna", ifoda:"G‘o‘zapoya = ekin maydoni (ga) × 10–15 tonna", mazmun:"6-ilova normativi", asos_band:62, turi:"normativ"}
] AS row
MERGE (n:Formula {code: row.code}) SET n += row;

// Formula -> Paragraph (DEFINED_IN)
MATCH (f:Formula) WHERE f.asos_band IS NOT NULL
MATCH (p:Paragraph {number: f.asos_band})
MERGE (f)-[:DEFINED_IN]->(p);

// ---------------------------------------------------------------------
// 9. Organization — tashkilotlar
//    tasdiqlangan=false -> hujjatda to'g'ridan-to'g'ri nomlanmagan, aniqlashtirish talab etiladi
// ---------------------------------------------------------------------
UNWIND [
  {code:"ORG_STAT", name:"O‘zbekiston Respublikasi Prezidenti huzuridagi Statistika agentligi", qisqa:"Statistika agentligi", turi:"davlat organi", rol:"YaICh hisob-kitobini tashkil etuvchi va statistik kuzatuvlarni o‘tkazuvchi organ", tasdiqlangan:true},
  {code:"ORG_DSQ", name:"O‘zbekiston Respublikasi Davlat statistika qo‘mitasi", qisqa:"Davlat statistika qo‘mitasi", turi:"davlat organi (huquqiy vorisi — Statistika agentligi)", rol:"2021 y. 26-son qarorni qabul qilgan organ", tasdiqlangan:true},
  {code:"ORG_MOLIYA", name:"Davlat budjeti ijrosi to‘g‘risidagi hisobotni shakllantiruvchi organ (Moliya vazirligi)", qisqa:"Moliya vazirligi", turi:"vazirlik", rol:"Nobozor (budjet) xizmatlari bo‘yicha ma’muriy ma’lumot manbai (23, 28, 80-bandlar)", tasdiqlangan:false},
  {code:"ORG_TARMOQ", name:"Tarmoq vazirlik va idoralari, tarmoq boshqarmalari", qisqa:"Tarmoq boshqarmalari", turi:"vazirlik/idora", rol:"Tegishli tarmoq ma’lumotlarini taqdim etuvchi manba (80-band)", tasdiqlangan:true},
  {code:"ORG_FAO", name:"BMTning Oziq-ovqat va qishloq xo‘jaligi tashkiloti (FAO)", qisqa:"FAO", turi:"xalqaro tashkilot", rol:"Uslubiy nizomni ishlab chiqishda tavsiyalari qo‘llanilgan (81-band)", tasdiqlangan:true},
  {code:"ORG_MDH_STAT", name:"Mustaqil Davlatlar Hamdo‘stligi Davlatlararo statistika qo‘mitasi", qisqa:"MDH Statqo‘mitasi", turi:"xalqaro tashkilot", rol:"Uslubiy tavsiyalar manbai (81-band)", tasdiqlangan:true}
] AS row
MERGE (n:Organization {code: row.code}) SET n += row;

// ---------------------------------------------------------------------
// 10. Department — boshqarmalar
// ---------------------------------------------------------------------
UNWIND [
  {code:"DEP_QX_STAT", name:"Qishloq xo‘jaligi statistikasi boshqarmasi", rol:"YaICh bo‘yicha bevosita hisob-kitobni yurituvchi boshqarma", tasdiqlangan:false},
  {code:"DEP_MILLIY_HISOB", name:"Milliy hisoblar (makroiqtisodiy statistika) boshqarmasi", rol:"YaICh natijalarini YaIM hisobiga integratsiya qilish", tasdiqlangan:false},
  {code:"DEP_GEO_AI", name:"Geofazoviy texnologiyalar va sun’iy intellektni joriy etish boshqarmasi", rol:"GIS/AI yechimlari, bilim grafi va analitik tizimlarni joriy etish", tasdiqlangan:false},
  {code:"DEP_HUDUDIY", name:"Qoraqalpog‘iston Respublikasi, viloyatlar va Toshkent shahri statistika boshqarmalari", rol:"Tuman kesimidan boshlab dastlabki hisob-kitob (8-band)", tasdiqlangan:true}
] AS row
MERGE (n:Department {code: row.code}) SET n += row;

MATCH (d:Department), (o:Organization {code:'ORG_STAT'})
MERGE (d)-[:PART_OF]->(o);

// ---------------------------------------------------------------------
// 11. System — axborot tizimlari
// ---------------------------------------------------------------------
UNWIND [
  {code:"SYS_ESTAT", name:"eStat — statistik hisobotlarni elektron yig‘ish tizimi", turi:"yig‘ish tizimi", tasdiqlangan:false},
  {code:"SYS_ESTAT4", name:"ESTAT 4.0 — statistik hisobot tizimi", turi:"yig‘ish/qayta ishlash tizimi", tasdiqlangan:false},
  {code:"SYS_ADMIN", name:"Ma’muriy manbalar (davlat budjeti ijrosi hisoboti) tizimi", turi:"ma’muriy manba", tasdiqlangan:true},
  {code:"SYS_XLSX", name:"SNSga_17072026.xlsx — jamlanma hisob-kitob fayli", turi:"hisob-kitob fayli", tasdiqlangan:true},
  {code:"SYS_GSBPM", name:"GSBPM / GSIM — statistik ishlab chiqarishning umumiy modeli", turi:"metodologik standart", tasdiqlangan:true}
] AS row
MERGE (n:System {code: row.code}) SET n += row;
// ---------------------------------------------------------------------
// 12. Source — axborot manbalari (7-bob, 80-band)
// ---------------------------------------------------------------------
UNWIND [
  {code:"SRC_4FX", shakl:"4 fx", name:"Fermer xo‘jaligi faoliyati to‘g‘risida hisobot", davriylik:"choraklik", qamrov:"fermer xo‘jaliklari", asos_band:"80-band"},
  {code:"SRC_4DX", shakl:"4 dx", name:"Dehqon va tomorqa xo‘jaliklari faoliyati to‘g‘risida hisobot", davriylik:"choraklik", qamrov:"dehqon va tomorqa xo‘jaliklari", asos_band:"80-band"},
  {code:"SRC_4QX", shakl:"4 qx (tashkilot)", name:"Qishloq xo‘jaligi faoliyati to‘g‘risida hisobot", davriylik:"choraklik", qamrov:"qishloq xo‘jaligi tashkilotlari", asos_band:"80-band"},
  {code:"SRC_3PILLA", shakl:"3 pilla", name:"Pilla xaridi to‘g‘risida hisobot", davriylik:"choraklik", qamrov:"pilla xaridi (57-band)", asos_band:"80-band"},
  {code:"SRC_3DON", shakl:"3 don", name:"Don ekinlarini tayyorlash to‘g‘risida hisobot", davriylik:"choraklik", qamrov:"don tayyorlash (58-band)", asos_band:"80-band"},
  {code:"SRC_3PAXTA", shakl:"3 paxta", name:"Paxta xomashyosini tayyorlash to‘g‘risida hisobot", davriylik:"choraklik", qamrov:"paxta tayyorlash (59-band)", asos_band:"80-band"},
  {code:"SRC_1FX", shakl:"1 fx", name:"Fermer xo‘jaligi faoliyati to‘g‘risida hisobot", davriylik:"yillik", qamrov:"fermer xo‘jaliklari", asos_band:"80-band"},
  {code:"SRC_1QX", shakl:"1 qx (tashkilot)", name:"Qishloq xo‘jaligi faoliyati to‘g‘risida hisobot", davriylik:"yillik", qamrov:"qishloq xo‘jaligi tashkilotlari", asos_band:"80-band"},
  {code:"SRC_1KB", shakl:"1 kb (qx)", name:"Mikrofirma va kichik korxonaning qishloq xo‘jaligi faoliyati to‘g‘risida hisobot", davriylik:"yillik", qamrov:"kichik korxona va mikrofirmalar", asos_band:"80-band"},
  {code:"SRC_1OX", shakl:"1 ox (ovchilik)", name:"Ovchilik xo‘jaligi faoliyati to‘g‘risida hisobot", davriylik:"yillik", qamrov:"ovchilik xo‘jaligi (25-band)", asos_band:"80-band"},
  {code:"SRC_1UX", shakl:"1 o‘x (o‘rmon)", name:"O‘rmon parvarishi ishlarini o‘tkazish to‘g‘risida hisobot", davriylik:"yillik", qamrov:"o‘rmonchilik (02-bo‘lim)", asos_band:"80-band"},
  {code:"SRC_5BOZOR", shakl:"5 bozor narxlari", name:"Dehqon bozorlarida narxlarni ro‘yxatga olish blankasi", davriylik:"oylik/choraklik", qamrov:"narxlar (60-band)", asos_band:"80-band"},
  {code:"SRC_TARMOQ", shakl:"—", name:"Tarmoq boshqarmalarining tegishli ma’lumotlari", davriylik:"doimiy", qamrov:"qo‘shimcha ma’lumotlar", asos_band:"80-band"},
  {code:"SRC_ADMIN", shakl:"—", name:"Ma’muriy manbalar: davlat budjetini bajarish to‘g‘risidagi hisobot, vazirlik va idoralar ma’lumotlari", davriylik:"yillik/choraklik", qamrov:"nobozor xizmatlar (23, 28-bandlar)", asos_band:"80-band"}
] AS row
MERGE (n:Source {code: row.code}) SET n += row;

// COLLECTED_BY : Source -> Organization
UNWIND [
  {s:"SRC_4FX", o:"ORG_STAT"},
  {s:"SRC_4DX", o:"ORG_STAT"},
  {s:"SRC_4QX", o:"ORG_STAT"},
  {s:"SRC_3PILLA", o:"ORG_STAT"},
  {s:"SRC_3DON", o:"ORG_STAT"},
  {s:"SRC_3PAXTA", o:"ORG_STAT"},
  {s:"SRC_1FX", o:"ORG_STAT"},
  {s:"SRC_1QX", o:"ORG_STAT"},
  {s:"SRC_1KB", o:"ORG_STAT"},
  {s:"SRC_1OX", o:"ORG_STAT"},
  {s:"SRC_1UX", o:"ORG_STAT"},
  {s:"SRC_5BOZOR", o:"ORG_STAT"},
  {s:"SRC_TARMOQ", o:"ORG_TARMOQ"},
  {s:"SRC_ADMIN", o:"ORG_MOLIYA"}
] AS row
MATCH (s:Source {code: row.s}), (o:Organization {code: row.o})
MERGE (s)-[:COLLECTED_BY]->(o);

// Source -> System (qo'shimcha bog'lanish)
MATCH (s:Source), (sys:System {code:'SYS_ESTAT'}) WHERE s.shakl <> '—'
MERGE (s)-[:COLLECTED_VIA]->(sys);
MATCH (s:Source {code:'SRC_ADMIN'}), (sys:System {code:'SYS_ADMIN'})
MERGE (s)-[:COLLECTED_VIA]->(sys);

// ---------------------------------------------------------------------
// 13. Report — statistik hisobotlar / hisob-kitoblar
// ---------------------------------------------------------------------
UNWIND [
  {code:"REP_CHORAK", name:"Choraklik tezkor hisob-kitob — yil boshidan o‘sib boruvchi yakunda", davriylik:"choraklik (I: yanvar-mart, II: yanvar-iyun, III: yanvar-sentabr, IV: yanvar-dekabr)", turi:"tezkor", asos_band:"7, 48-bandlar"},
  {code:"REP_DISKRET", name:"Diskret (sof) choraklar asosidagi hisob-kitob", davriylik:"diskret chorak (I: yanvar-mart, II: aprel-iyun, III: iyul-sentabr, IV: oktabr-dekabr)", turi:"tezkor", asos_band:"69-77-bandlar"},
  {code:"REP_YILLIK", name:"Yillik yakuniy hisob-kitob", davriylik:"yillik", turi:"yakuniy", asos_band:"49, 50-bandlar"},
  {code:"REP_SNSGA", name:"SNSga_17072026.xlsx — 2026 yil yanvar-iyun jamlanma hisob-kitobi", davriylik:"choraklik", turi:"ishchi jamlanma", asos_band:"—", fayl:"SNSga_17072026.xlsx", davr:"2026-01/06"}
] AS row
MERGE (n:Report {code: row.code}) SET n += row;

MATCH (r:Report), (sys:System {code:'SYS_GSBPM'}) MERGE (r)-[:PRODUCED_IN]->(sys);
MATCH (r:Report {code:'REP_SNSGA'}), (sys:System {code:'SYS_XLSX'}) MERGE (r)-[:PRODUCED_IN]->(sys);

// ---------------------------------------------------------------------
// 14. Table — hisoblash jadvallari va hisobot varaqlari
// ---------------------------------------------------------------------
UNWIND [
  {code:"TBL_ILOVA1", name:"1-ilova jadvali — Qishloq xo‘jaligi mahsulotlarining fizik hajmini shakllantirish", manba:"APP_1", turi:"hisoblash sxemasi", satrlar:"101-115"},
  {code:"TBL_ILOVA2", name:"2-ilova jadvali — YaICh ni joriy narxlarda hisoblash sxemasi", manba:"APP_2", turi:"hisoblash sxemasi", satrlar:"201-216, I-X"},
  {code:"TBL_ILOVA3", name:"3-ilova jadvali — YaICh ni taqqoslama narxlarda hisoblash sxemasi", manba:"APP_3", turi:"hisoblash sxemasi", satrlar:"301-316, I-X"},
  {code:"TBL_ILOVA4", name:"4-ilova jadvali — boshqa turdagi mahsulotlar ro‘yxati", manba:"APP_4", turi:"ro‘yxat", satrlar:"401-471"},
  {code:"TBL_ILOVA5", name:"5-ilova jadvali — sabzavot turlarini choraklik taqsimlash (shartli misol)", manba:"APP_5", turi:"misol", satrlar:null},
  {code:"TBL_ILOVA6_1", name:"6.1-jadval — bitta hayvondan chiqadigan go‘ngning taxminiy me’yorlari", manba:"APP_6", turi:"normativ", satrlar:null},
  {code:"TBL_ILOVA6_2", name:"6.2-jadval — bitta asalari oilasidan olinadigan qo‘shimcha mahsulot me’yorlari", manba:"APP_6", turi:"normativ", satrlar:null},
  {code:"TBL_ILOVA7", name:"7-ilova jadvali — diskret choraklar asosida shakllantirish (go‘sht misolida)", manba:"APP_7", turi:"misol", satrlar:"701-705"},
  {code:"TBL_XLS_RESPUBLIKA", name:"SNSga.xlsx — \"Respublika\" varag‘i", manba:"REP_SNSGA", turi:"natija jadvali", satrlar:null},
  {code:"TBL_XLS_VALOVKA", name:"SNSga.xlsx — \"valovka\" varag‘i (mahsulot turlari kesimi)", manba:"REP_SNSGA", turi:"natija jadvali", satrlar:null},
  {code:"TBL_XLS_VILOYAT", name:"SNSga.xlsx — \"viloyat\" / \"Viloyatlar\" varaqlari (hududiy kesim)", manba:"REP_SNSGA", turi:"natija jadvali", satrlar:null},
  {code:"TBL_XLS_MULKCHILIK", name:"SNSga.xlsx — \"mulkchilik\" varag‘i", manba:"REP_SNSGA", turi:"natija jadvali", satrlar:null},
  {code:"TBL_XLS_OSISH", name:"SNSga.xlsx — \"osish_deflyator_ulush\" varag‘i", manba:"REP_SNSGA", turi:"natija jadvali", satrlar:null},
  {code:"TBL_XLS_SEKTOR", name:"SNSga.xlsx — \"sektor2025\" / \"sektor2026\" varaqlari (institutsional sektorlar)", manba:"REP_SNSGA", turi:"natija jadvali", satrlar:"to‘ldirilmagan"}
] AS row
MERGE (n:Table {code: row.code}) SET n += row;

// HAS_TABLE : Report -> Table
MATCH (t:Table {manba:'REP_SNSGA'}), (r:Report {code:'REP_SNSGA'}) MERGE (r)-[:HAS_TABLE]->(t);
MATCH (t:Table) WHERE t.code IN ['TBL_ILOVA1','TBL_ILOVA2','TBL_ILOVA3','TBL_ILOVA4','TBL_ILOVA5','TBL_ILOVA6_1','TBL_ILOVA6_2']
MATCH (r:Report) WHERE r.code IN ['REP_CHORAK','REP_YILLIK'] MERGE (r)-[:HAS_TABLE]->(t);
MATCH (t:Table) WHERE t.code IN ['TBL_ILOVA1','TBL_ILOVA2','TBL_ILOVA3','TBL_ILOVA7']
MATCH (r:Report {code:'REP_DISKRET'}) MERGE (r)-[:HAS_TABLE]->(t);
// Table -> Appendix (qo'shimcha bog'lanish)
MATCH (t:Table) WHERE t.manba STARTS WITH 'APP_'
MATCH (a:Appendix {code: t.manba}) MERGE (t)-[:IN_APPENDIX]->(a);

// ---------------------------------------------------------------------
// 15. Column — jadval ustunlari
// ---------------------------------------------------------------------
UNWIND [
  {code:"COL_I1_1", jadval:"TBL_ILOVA1", ustun:"1", name:"Fermer xo‘jaliklari"},
  {code:"COL_I1_2", jadval:"TBL_ILOVA1", ustun:"2", name:"Dehqon va tomorqa xo‘jaliklari"},
  {code:"COL_I1_3", jadval:"TBL_ILOVA1", ustun:"3", name:"Qishloq xo‘jaligi faoliyatini amalga oshiruvchi tashkilotlar"},
  {code:"COL_I1_4", jadval:"TBL_ILOVA1", ustun:"4 (1+2+3)", name:"Barcha toifadagi xo‘jaliklar"},
  {code:"COL_I2_1", jadval:"TBL_ILOVA2", ustun:"1", name:"O‘rtacha (hisobot davridagi) narx, so‘m — pi1"},
  {code:"COL_I2_2", jadval:"TBL_ILOVA2", ustun:"2", name:"Mahsulotlarning fizik hajmi — ki1"},
  {code:"COL_I2_3", jadval:"TBL_ILOVA2", ustun:"3 (1×2)", name:"Joriy narxlardagi qiymati, ming so‘m"},
  {code:"COL_I3_1", jadval:"TBL_ILOVA3", ustun:"1", name:"Taqqoslama narx, so‘m — pi0"},
  {code:"COL_I3_2", jadval:"TBL_ILOVA3", ustun:"2", name:"O‘tgan yil fizik hajmi — q0"},
  {code:"COL_I3_3", jadval:"TBL_ILOVA3", ustun:"3 (1×2)", name:"O‘tgan yil qiymati — q0p0"},
  {code:"COL_I3_4", jadval:"TBL_ILOVA3", ustun:"4", name:"Joriy yil fizik hajmi — q1"},
  {code:"COL_I3_5", jadval:"TBL_ILOVA3", ustun:"5 (1×4)", name:"Joriy yil qiymati taqqoslama narxda — q1p0"},
  {code:"COL_I3_6", jadval:"TBL_ILOVA3", ustun:"6 (5/3×100)", name:"Fizik hajm indeksi (FHI), %"},
  {code:"COL_I5_1", jadval:"TBL_ILOVA5", ustun:"1", name:"Yillik ishlab chiqarish hajmi, tonna"},
  {code:"COL_I5_2", jadval:"TBL_ILOVA5", ustun:"2", name:"Yillik hisoblashdagi ulushi, %"},
  {code:"COL_I5_3", jadval:"TBL_ILOVA5", ustun:"3", name:"Joriy chorakdagi ishlab chiqarish hajmi, tonna"},
  {code:"COL_I5_4", jadval:"TBL_ILOVA5", ustun:"4", name:"Joriy narx, 1 kg uchun so‘m"},
  {code:"COL_I5_5", jadval:"TBL_ILOVA5", ustun:"5", name:"Joriy narxlardagi umumiy qiymati, mln so‘m"},
  {code:"COL_I7_1", jadval:"TBL_ILOVA7", ustun:"1-2", name:"Fermer xo‘jaliklari — hajmi va qiymati"},
  {code:"COL_I7_2", jadval:"TBL_ILOVA7", ustun:"3-4", name:"Dehqon va tomorqa xo‘jaliklari — hajmi va qiymati"},
  {code:"COL_I7_3", jadval:"TBL_ILOVA7", ustun:"5-6", name:"Tashkilotlar — hajmi va qiymati"},
  {code:"COL_I7_4", jadval:"TBL_ILOVA7", ustun:"7-8", name:"Jami (1+3+5), (2+4+6)"},
  {code:"COL_X_2025", jadval:"TBL_XLS_RESPUBLIKA", ustun:"2025", name:"2025 yil mos davri, mlrd so‘m — bazis"},
  {code:"COL_X_2026", jadval:"TBL_XLS_RESPUBLIKA", ustun:"2026", name:"2026 yil yanvar-iyun, joriy narxlarda, mlrd so‘m"},
  {code:"COL_X_OSISH", jadval:"TBL_XLS_OSISH", ustun:"o‘sish", name:"O‘sish sur’ati (FHI), %"},
  {code:"COL_X_DEFL", jadval:"TBL_XLS_OSISH", ustun:"deflyator", name:"Deflyator indeksi, %"},
  {code:"COL_X_ULUSH", jadval:"TBL_XLS_OSISH", ustun:"ulush", name:"Jamiga nisbatan ulushi, %"},
  {code:"COL_X_HUDUD", jadval:"TBL_XLS_VILOYAT", ustun:"hudud", name:"Qoraqalpog‘iston Respublikasi, viloyatlar va Toshkent shahri kesimi"},
  {code:"COL_X_MULK", jadval:"TBL_XLS_MULKCHILIK", ustun:"mulkchilik", name:"Davlat / nodavlat mulk kesimi"},
  {code:"COL_X_NOBOZOR", jadval:"TBL_XLS_VALOVKA", ustun:"nobozor", name:"Nobozor (budjet) xizmatlari, mlrd so‘m"}
] AS row
MERGE (n:Column {code: row.code}) SET n += row;

// HAS_COLUMN : Table -> Column
MATCH (c:Column), (t:Table {code: c.jadval}) MERGE (t)-[:HAS_COLUMN]->(c);

// SOURCE_FROM : Column -> Source
UNWIND [
  {c:"COL_I1_1", s:"SRC_4FX"},
  {c:"COL_I1_1", s:"SRC_1FX"},
  {c:"COL_I1_2", s:"SRC_4DX"},
  {c:"COL_I1_3", s:"SRC_4QX"},
  {c:"COL_I1_3", s:"SRC_1QX"},
  {c:"COL_I1_3", s:"SRC_1KB"},
  {c:"COL_I2_1", s:"SRC_5BOZOR"},
  {c:"COL_I2_1", s:"SRC_3DON"},
  {c:"COL_I2_1", s:"SRC_3PAXTA"},
  {c:"COL_I2_1", s:"SRC_3PILLA"},
  {c:"COL_I2_2", s:"SRC_4FX"},
  {c:"COL_I2_2", s:"SRC_4DX"},
  {c:"COL_I2_2", s:"SRC_4QX"},
  {c:"COL_I2_2", s:"SRC_1FX"},
  {c:"COL_I2_2", s:"SRC_1QX"},
  {c:"COL_I2_2", s:"SRC_1KB"},
  {c:"COL_I2_2", s:"SRC_1OX"},
  {c:"COL_I2_2", s:"SRC_1UX"},
  {c:"COL_I3_1", s:"SRC_5BOZOR"},
  {c:"COL_I3_2", s:"SRC_4FX"},
  {c:"COL_I3_2", s:"SRC_4DX"},
  {c:"COL_I3_2", s:"SRC_4QX"},
  {c:"COL_I3_4", s:"SRC_4FX"},
  {c:"COL_I3_4", s:"SRC_4DX"},
  {c:"COL_I3_4", s:"SRC_4QX"},
  {c:"COL_I5_1", s:"SRC_1FX"},
  {c:"COL_I5_1", s:"SRC_1QX"},
  {c:"COL_I5_4", s:"SRC_5BOZOR"},
  {c:"COL_I7_1", s:"SRC_4FX"},
  {c:"COL_I7_2", s:"SRC_4DX"},
  {c:"COL_I7_3", s:"SRC_4QX"},
  {c:"COL_X_2025", s:"SRC_4FX"},
  {c:"COL_X_2025", s:"SRC_4DX"},
  {c:"COL_X_2025", s:"SRC_4QX"},
  {c:"COL_X_2026", s:"SRC_4FX"},
  {c:"COL_X_2026", s:"SRC_4DX"},
  {c:"COL_X_2026", s:"SRC_4QX"},
  {c:"COL_X_2026", s:"SRC_5BOZOR"},
  {c:"COL_X_HUDUD", s:"SRC_4FX"},
  {c:"COL_X_HUDUD", s:"SRC_4DX"},
  {c:"COL_X_HUDUD", s:"SRC_4QX"},
  {c:"COL_X_MULK", s:"SRC_4QX"},
  {c:"COL_X_MULK", s:"SRC_ADMIN"},
  {c:"COL_X_NOBOZOR", s:"SRC_ADMIN"}
] AS row
MATCH (c:Column {code: row.c}), (s:Source {code: row.s})
MERGE (c)-[:SOURCE_FROM]->(s);
// ---------------------------------------------------------------------
// 16. Indicator — statistik ko'rsatkichlar
//     turi: mahsulot | agregat | komponent | indeks
//     qiymatlar: 2026 yil yanvar-iyun, joriy narxlarda, mlrd so'm
// ---------------------------------------------------------------------
UNWIND [
  {code:"IND_DON", name:"Don ekinlari", turi:"mahsulot", soha:"dehqonchilik", guruh:"asosiy", olchov_birligi:"U_TONNA", satr_1ilova:"101", satr_2ilova:"201", satr_3ilova:"301", hajm_2026:7516.4, hajm_birligi:"ming tonna", qiymat_2026_mlrd_som:22053.3, osish_foiz:113.8, deflyator_foiz:92.2, davr:"2026 yil yanvar-iyun", izoh:"Qiymat ishlab chiqaruvchi narxlarida hisoblanadi (58-band)"},
  {code:"IND_PAXTA", name:"Paxta xomashyosi", turi:"mahsulot", soha:"dehqonchilik", guruh:"asosiy", olchov_birligi:"U_TONNA", satr_1ilova:"102", satr_2ilova:"202", satr_3ilova:"302", hajm_2026:0.0, hajm_birligi:"ming tonna", qiymat_2026_mlrd_som:0.0, osish_foiz:null, deflyator_foiz:null, davr:"2026 yil yanvar-iyun", izoh:"Yanvar-iyunda hosil yig‘ilmagan; tugallanmagan ishlab chiqarish sifatida hisoblanadi (52-band)"},
  {code:"IND_KARTOSHKA", name:"Kartoshka", turi:"mahsulot", soha:"dehqonchilik", guruh:"asosiy", olchov_birligi:"U_TONNA", satr_1ilova:"103", satr_2ilova:"203", satr_3ilova:"303", hajm_2026:2254.3, hajm_birligi:"ming tonna", qiymat_2026_mlrd_som:8989.5, osish_foiz:115.5, deflyator_foiz:115.1, davr:"2026 yil yanvar-iyun", izoh:"Namunaviy hisob: q0=1952,4 ming t; p1=3987,3 so‘m/kg; p0=3465,7 so‘m/kg; q1p0=7812,9; q0p0=6766,4 mlrd so‘m. HTML hujjatning 06-bo‘limida deflyator 115,2 % (yaxlitlash farqi)"},
  {code:"IND_SABZAVOT", name:"Sabzavot ekinlari", turi:"mahsulot", soha:"dehqonchilik", guruh:"asosiy", olchov_birligi:"U_TONNA", satr_1ilova:"104", satr_2ilova:"204", satr_3ilova:"304", hajm_2026:4454.0, hajm_birligi:"ming tonna", qiymat_2026_mlrd_som:25679.3, osish_foiz:106.7, deflyator_foiz:93.9, davr:"2026 yil yanvar-iyun", izoh:"Choraklik kesimda turlar bo‘yicha 5-ilova ulushlari qo‘llaniladi (61-band)"},
  {code:"IND_POLIZ", name:"Poliz ekinlari", turi:"mahsulot", soha:"dehqonchilik", guruh:"asosiy", olchov_birligi:"U_TONNA", satr_1ilova:"105", satr_2ilova:"205", satr_3ilova:"305", hajm_2026:1109.4, hajm_birligi:"ming tonna", qiymat_2026_mlrd_som:3746.0, osish_foiz:118.2, deflyator_foiz:86.2, davr:"2026 yil yanvar-iyun", izoh:null},
  {code:"IND_MEVA", name:"Mevalar va rezavorlar", turi:"mahsulot", soha:"dehqonchilik", guruh:"asosiy", olchov_birligi:"U_TONNA", satr_1ilova:"106", satr_2ilova:"206", satr_3ilova:"306", hajm_2026:2820.1, hajm_birligi:"ming tonna", qiymat_2026_mlrd_som:28637.7, osish_foiz:100.6, deflyator_foiz:103.9, davr:"2026 yil yanvar-iyun", izoh:null},
  {code:"IND_UZUM", name:"Uzum (tokzorlar)", turi:"mahsulot", soha:"dehqonchilik", guruh:"asosiy", olchov_birligi:"U_TONNA", satr_1ilova:"107", satr_2ilova:"207", satr_3ilova:"307", hajm_2026:599.8, hajm_birligi:"ming tonna", qiymat_2026_mlrd_som:6560.2, osish_foiz:101.9, deflyator_foiz:99.3, davr:"2026 yil yanvar-iyun", izoh:"SNSga faylining ayrim varaqlarida o‘sish sur’ati to‘ldirilmagan — sverka talab etiladi"},
  {code:"IND_DEH_BOSHQA", name:"Dehqonchilikning boshqa mahsulotlari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", olchov_birligi:"U_MING_SOM", satr_1ilova:"—", satr_2ilova:"208", satr_3ilova:"308", hajm_2026:null, hajm_birligi:null, qiymat_2026_mlrd_som:10532.2, osish_foiz:102.3, deflyator_foiz:94.2, davr:"2026 yil yanvar-iyun", izoh:"4-ilovaning 401-452-satrlari; choraklikda 56-band formulasi bo‘yicha"},
  {code:"IND_GOSHT", name:"Go‘sht, tirik vaznda", turi:"mahsulot", soha:"chorvachilik", guruh:"asosiy", olchov_birligi:"U_TONNA", satr_1ilova:"108", satr_2ilova:"209", satr_3ilova:"309", hajm_2026:1299.0, hajm_birligi:"ming tonna", qiymat_2026_mlrd_som:89408.4, osish_foiz:100.9, deflyator_foiz:125.5, davr:"2026 yil yanvar-iyun", izoh:null},
  {code:"IND_SUT", name:"Sut", turi:"mahsulot", soha:"chorvachilik", guruh:"asosiy", olchov_birligi:"U_TONNA", satr_1ilova:"109", satr_2ilova:"210", satr_3ilova:"310", hajm_2026:5096.4, hajm_birligi:"ming tonna", qiymat_2026_mlrd_som:41843.0, osish_foiz:101.5, deflyator_foiz:142.0, davr:"2026 yil yanvar-iyun", izoh:"Hududiy deflyatorlarda anomaliya: Sirdaryo 718,9 %, Namangan 411,9 %, Xorazm 61,4 % — tekshiruv talab etiladi"},
  {code:"IND_TUXUM", name:"Tuxum", turi:"mahsulot", soha:"chorvachilik", guruh:"asosiy", olchov_birligi:"U_MLN_DONA", satr_1ilova:"110", satr_2ilova:"211", satr_3ilova:"311", hajm_2026:4915.6, hajm_birligi:"mln dona", qiymat_2026_mlrd_som:4186.7, osish_foiz:113.8, deflyator_foiz:113.7, davr:"2026 yil yanvar-iyun", izoh:null},
  {code:"IND_JUN", name:"Jun", turi:"mahsulot", soha:"chorvachilik", guruh:"asosiy", olchov_birligi:"U_TONNA", satr_1ilova:"111", satr_2ilova:"212", satr_3ilova:"312", hajm_2026:20627.0, hajm_birligi:"tonna", qiymat_2026_mlrd_som:12.0, osish_foiz:105.2, deflyator_foiz:109.2, davr:"2026 yil yanvar-iyun", izoh:null},
  {code:"IND_QORAKOL", name:"Qorako‘l teri", turi:"mahsulot", soha:"chorvachilik", guruh:"asosiy", olchov_birligi:"U_MING_DONA", satr_1ilova:"112", satr_2ilova:"213", satr_3ilova:"313", hajm_2026:599.9, hajm_birligi:"ming dona", qiymat_2026_mlrd_som:27.8, osish_foiz:101.8, deflyator_foiz:164.9, davr:"2026 yil yanvar-iyun", izoh:"Jizzaxda deflyator 529,6 % — tekshiruv talab etiladi"},
  {code:"IND_ASAL", name:"Tabiiy asal", turi:"mahsulot", soha:"chorvachilik", guruh:"asosiy", olchov_birligi:"U_TONNA", satr_1ilova:"113", satr_2ilova:"214", satr_3ilova:"314", hajm_2026:null, hajm_birligi:null, qiymat_2026_mlrd_som:null, osish_foiz:null, deflyator_foiz:null, davr:"2026 yil yanvar-iyun", izoh:"18-bandga ko‘ra asosiy tur, ammo SNSga faylida alohida ajratilmagan — \"boshqa\" tarkibida hisoblangan"},
  {code:"IND_BALIQ", name:"Baliq", turi:"mahsulot", soha:"baliqchilik", guruh:"asosiy", olchov_birligi:"U_TONNA", satr_1ilova:"114", satr_2ilova:"—", satr_3ilova:"—", hajm_2026:null, hajm_birligi:null, qiymat_2026_mlrd_som:null, osish_foiz:null, deflyator_foiz:null, davr:"2026 yil yanvar-iyun", izoh:"Qiymati 03-bo‘lim tarkibida baholanadi (29, 46-bandlar); 4-ilovaning 470-471-satrlari"},
  {code:"IND_PILLA", name:"Pilla", turi:"mahsulot", soha:"chorvachilik", guruh:"asosiy", olchov_birligi:"U_TONNA", satr_1ilova:"115", satr_2ilova:"215", satr_3ilova:"315", hajm_2026:31.1, hajm_birligi:"ming tonna", qiymat_2026_mlrd_som:1088.0, osish_foiz:103.5, deflyator_foiz:105.5, davr:"2026 yil yanvar-iyun", izoh:"Manba: \"3 pilla\" shakli (57-band)"},
  {code:"IND_CHOR_BOSHQA", name:"Chorvachilikning boshqa mahsulotlari", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", olchov_birligi:"U_MING_SOM", satr_1ilova:"—", satr_2ilova:"216", satr_3ilova:"316", hajm_2026:null, hajm_birligi:null, qiymat_2026_mlrd_som:11322.6, osish_foiz:100.9, deflyator_foiz:120.8, davr:"2026 yil yanvar-iyun", izoh:"4-ilovaning 453-469-satrlari"},
  {code:"IND_I", name:"Dehqonchilik mahsulotlarining qiymati", turi:"agregat", soha:"dehqonchilik", guruh:"agregat", olchov_birligi:"U_MLRD_SOM", satr_2ilova:"I", satr_3ilova:"I", qiymat_2026_mlrd_som:106198.2, osish_foiz:106.7, deflyator_foiz:97.6, ulush_foiz:41.8, davr:"2026 yil yanvar-iyun", izoh:"2-ilova, 201-208-satrlar yig‘indisi"},
  {code:"IND_II", name:"Chorvachilik mahsulotlarining qiymati", turi:"agregat", soha:"chorvachilik", guruh:"agregat", olchov_birligi:"U_MLRD_SOM", satr_2ilova:"II", satr_3ilova:"II", qiymat_2026_mlrd_som:147888.4, osish_foiz:101.3, deflyator_foiz:128.8, ulush_foiz:58.2, davr:"2026 yil yanvar-iyun", izoh:"2-ilova, 209-216-satrlar yig‘indisi"},
  {code:"IND_III", name:"Dehqonchilikda tugallanmagan ishlab chiqarish qiymati", turi:"agregat", soha:"dehqonchilik", guruh:"agregat", olchov_birligi:"U_MLRD_SOM", satr_2ilova:"III", satr_3ilova:"III", qiymat_2026_mlrd_som:null, osish_foiz:null, deflyator_foiz:null, ulush_foiz:null, davr:"2026 yil yanvar-iyun", izoh:"N = z(kuz) × pl(kuz), 21-band; choraklikda o‘tgan yil ulushi bo‘yicha (55-band). 2026 yanvar-iyun uchun jadvalda ajratilmagan"},
  {code:"IND_IV", name:"Dehqonchilik va chorvachilik sohasidagi xizmatlar qiymati", turi:"agregat", soha:"xizmat", guruh:"agregat", olchov_birligi:"U_MLRD_SOM", satr_2ilova:"IV", satr_3ilova:"IV", qiymat_2026_mlrd_som:3928.6, osish_foiz:169.9, deflyator_foiz:116.4, ulush_foiz:null, davr:"2026 yil yanvar-iyun", izoh:"Bozor + nobozor xizmatlari (23-band)"},
  {code:"IND_V", name:"Dehqonchilik va chorvachilik mahsulot (xizmat)lari yalpi ishlab chiqarishi", turi:"agregat", soha:"qishloq xo‘jaligi", guruh:"agregat", olchov_birligi:"U_MLRD_SOM", satr_2ilova:"V", satr_3ilova:"V", qiymat_2026_mlrd_som:258015.2, osish_foiz:null, deflyator_foiz:null, ulush_foiz:null, davr:"2026 yil yanvar-iyun", izoh:"I+II+III+IV (24-band); qiymat 2-ilova mantig‘i asosida hisoblangan (III = 0)"},
  {code:"IND_VI", name:"Ovchilik xo‘jaligida yetishtirilgan mahsulot (xizmat)lar qiymati", turi:"agregat", soha:"ovchilik", guruh:"agregat", olchov_birligi:"U_MLRD_SOM", satr_2ilova:"VI", satr_3ilova:"VI", qiymat_2026_mlrd_som:7.3, osish_foiz:166.4, deflyator_foiz:100.1, ulush_foiz:null, davr:"2026 yil yanvar-iyun", izoh:"25-band"},
  {code:"IND_VII", name:"A seksiya 01-bo‘lim — Dehqonchilik va chorvachilik, ovchilik va bu sohalarda xizmat ko‘rsatish", turi:"agregat", soha:"01-bo‘lim", guruh:"agregat", olchov_birligi:"U_MLRD_SOM", satr_2ilova:"VII", satr_3ilova:"VII", qiymat_2026_mlrd_som:258022.5, osish_foiz:104.5, deflyator_foiz:113.7, ulush_foiz:94.0, davr:"2026 yil yanvar-iyun", izoh:"V+VI (26-band). \"Respublika\" varag‘ida 254 679,6 mlrd so‘m va deflyator 112,2 % — sverka farqi 3 342,9 mlrd so‘m"},
  {code:"IND_VIII", name:"A seksiya 02-bo‘lim — O‘rmonchilik va yog‘och tayyorlash", turi:"agregat", soha:"02-bo‘lim", guruh:"agregat", olchov_birligi:"U_MLRD_SOM", satr_2ilova:"VIII", satr_3ilova:"VIII", qiymat_2026_mlrd_som:14338.2, osish_foiz:106.6, deflyator_foiz:105.3, ulush_foiz:5.3, davr:"2026 yil yanvar-iyun", izoh:"27-28-bandlar; taqqoslama narx — 45-band (ekstrapolyatsiya)"},
  {code:"IND_IX", name:"A seksiya 03-bo‘lim — Baliq ovlash va akvakultura", turi:"agregat", soha:"03-bo‘lim", guruh:"agregat", olchov_birligi:"U_MLRD_SOM", satr_2ilova:"IX", satr_3ilova:"IX", qiymat_2026_mlrd_som:1934.6, osish_foiz:135.6, deflyator_foiz:111.4, ulush_foiz:0.7, davr:"2026 yil yanvar-iyun", izoh:"29-band; taqqoslama narx — 46-band (ekstrapolyatsiya)"},
  {code:"IND_X", name:"A seksiya — Qishloq, o‘rmon va baliqchilik xo‘jaligi mahsulot (xizmat)lari yalpi ishlab chiqarishi", turi:"agregat", soha:"A seksiya", guruh:"agregat", olchov_birligi:"U_MLRD_SOM", satr_2ilova:"X", satr_3ilova:"X", qiymat_2026_mlrd_som:270952.3, osish_foiz:104.7, deflyator_foiz:111.8, ulush_foiz:100.0, davr:"2026 yil yanvar-iyun", izoh:"VII+VIII+IX (30-band). 2025 y. bazis 231 346,5; taqqoslama narxlarda 2026 y. 242 314,3 mlrd so‘m. \"valovka\" varag‘ida 274 295,5 va deflyator 113,2 % — sverka talab etiladi"},
  {code:"IND_X", qiymat_2025_mlrd_som:231346.5, qiymat_2026_taqqoslama_mlrd_som:242314.3, nominal_ozgarish_foiz:117.1, qiymat_2026_valovka_mlrd_som:274295.5},
  {code:"IND_XIZMAT_BOZOR", name:"Bozor xizmatlari qiymati", turi:"komponent", soha:"xizmat", olchov_birligi:"U_MLRD_SOM", qiymat_2026_mlrd_som:null, osish_foiz:null, deflyator_foiz:null, davr:"2026 yil yanvar-iyun", izoh:"23-band; jami xizmatlar (3 928,6) tarkibida, alohida ajratilmagan"},
  {code:"IND_XIZMAT_NOBOZOR", name:"Nobozor (davlat budjetidan moliyalashtiriladigan) xizmatlar qiymati", turi:"komponent", soha:"xizmat", olchov_birligi:"U_MLRD_SOM", qiymat_2026_mlrd_som:1625.5, osish_foiz:128.5, deflyator_foiz:116.4, davr:"2026 yil yanvar-iyun", izoh:"23, 28-bandlar; manba — davlat budjeti ijrosi hisoboti"},
  {code:"IND_NOBOZOR_ORMON", name:"02-bo‘lim bo‘yicha nobozor (budjet) xizmatlari", turi:"komponent", soha:"02-bo‘lim", olchov_birligi:"U_MLRD_SOM", qiymat_2026_mlrd_som:189.5, osish_foiz:93.0, deflyator_foiz:116.4, davr:"2026 yil yanvar-iyun", izoh:"28-band"},
  {code:"IND_FHI", name:"Fizik hajm indeksi (FHI, Paashe)", turi:"indeks", soha:"A seksiya", olchov_birligi:"U_FOIZ", qiymat_foiz:104.7, hisoblash:"Σq1p0 / Σq0p0 × 100 = 242 314,3 / 231 346,5 × 100", asos_band:"37-41-bandlar", davr:"2026 yil yanvar-iyun"},
  {code:"IND_DEFLYATOR", name:"Deflyator indeksi", turi:"indeks", soha:"A seksiya", olchov_birligi:"U_FOIZ", qiymat_foiz:111.8, hisoblash:"Σq1p1 / Σq1p0 × 100 = 270 952,3 / 242 314,3 × 100", asos_band:"2-ilova", davr:"2026 yil yanvar-iyun"},
  {code:"IND_NOMINAL", name:"Nominal o‘zgarish indeksi", turi:"indeks", soha:"A seksiya", olchov_birligi:"U_FOIZ", qiymat_foiz:117.1, hisoblash:"Σq1p1 / Σq0p0 × 100 = 270 952,3 / 231 346,5 × 100; tekshiruv: 1,047 × 1,118 = 1,171", asos_band:"—", davr:"2026 yil yanvar-iyun"},
  {code:"IND_401", name:"sholi ko‘chatlari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"401", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_402", name:"kanop poyasi", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"402", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_403", name:"zig‘ir poyasi", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"403", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_404", name:"shakar qamish", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"404", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_405", name:"qand lavlagi", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"405", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_406", name:"supurgi jo‘xori", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"406", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_407", name:"tamaki", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"407", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_408", name:"don uchun kungaboqar", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"408", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_409", name:"zig‘ir urug‘i", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"409", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_410", name:"soya", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"410", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_411", name:"raps", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"411", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_412", name:"kunjut", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"412", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_413", name:"maxsar", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"413", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_414", name:"eryong‘oq", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"414", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_415", name:"urug‘lik paxta chigiti", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"415", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_416", name:"paxta chigiti, urug‘likdan tashqari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"416", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_417", name:"g‘o‘zapoya", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"417", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_418", name:"xantal", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"418", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_419", name:"ko‘knor", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"419", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_420", name:"kanop urug‘i", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"420", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_421", name:"tut barglari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"421", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_422", name:"ishlov berilmagan qalampir", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"422", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_423", name:"quritilgan, ishlov berilmagan achchiq va shirin butun qalampir", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"423", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_424", name:"ishlov berilmagan muskat yong‘og‘i, matsis va kardamon", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"424", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_425", name:"ishlov berilmagan arpabodiyon, bodiyon, kashnich, kmin, sedana, ziralarning urug‘lari va archa mevasi", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"425", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_426", name:"ishlov berilmagan dolchin (dolchin daraxtining po‘stlog‘i va gullari)", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"426", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_427", name:"ishlov berilmagan qalampirmunchoq (butun poyasi)", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"427", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_428", name:"ishlov berilmagan vanil", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"428", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_429", name:"ishlov berilmagan boshqa ziravorlar", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"429", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_430", name:"qulmoq (xmel) g‘uddasi", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"430", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_431", name:"steviya", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"431", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_432", name:"boshqa ziravor va dorivor ekinlar", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"432", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_433", name:"maniok (kassava)", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"433", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_434", name:"sabzavot ekinlari ko‘chatlari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"434", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_435", name:"sabzavot ekinlari urug‘lari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"435", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_436", name:"poliz ekinlari ko‘chatlari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"436", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_437", name:"poliz ekinlari urug‘lari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"437", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_438", name:"ozuqabop ildizmevalilar va poliz", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"438", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_439", name:"makkajo‘xori silos uchun", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"439", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_440", name:"bir yillik o‘tlar", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"440", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_441", name:"ko‘p yillik o‘tlar", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"441", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_442", name:"senaj uchun ekinlar", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"442", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_443", name:"don uchun yig‘ib olingan don ekinlari somoni, paxoli, poyasi", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"443", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_444", name:"quritilgan dukkakli yem-xashak ekinlari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"444", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_445", name:"ozuqabop lavlagi urug‘i", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"445", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_446", name:"ozuqa ekinlari urug‘lari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"446", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_447", name:"kesib olingan gullar va gul g‘unchalari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"447", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_448", name:"gul urug‘lari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"448", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_449", name:"gul ko‘chatlari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"449", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_450", name:"hosil beradigan yoshigacha ko‘p yillik yosh ko‘chatlarni o‘stirish", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"450", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_451", name:"tugallanmagan ishlab chiqarish qiymati", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"451", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_452", name:"yuqoridagi ro‘yxatga va asosiy mahsulotlar ro‘yxatiga qo‘shilmagan boshqa dehqonchilik mahsulotlari", turi:"mahsulot", soha:"dehqonchilik", guruh:"boshqa", satr_4ilova:"452", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_453", name:"mo‘ynali hayvonlar‒mo‘yna xomashyosi, quyon terisidan tashqari, jami", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"453", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_454", name:"quyonlar ‒ mo‘yna xomashyosi", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"454", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_455", name:"asalari oilalari", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"455", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_456", name:"asalari mumi", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"456", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_457", name:"gul changi", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"457", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_458", name:"ona asalari suti", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"458", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_459", name:"propolis", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"459", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_460", name:"asalari zahari", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"460", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_461", name:"qishloq xo‘jaligi hayvonlari va parrandalarining spermasi (maniy)", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"461", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_462", name:"qishloq xo‘jaligi hayvonlarining embrionlari", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"462", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_463", name:"ipak qurti tuxumi", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"463", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_464", name:"par", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"464", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_465", name:"pat", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"465", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_466", name:"qishloq xo‘jaligi hayvonlari va parrandalari nasli", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"466", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_467", name:"tirik qishloq xo‘jalik sudralib yuruvchilari – ilonlar", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"467", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_468", name:"tirik qishloq xo‘jalik sudralib yuruvchilari – toshbaqalar", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"468", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_469", name:"hayvonlardan olinadigan noozuqaviy mahsulotlar (go‘ng, axlat va boshqalar)", turi:"mahsulot", soha:"chorvachilik", guruh:"boshqa", satr_4ilova:"469", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_470", name:"shu yillik baliqlar", turi:"mahsulot", soha:"baliqchilik", guruh:"boshqa", satr_4ilova:"470", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"},
  {code:"IND_471", name:"bir yillik baliqlar", turi:"mahsulot", soha:"baliqchilik", guruh:"boshqa", satr_4ilova:"471", olchov_birligi:"U_TONNA", izoh:"4-ilova — asosiy turlar guruhiga kiritilmagan boshqa turdagi mahsulot"}
] AS row
MERGE (i:Indicator {code: row.code}) SET i += row;
// =====================================================================
// 17. BOG'LANISHLAR (rasmdagi 11 ta asosiy relationship)
// =====================================================================

// ---------------------------------------------------------------------
// 17.1 MEASURED_IN : Indicator -> Unit   (qo'shimcha bog'lanish)
// ---------------------------------------------------------------------
MATCH (i:Indicator) WHERE i.olchov_birligi IS NOT NULL
MATCH (u:Unit {code: i.olchov_birligi})
MERGE (i)-[:MEASURED_IN]->(u);

// ---------------------------------------------------------------------
// 17.2 USES_PRICE : Indicator -> Price
// ---------------------------------------------------------------------
// Barcha mahsulot ko'rsatkichlari ikkita narx bilan baholanadi (p1 va p0)
MATCH (i:Indicator {turi:'mahsulot'}), (p:Price)
WHERE p.code IN ['PRICE_JORIY','PRICE_TAQQOSLAMA']
MERGE (i)-[r:USES_PRICE]->(p)
SET r.maqsad = CASE p.code WHEN 'PRICE_JORIY' THEN 'joriy narxlarda baholash (14-band)'
                           ELSE 'taqqoslama narxlarda qayta baholash (34-band)' END;

// Narx manbasi bo'yicha aniqlashtirish
MATCH (i:Indicator), (p:Price {code:'PRICE_ISHLAB_CHIQ'})
WHERE i.code IN ['IND_DON','IND_PAXTA']
MERGE (i)-[:USES_PRICE {maqsad:'ishlab chiqaruvchi narxi (58, 59-bandlar)'}]->(p);

MATCH (i:Indicator {turi:'mahsulot'}), (p:Price {code:'PRICE_BOZOR'})
WHERE NOT i.code IN ['IND_DON','IND_PAXTA','IND_PILLA']
MERGE (i)-[:USES_PRICE {maqsad:'dehqon bozori narxlari blankasi (60-band)'}]->(p);

MATCH (i:Indicator {turi:'mahsulot'}), (p:Price {code:'PRICE_ORT_SOTISH'})
MERGE (i)-[:USES_PRICE {maqsad:'o‘rtacha sotish narxi (14-band)'}]->(p);

// F_42 — boshqa turdagi mahsulotlarni asosiy turlar FHI si bo'yicha qayta hisoblash
MERGE (f:Formula {code:'F_42'})
SET f.name='S(boshq, taqqos) = S(boshq, bazis) × FHI(asosiy tur)',
    f.ifoda='S(boshq, taqqos) = S(boshq, bazis) × FHI(asosiy tur)',
    f.mazmun='Boshqa turdagi mahsulotlarni taqqoslama narxlarda indeks ko‘chirish usulida qayta hisoblash',
    f.asos_band=42, f.turi='taqqoslama narx';
MATCH (f:Formula {code:'F_42'}), (p:Paragraph {number:42}) MERGE (f)-[:DEFINED_IN]->(p);

// ---------------------------------------------------------------------
// 17.3 USES_FORMULA : Indicator -> Formula
// ---------------------------------------------------------------------
UNWIND [
  {i:"IND_DON", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_DON", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_PAXTA", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_PAXTA", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_KARTOSHKA", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_KARTOSHKA", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_SABZAVOT", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_SABZAVOT", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_POLIZ", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_POLIZ", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_MEVA", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_MEVA", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_UZUM", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_UZUM", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_GOSHT", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_GOSHT", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_SUT", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_SUT", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_TUXUM", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_TUXUM", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_JUN", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_JUN", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_QORAKOL", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_QORAKOL", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_ASAL", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_ASAL", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_PILLA", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_PILLA", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_BALIQ", f:"F_14", m:"joriy narxlarda baholash"},
  {i:"IND_BALIQ", f:"F_34", m:"taqqoslama narxlarda qayta baholash"},
  {i:"IND_DEH_BOSHQA", f:"F_56", m:"choraklik hisoblash"},
  {i:"IND_DEH_BOSHQA", f:"F_42", m:"asosiy turlar FHI si bo‘yicha qayta hisoblash"},
  {i:"IND_CHOR_BOSHQA", f:"F_56", m:"choraklik hisoblash"},
  {i:"IND_I", f:"F_16", m:"joriy narxlarda jamlash"},
  {i:"IND_I", f:"F_36", m:"taqqoslama narxlarda jamlash"},
  {i:"IND_II", f:"F_16", m:"joriy narxlarda jamlash"},
  {i:"IND_II", f:"F_36", m:"taqqoslama narxlarda jamlash"},
  {i:"IND_III", f:"F_21", m:"joriy narxlarda"},
  {i:"IND_III", f:"F_43", m:"taqqoslama narxlarda"},
  {i:"IND_III", f:"F_55", m:"choraklarga taqsimlash"},
  {i:"IND_IV", f:"F_23", m:"joriy narxlarda"},
  {i:"IND_IV", f:"F_44", m:"taqqoslama narxlarda ekstrapolyatsiya"},
  {i:"IND_V", f:"F_24", m:"01-bo‘lim yadrosi"},
  {i:"IND_VI", f:"F_44", m:"taqqoslama narxlarda ekstrapolyatsiya"},
  {i:"IND_VII", f:"F_26", m:"01-bo‘lim yakuniy hisobi"},
  {i:"IND_VIII", f:"F_45", m:"taqqoslama narxlarda ekstrapolyatsiya"},
  {i:"IND_IX", f:"F_46", m:"taqqoslama narxlarda ekstrapolyatsiya"},
  {i:"IND_X", f:"F_30", m:"A seksiya bo‘yicha yakuniy hisob"},
  {i:"IND_FHI", f:"F_38", m:"Paashe indeksi"},
  {i:"IND_FHI", f:"F_41", m:"umumiy indeks, % da"},
  {i:"IND_DEFLYATOR", f:"F_DEFLYATOR", m:"joriy/taqqoslama nisbati"},
  {i:"IND_NOMINAL", f:"F_NOMINAL", m:"tekshiruv ayniyati"},
  {i:"IND_SABZAVOT", f:"F_61", m:"choraklik taqsimlash"},
  {i:"IND_421", f:"F_TUT_BARGI", m:"normativ hisob (6-ilova)"},
  {i:"IND_443", f:"F_POXOL", m:"normativ hisob (6-ilova)"},
  {i:"IND_417", f:"F_GOZAPOYA", m:"normativ hisob (6-ilova)"},
  {i:"IND_469", f:"F_73", m:"diskret choraklar yig‘indisi"}
] AS row
MATCH (i:Indicator {code: row.i}), (f:Formula {code: row.f})
MERGE (i)-[r:USES_FORMULA]->(f) SET r.maqsad = row.m;

// ---------------------------------------------------------------------
// 17.4 CALCULATED_FROM : Indicator -> Indicator (agregatsiya daraxti)
// ---------------------------------------------------------------------
UNWIND [
  {a:"IND_I", b:"IND_DON", m:"2-ilova 201-208-satrlar"},
  {a:"IND_I", b:"IND_PAXTA", m:"2-ilova 201-208-satrlar"},
  {a:"IND_I", b:"IND_KARTOSHKA", m:"2-ilova 201-208-satrlar"},
  {a:"IND_I", b:"IND_SABZAVOT", m:"2-ilova 201-208-satrlar"},
  {a:"IND_I", b:"IND_POLIZ", m:"2-ilova 201-208-satrlar"},
  {a:"IND_I", b:"IND_MEVA", m:"2-ilova 201-208-satrlar"},
  {a:"IND_I", b:"IND_UZUM", m:"2-ilova 201-208-satrlar"},
  {a:"IND_I", b:"IND_DEH_BOSHQA", m:"2-ilova 201-208-satrlar"},
  {a:"IND_II", b:"IND_GOSHT", m:"2-ilova 209-216-satrlar"},
  {a:"IND_II", b:"IND_SUT", m:"2-ilova 209-216-satrlar"},
  {a:"IND_II", b:"IND_TUXUM", m:"2-ilova 209-216-satrlar"},
  {a:"IND_II", b:"IND_JUN", m:"2-ilova 209-216-satrlar"},
  {a:"IND_II", b:"IND_QORAKOL", m:"2-ilova 209-216-satrlar"},
  {a:"IND_II", b:"IND_ASAL", m:"2-ilova 209-216-satrlar"},
  {a:"IND_II", b:"IND_PILLA", m:"2-ilova 209-216-satrlar"},
  {a:"IND_II", b:"IND_CHOR_BOSHQA", m:"2-ilova 209-216-satrlar"},
  {a:"IND_IV", b:"IND_XIZMAT_BOZOR", m:"23-band"},
  {a:"IND_IV", b:"IND_XIZMAT_NOBOZOR", m:"23-band"},
  {a:"IND_V", b:"IND_I", m:"24-band"},
  {a:"IND_V", b:"IND_II", m:"24-band"},
  {a:"IND_V", b:"IND_III", m:"24-band"},
  {a:"IND_V", b:"IND_IV", m:"24-band"},
  {a:"IND_VII", b:"IND_V", m:"26-band"},
  {a:"IND_VII", b:"IND_VI", m:"26-band"},
  {a:"IND_VIII", b:"IND_NOBOZOR_ORMON", m:"28-band"},
  {a:"IND_IX", b:"IND_BALIQ", m:"29-band"},
  {a:"IND_X", b:"IND_VII", m:"30-band"},
  {a:"IND_X", b:"IND_VIII", m:"30-band"},
  {a:"IND_X", b:"IND_IX", m:"30-band"},
  {a:"IND_FHI", b:"IND_X", m:"38, 41-bandlar"},
  {a:"IND_DEFLYATOR", b:"IND_X", m:"2-ilova"},
  {a:"IND_NOMINAL", b:"IND_FHI", m:"tekshiruv ayniyati"},
  {a:"IND_NOMINAL", b:"IND_DEFLYATOR", m:"tekshiruv ayniyati"}
] AS row
MATCH (a:Indicator {code: row.a}), (b:Indicator {code: row.b})
MERGE (a)-[r:CALCULATED_FROM]->(b) SET r.asos = row.m;

// 4-ilova mahsulotlari -> "boshqa mahsulotlar" agregatlariga
MATCH (b:Indicator) WHERE b.satr_4ilova IS NOT NULL AND toInteger(b.satr_4ilova) <= 452
MATCH (a:Indicator {code:'IND_DEH_BOSHQA'}) MERGE (a)-[:CALCULATED_FROM {asos:'4-ilova'}]->(b);
MATCH (b:Indicator) WHERE b.satr_4ilova IS NOT NULL AND toInteger(b.satr_4ilova) >= 453 AND toInteger(b.satr_4ilova) <= 469
MATCH (a:Indicator {code:'IND_CHOR_BOSHQA'}) MERGE (a)-[:CALCULATED_FROM {asos:'4-ilova'}]->(b);
MATCH (b:Indicator) WHERE b.satr_4ilova IN ['470','471']
MATCH (a:Indicator {code:'IND_IX'}) MERGE (a)-[:CALCULATED_FROM {asos:'4-ilova, 470-471-satrlar'}]->(b);

// ---------------------------------------------------------------------
// 17.5 DEFINED_IN : Indicator -> Paragraph
// ---------------------------------------------------------------------
UNWIND [
  {i:"IND_X", p:5},
  {i:"IND_X", p:6},
  {i:"IND_X", p:30},
  {i:"IND_VII", p:5},
  {i:"IND_VII", p:24},
  {i:"IND_VII", p:26},
  {i:"IND_VIII", p:5},
  {i:"IND_VIII", p:27},
  {i:"IND_VIII", p:28},
  {i:"IND_VIII", p:45},
  {i:"IND_IX", p:5},
  {i:"IND_IX", p:29},
  {i:"IND_IX", p:46},
  {i:"IND_V", p:24},
  {i:"IND_VI", p:25},
  {i:"IND_VI", p:44},
  {i:"IND_I", p:14},
  {i:"IND_I", p:15},
  {i:"IND_I", p:16},
  {i:"IND_I", p:17},
  {i:"IND_I", p:18},
  {i:"IND_I", p:22},
  {i:"IND_II", p:14},
  {i:"IND_II", p:15},
  {i:"IND_II", p:16},
  {i:"IND_II", p:17},
  {i:"IND_II", p:18},
  {i:"IND_II", p:22},
  {i:"IND_III", p:21},
  {i:"IND_III", p:43},
  {i:"IND_III", p:55},
  {i:"IND_IV", p:23},
  {i:"IND_IV", p:44},
  {i:"IND_XIZMAT_BOZOR", p:23},
  {i:"IND_XIZMAT_NOBOZOR", p:23},
  {i:"IND_NOBOZOR_ORMON", p:28},
  {i:"IND_DEH_BOSHQA", p:19},
  {i:"IND_DEH_BOSHQA", p:42},
  {i:"IND_DEH_BOSHQA", p:56},
  {i:"IND_CHOR_BOSHQA", p:20},
  {i:"IND_CHOR_BOSHQA", p:42},
  {i:"IND_CHOR_BOSHQA", p:56},
  {i:"IND_FHI", p:37},
  {i:"IND_FHI", p:38},
  {i:"IND_FHI", p:39},
  {i:"IND_FHI", p:40},
  {i:"IND_FHI", p:41},
  {i:"IND_DEFLYATOR", p:32},
  {i:"IND_DEFLYATOR", p:33},
  {i:"IND_NOMINAL", p:37},
  {i:"IND_DON", p:18},
  {i:"IND_DON", p:58},
  {i:"IND_DON", p:61},
  {i:"IND_PAXTA", p:18},
  {i:"IND_PAXTA", p:52},
  {i:"IND_PAXTA", p:59},
  {i:"IND_KARTOSHKA", p:18},
  {i:"IND_KARTOSHKA", p:51},
  {i:"IND_SABZAVOT", p:18},
  {i:"IND_SABZAVOT", p:61},
  {i:"IND_POLIZ", p:18},
  {i:"IND_POLIZ", p:61},
  {i:"IND_MEVA", p:18},
  {i:"IND_MEVA", p:51},
  {i:"IND_MEVA", p:61},
  {i:"IND_UZUM", p:18},
  {i:"IND_UZUM", p:52},
  {i:"IND_UZUM", p:61},
  {i:"IND_GOSHT", p:18},
  {i:"IND_GOSHT", p:61},
  {i:"IND_GOSHT", p:73},
  {i:"IND_SUT", p:18},
  {i:"IND_TUXUM", p:18},
  {i:"IND_JUN", p:18},
  {i:"IND_QORAKOL", p:18},
  {i:"IND_ASAL", p:18},
  {i:"IND_PILLA", p:18},
  {i:"IND_PILLA", p:57},
  {i:"IND_BALIQ", p:29},
  {i:"IND_BALIQ", p:46}
] AS row
MATCH (i:Indicator {code: row.i}), (p:Paragraph {number: row.p})
MERGE (i)-[:DEFINED_IN]->(p);

// 4-ilova mahsulotlari 19 va 20-bandlarda ta'riflangan
MATCH (i:Indicator) WHERE i.satr_4ilova IS NOT NULL AND i.soha='dehqonchilik'
MATCH (p:Paragraph {number:19}) MERGE (i)-[:DEFINED_IN]->(p);
MATCH (i:Indicator) WHERE i.satr_4ilova IS NOT NULL AND i.soha='chorvachilik'
MATCH (p:Paragraph {number:20}) MERGE (i)-[:DEFINED_IN]->(p);

// ---------------------------------------------------------------------
// 17.6 REPORTED_IN : Indicator -> Report
// ---------------------------------------------------------------------
MATCH (i:Indicator), (r:Report)
WHERE i.turi IN ['mahsulot','agregat','komponent','indeks']
  AND r.code IN ['REP_CHORAK','REP_YILLIK']
MERGE (i)-[:REPORTED_IN]->(r);

MATCH (i:Indicator), (r:Report {code:'REP_DISKRET'})
WHERE i.turi IN ['mahsulot','agregat'] AND i.guruh <> 'boshqa'
MERGE (i)-[:REPORTED_IN {asos:'5-bob, 69-77-bandlar'}]->(r);

// 2026 yil yanvar-iyun haqiqiy natijalari SNSga faylida aks etgan
MATCH (i:Indicator), (r:Report {code:'REP_SNSGA'})
WHERE i.qiymat_2026_mlrd_som IS NOT NULL OR i.qiymat_foiz IS NOT NULL
MERGE (i)-[:REPORTED_IN {davr:'2026 yil yanvar-iyun'}]->(r);

// ---------------------------------------------------------------------
// 17.7 Qo'shimcha bog'lanishlar: Department / System / Appendix
// ---------------------------------------------------------------------
MATCH (d:Department {code:'DEP_QX_STAT'}), (m:Methodology {code:'MET_YAICH'})
MERGE (d)-[:RESPONSIBLE_FOR]->(m);
MATCH (d:Department {code:'DEP_MILLIY_HISOB'}), (i:Indicator {code:'IND_X'})
MERGE (d)-[:RESPONSIBLE_FOR]->(i);
MATCH (d:Department {code:'DEP_HUDUDIY'}), (r:Report {code:'REP_CHORAK'})
MERGE (d)-[:RESPONSIBLE_FOR]->(r);
MATCH (d:Department {code:'DEP_GEO_AI'}), (s:System {code:'SYS_ESTAT4'})
MERGE (d)-[:RESPONSIBLE_FOR]->(s);

// Indicator -> Appendix (qaysi ilovada aks etgan)
MATCH (i:Indicator) WHERE i.satr_1ilova IS NOT NULL AND i.satr_1ilova <> '—'
MATCH (a:Appendix {code:'APP_1'}) MERGE (i)-[:LISTED_IN]->(a);
MATCH (i:Indicator) WHERE i.satr_2ilova IS NOT NULL AND i.satr_2ilova <> '—'
MATCH (a:Appendix {code:'APP_2'}) MERGE (i)-[:LISTED_IN]->(a);
MATCH (i:Indicator) WHERE i.satr_3ilova IS NOT NULL AND i.satr_3ilova <> '—'
MATCH (a:Appendix {code:'APP_3'}) MERGE (i)-[:LISTED_IN]->(a);
MATCH (i:Indicator) WHERE i.satr_4ilova IS NOT NULL
MATCH (a:Appendix {code:'APP_4'}) MERGE (i)-[:LISTED_IN]->(a);
