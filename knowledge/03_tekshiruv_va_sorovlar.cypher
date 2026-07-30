// =====================================================================
//  03_tekshiruv_va_sorovlar.cypher
//  Grafni tekshirish va amaliy so'rovlar to'plami.
//  Har bir so'rovni Neo4j Browser da alohida ishga tushiring.
// =====================================================================


// =====================================================================
//  A. TEKSHIRUV (grafni yuklaganingizdan keyin)
// =====================================================================

// A1. Label bo'yicha tugunlar soni
MATCH (n) RETURN labels(n)[0] AS label, count(*) AS soni ORDER BY soni DESC;

// A2. Relationship turlari bo'yicha bog'lanishlar soni
MATCH ()-[r]->() RETURN type(r) AS bogʻlanish, count(*) AS soni ORDER BY soni DESC;

// A3. Grafning umumiy sxemasi (rasmdagi ko'rinish)
CALL db.schema.visualization();

// A4. Haqiqiy "From -> Relationship -> To" jadvali (rasmdagi o'rta ustun bilan solishtiring)
MATCH (a)-[r]->(b)
RETURN labels(a)[0] AS `From`, type(r) AS Relationship, labels(b)[0] AS `To`, count(*) AS soni
ORDER BY `From`, Relationship;

// A5. Yetim (bog'lanmagan) tugunlar bormi?
MATCH (n) WHERE NOT (n)--() RETURN labels(n) AS label, n.code AS code, n.name AS nomi;

// A6. 82 ta band to'liq yuklanganmi?
MATCH (p:Paragraph) RETURN count(p) AS bandlar_soni,
       min(p.number) AS eng_kichik, max(p.number) AS eng_katta;

// A7. Bandlar bob kesimida
MATCH (p:Paragraph)
RETURN p.chapter AS bob, p.chapter_title AS bob_nomi, count(*) AS bandlar,
       collect(p.number)[0] + '-' + collect(p.number)[-1] AS oraliq
ORDER BY bob;


// =====================================================================
//  B. MAZMUNIY TEKSHIRUV (raqamlar to'g'ri jamlanganmi?)
// =====================================================================

// B1. Vv(A) = Vv(01) + Vv(02) + Vv(03)  — 30-band
MATCH (x:Indicator {code:'IND_X'})-[:CALCULATED_FROM]->(qism:Indicator)
WITH x.qiymat_2026_mlrd_som AS jami,
     round(sum(qism.qiymat_2026_mlrd_som), 1) AS qismlar_yigindisi
RETURN jami, qismlar_yigindisi, round(jami - qismlar_yigindisi, 1) AS farq;
// Kutilayotgan natija: 270 952,3 va 274 295,3 -> farq -3 343,0
// Sabab: "Respublika" varag'i (254 679,6) va "valovka" varag'i (258 022,5)
// o'rtasidagi 01-bo'lim bo'yicha sverka farqi. Rahbariyatga taqdim etishdan
// oldin qaysi variant yakuniy ekanini aniqlashtirish zarur.

// B2. Deflyator x FHI = nominal o'zgarish (tekshiruv ayniyati)
MATCH (f:Indicator {code:'IND_FHI'}), (d:Indicator {code:'IND_DEFLYATOR'}), (n:Indicator {code:'IND_NOMINAL'})
RETURN f.qiymat_foiz AS FHI, d.qiymat_foiz AS deflyator,
       round(f.qiymat_foiz * d.qiymat_foiz / 100, 1) AS hisoblangan,
       n.qiymat_foiz AS jadvaldagi;

// B3. Dehqonchilik (I) va chorvachilik (II) yig'indisi
MATCH (i:Indicator) WHERE i.code IN ['IND_I','IND_II']
RETURN sum(i.qiymat_2026_mlrd_som) AS deh_chor_jami;   // kutilmoqda: 254 086,6

// B4. Hududlar yig'indisi respublika jamiga tengmi?
MATCH (o:Observation)-[:IN_REGION]->(r:Region)
WHERE r.code <> 'R_UZ' AND o.kesim = 'hudud'
RETURN round(sum(o.qiymat), 1) AS hududlar_yigindisi;  // kutilmoqda: ~270 952,3

// B5. Sverka va e'tibor talab qiladigan ko'rsatkichlar
MATCH (i:Indicator) WHERE i.izoh CONTAINS 'sverka' OR i.izoh CONTAINS 'tekshiruv'
RETURN i.code, i.name, i.izoh;

// B6. Anomal deflyatorlar (>130 % yoki <95 %)
MATCH (i:Indicator)
WHERE i.deflyator_foiz IS NOT NULL AND (i.deflyator_foiz > 130 OR i.deflyator_foiz < 95)
RETURN i.name, i.qiymat_2026_mlrd_som AS qiymat, i.osish_foiz AS osish,
       i.deflyator_foiz AS deflyator
ORDER BY i.deflyator_foiz DESC;


// =====================================================================
//  C. AMALIY SO'ROVLAR
// =====================================================================

// C1. Rasmdagi misol: Indicator -[USES_FORMULA]-> Formula
MATCH (i:Indicator {name:'Don ekinlari'})-[:USES_FORMULA]->(f:Formula)
RETURN i, f;

