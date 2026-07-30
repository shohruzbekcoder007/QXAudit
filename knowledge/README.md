# YaICh bilim grafi (Neo4j) — 86-son buyruq + hisoblash arxitekturasi

Rasmdagi ontologiyaga (15 ta node label, 11 ta relationship) to'liq mos keluvchi Neo4j grafi.
Ma'lumotlar ikkita manbadan olingan:

| Manba | Nima berdi |
|---|---|
| `Buyruq_86.docx` — Uslubiy nizom | 8 bob, **82 band** (to'liq matni bilan), 7 ilova, formulalar, 14 ta axborot manbai |
| `YaICh_hisoblash_arxitekturasi.html` | 2026 yil yanvar-iyun **haqiqiy raqamlari**: qiymat, hajm, o'sish, deflyator, hudud va toifa kesimlari |

---

## 1. Fayllar va ishga tushirish tartibi

| № | Fayl | Vazifasi | Majburiymi |
|---|---|---|---|
| 1 | `01_yaich_ontologiya_core.cypher` | Rasmdagi ontologiya + barcha ma'lumotlar | **Ha** |
| 2 | `02_kengaytma_kesimlar.cypher` | Hudud / toifa / mulkchilik / davr kesimlari | Ixtiyoriy |
| 3 | `03_tekshiruv_va_sorovlar.cypher` | Tekshiruv va amaliy so'rovlar | Ixtiyoriy |

```bash
# cypher-shell orqali (Neo4j 5.x)
cat 01_yaich_ontologiya_core.cypher | cypher-shell -u neo4j -p <parol> -d neo4j
cat 02_kengaytma_kesimlar.cypher    | cypher-shell -u neo4j -p <parol> -d neo4j
```

Neo4j Browser'da ishlatsangiz — faylni ochib, `:auto` rejimisiz butun matnni joylashtiring
(Browser `;` bilan ajratilgan statementlarni ketma-ket bajaradi).

> Sintaksis Neo4j **5.x** uchun (`CREATE CONSTRAINT ... IF NOT EXISTS FOR ... REQUIRE ...`).
> 4.4 da ishlatmoqchi bo'lsangiz, constraint va fulltext index sintaksisini o'zgartirish kerak.

---

## 2. Ontologiya — rasmga moslik

### Node labellar (15/15 — rasmdagidek)

| Label | Rasmdagi izoh | Nechta | Nima bilan to'ldirildi |
|---|---|---:|---|
| `Indicator` | Statistik ko'rsatkich | 104 | 1-ilova (101-115), 2/3-ilova (201-216, 301-316), 4-ilova (401-471), agregatlar I–X, FHI/deflyator |
| `Methodology` | Metodologiya | 1 | Uslubiy nizom (8 bob, 82 band, 7 ilova) |
| `Formula` | Hisoblash formulasi | 25 | 14, 16, 21, 23, 24, 26, 30, 34, 36, 38, 41–46, 55, 56, 61, 73-bandlar + deflyator + normativlar |
| `Paragraph` | Band | 82 | Har bir bandning **to'liq matni**, bob va § bilan |
| `Table` | Jadval | 14 | 7 ilova jadvali + SNSga.xlsx varaqlari |
| `Appendix` | Ilova | 7 | 1–7-ilovalar |
| `Column` | Ustun | 30 | Ilova jadvallari va Excel varaqlarining ustunlari |
| `Source` | Axborot manbasi | 14 | 80-band: 4fx, 4dx, 4qx, 3pilla, 3don, 3paxta, 1fx, 1qx, 1kb, 1ox, 1o'x, 5 bozor narxlari, tarmoq boshqarmalari, ma'muriy manbalar |
| `Report` | Statistik hisobot | 4 | Choraklik (o'sib boruvchi), diskret choraklik, yillik yakuniy, SNSga jamlanmasi |
| `Price` | Narx turi | 5 | Joriy (p₁), taqqoslama (p₀), o'rtacha sotish, ishlab chiqaruvchi, bozor narxi |
| `Unit` | O'lchov birligi | 16 | tonna, ming dona, mlrd so'm, so'm/kg, foiz va h.k. |
| `Organization` | Tashkilot | 6 | Statistika agentligi, Davlat statistika qo'mitasi, Moliya vazirligi, tarmoq idoralari, FAO, MDH Statqo'mitasi |
| `Department` | Boshqarma | 4 | Q/x statistikasi, Milliy hisoblar, Geofazoviy texnologiyalar va SI, hududiy boshqarmalar |
| `System` | eStat, Admin va boshqalar | 5 | eStat, ESTAT 4.0, ma'muriy manbalar, SNSga.xlsx, GSBPM/GSIM |
| `LegalDocument` | Buyruq, Qonun | 5 | 86-son buyruq, "Rasmiy statistika" qonuni, PQ-114, Statistika dasturi, bekor qilingan 26-son qaror |

**Jami: 322 ta tugun.**

### Relationshiplar (11/11 — rasmdagidek)

```
Indicator     -[:USES_FORMULA]->    Formula
Indicator     -[:REPORTED_IN]->     Report
Indicator     -[:DEFINED_IN]->      Paragraph
Indicator     -[:USES_PRICE]->      Price
Indicator     -[:CALCULATED_FROM]-> Indicator
Report        -[:HAS_TABLE]->       Table
Table         -[:HAS_COLUMN]->      Column
Column        -[:SOURCE_FROM]->     Source
Source        -[:COLLECTED_BY]->    Organization
Paragraph     -[:BELONGS_TO]->      Methodology
Methodology   -[:REGULATED_BY]->    LegalDocument
```

### Qo'shimcha bog'lanishlar

Rasmda `Unit`, `Appendix`, `Department`, `System` labellari bor, lekin ular uchun bog'lanish
ko'rsatilmagan. Ularni grafga ulash uchun quyidagilar qo'shildi (o'chirib tashlasangiz ham
asosiy model buzilmaydi):

`MEASURED_IN` (Indicator→Unit) · `LISTED_IN` (Indicator→Appendix) · `IN_APPENDIX` (Table→Appendix) ·
`PART_OF` (Appendix→Methodology, Department→Organization) · `RESPONSIBLE_FOR` (Department→…) ·
`COLLECTED_VIA` / `PRODUCED_IN` (→System) · `DEFINED_IN` (Formula→Paragraph) · `REPLACES` (LegalDocument→LegalDocument)

---

## 3. Rasmdagi misolning grafdagi ko'rinishi

```cypher
MATCH (i:Indicator {name:'Don ekinlari'})-[:USES_FORMULA]->(f:Formula)
RETURN i, f;
```

`Indicator` tuguni rasmdagidek xossalarga ega:

```
name = "Don ekinlari"   unit (MEASURED_IN) = tonna   satr_1ilova = "101"
qiymat_2026_mlrd_som = 22053.3   hajm_2026 = 7516.4   osish_foiz = 113.8   deflyator_foiz = 92.2
```

---

## 4. E'tibor bering: ma'lumot sifati

Graf ichida manbadagi muammolar **yashirilmagan**, aksincha `izoh` xossasida belgilangan:

* **Sverka farqi.** `Vv(A)` bo'yicha "Respublika" varag'ida 270 952,3 (deflyator 111,8 %),
  "valovka" varag'ida 274 295,5 (deflyator 113,2 %). Farq 3 343,2 mlrd so'm, deyarli to'liq
  01-bo'limda. `03_...cypher` faylidagi **B1** so'rovi buni ko'rsatadi. Rahbariyatga taqdim
  etishdan oldin qaysi variant yakuniy ekanini aniqlashtirish zarur.
* **Anomal deflyatorlar** (sut, qorako'l teri) — **B6** so'rovi.
* **`tasdiqlangan = false`** — hujjatlarda to'g'ridan-to'g'ri nomlanmagan, mantiq bo'yicha
  qo'shilgan 6 ta tugun: `Organization` (Moliya vazirligi), barcha `Department`lar,
  `System` (eStat, ESTAT 4.0). Ularni o'z tashkiliy tuzilmangizga moslab to'g'rilang:

```cypher
MATCH (n) WHERE n.tasdiqlangan = false RETURN labels(n)[0], n.code, n.name;
```

* **68-band** manba hujjatda raqamsiz berilgan — matn bo'yicha tiklandi va `izoh`da belgilandi.

---

## 5. Nima uchun bu foydali

* **Audit trail** — har bir raqamdan bandgacha, banddan buyruqqacha bir so'rov bilan borish
  (`03_...cypher` → C5).
* **Impact analysis** — bitta hisobot shakli o'zgarsa, qaysi ko'rsatkichlar ta'sirlanishini
  ko'rish (C7).
* **GraphRAG** — LLM ga ko'rsatkich + huquqiy matn + formulani bitta kontekstda uzatish (C12).
  Shu maqsadda `Paragraph.text` va `Indicator.name` bo'yicha full-text indekslar yaratilgan.