// C2. Bitta ko'rsatkichning to'liq "pasporti"
MATCH (i:Indicator {code:'IND_KARTOSHKA'})
OPTIONAL MATCH (i)-[:USES_FORMULA]->(f:Formula)
OPTIONAL MATCH (i)-[:DEFINED_IN]->(p:Paragraph)
OPTIONAL MATCH (i)-[:USES_PRICE]->(pr:Price)
OPTIONAL MATCH (i)-[:MEASURED_IN]->(u:Unit)
RETURN i.name AS korsatkich, i.qiymat_2026_mlrd_som AS qiymat_mlrd,
       i.hajm_2026 AS hajm, i.osish_foiz AS osish, i.deflyator_foiz AS deflyator,
       collect(DISTINCT f.ifoda) AS formulalar,
       collect(DISTINCT p.number) AS bandlar,
       collect(DISTINCT pr.name) AS narxlar,
       head(collect(u.name)) AS olchov;

// C3. "Bu raqam qayerdan keldi?" — to'liq manba zanjiri
MATCH (i:Indicator {code:'IND_X'})
MATCH path = (i)-[:CALCULATED_FROM*1..3]->(:Indicator)
RETURN path LIMIT 50;

// C4. Ko'rsatkichdan manbagacha: Indicator -> Report -> Table -> Column -> Source -> Organization
MATCH (i:Indicator {code:'IND_GOSHT'})-[:REPORTED_IN]->(r:Report)-[:HAS_TABLE]->(t:Table)
      -[:HAS_COLUMN]->(c:Column)-[:SOURCE_FROM]->(s:Source)-[:COLLECTED_BY]->(o:Organization)
RETURN DISTINCT i.name AS korsatkich, r.name AS hisobot, t.name AS jadval,
       c.name AS ustun, s.shakl AS shakl, s.name AS manba, o.qisqa AS tashkilot;

// C5. Huquqiy asosgacha bo'lgan zanjir (audit trail)
MATCH path = (i:Indicator {code:'IND_X'})-[:DEFINED_IN]->(:Paragraph)
             -[:BELONGS_TO]->(:Methodology)-[:REGULATED_BY]->(:LegalDocument)
RETURN path;

// C6. Qaysi band nechta ko'rsatkichga asos bo'ladi? (eng "og'ir" bandlar)
MATCH (i:Indicator)-[:DEFINED_IN]->(p:Paragraph)
RETURN p.number AS band, left(p.title, 90) AS band_mazmuni, count(i) AS korsatkichlar
ORDER BY korsatkichlar DESC LIMIT 15;

// C7. Bitta manba (shakl) o'zgarsa — nimaga ta'sir qiladi? (impact analysis)
MATCH (s:Source {code:'SRC_4DX'})<-[:SOURCE_FROM]-(c:Column)<-[:HAS_COLUMN]-(t:Table)
      <-[:HAS_TABLE]-(r:Report)<-[:REPORTED_IN]-(i:Indicator)
RETURN s.shakl AS shakl, collect(DISTINCT t.name)[0..5] AS jadvallar,
       count(DISTINCT i) AS tasirlanadigan_korsatkichlar;

// C8. Deflyator eng yuqori bo'lgan 10 ta mahsulot
MATCH (i:Indicator {turi:'mahsulot'}) WHERE i.deflyator_foiz IS NOT NULL
RETURN i.name AS mahsulot, i.qiymat_2026_mlrd_som AS qiymat_mlrd,
       i.osish_foiz AS osish, i.deflyator_foiz AS deflyator
ORDER BY i.deflyator_foiz DESC LIMIT 10;

// C9. Hududiy reyting (kengaytma qatlami kerak)
MATCH (o:Observation {kesim:'hudud'})-[:IN_REGION]->(r:Region)
WHERE r.code <> 'R_UZ'
RETURN r.name AS hudud, o.qiymat AS mlrd_som, o.osish_foiz AS osish, o.ulush_foiz AS ulush
ORDER BY o.qiymat DESC;

// C10. Ishlab chiqaruvchilar toifasi kesimi
MATCH (o:Observation)-[:BY_CATEGORY]->(c:ProducerCategory)
WHERE c.daraja = 'toifa'
RETURN c.name AS toifa, o.qiymat AS mlrd_som, o.osish_foiz AS osish
ORDER BY o.qiymat DESC;

// C11. Matn bo'yicha qidiruv (full-text) — masalan "tugallanmagan"
CALL db.index.fulltext.queryNodes('ft_paragraph', 'tugallanmagan')
YIELD node, score
RETURN node.number AS band, left(node.text, 200) AS matn, round(score, 2) AS ball
ORDER BY score DESC LIMIT 5;

// C12. LLM / RAG uchun kontekst: ko'rsatkich + band matni + formula
MATCH (i:Indicator {code:'IND_III'})-[:DEFINED_IN]->(p:Paragraph)
OPTIONAL MATCH (i)-[:USES_FORMULA]->(f:Formula)
RETURN i.name AS korsatkich,
       collect(DISTINCT p.number + '-band: ' + p.text) AS huquqiy_matn,
       collect(DISTINCT f.ifoda + '  —  ' + f.mazmun) AS formulalar;

// C13. Butun graf (kichik graf bo'lgani uchun to'liq ko'rish mumkin)
MATCH (n)-[r]->(m) RETURN n, r, m LIMIT 500;
