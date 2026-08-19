# QXAudit — self-improving, kontekst xotirasi va LLM chaqiruvlari

> Jonli tizim loglaridan tasdiqlangan holat (2026-08-19).
> Manba: `agents/self_improve.py`, `agents/hermes_host.py`, `agents/rag_agent.py`.

---

## 1. Self-improving saqlanib qoldimi? — **Ha, ishlayapti va sog'lomlashdi**

Hozirgi holat: `enabled: true, count: 26` — tozalashdan keyin 22 ta edi, keyin 4 ta
yangi **haqiqiy** savol o'rganilgan (masalan `narx ma'lumoti nima uchun kerak?`).

Qanday ishlaydi (to'liq sikl):

```text
Savol keldi
  │
  ├─ 1. RETRIEVE: store'dagi 26 retseptdan leksik o'xshashlik (Jaccard) bo'yicha
  │      top-3 tanlanadi (ball ≥ 0.18) — embedding kerak emas, LLM kerak emas
  │
  ├─ 2. INJECT: topilganlar system promptga "Learned patterns" bloki sifatida
  │      qo'shiladi — qat'iy ogohlantirish bilan:
  │      "faqat uslub uchun; har bir raqam SHU turda tool orqali tasdiqlansin"
  │
  ├─ 3. Agent javob beradi (tool'lar bilan)
  │
  └─ 4. LEARN: javob muvaffaqiyatli bo'lsa — savol+javob store'ga yoziladi
         (data/self_improve.json, max 500 ta, kam ishlatilganlari o'chadi)
```

2026-08-19 dagi o'zgarishlar uni **buzmadi, himoyaladi**:

- `### Task...` meta-promptlar endi o'rganilmaydi ham, promptga qaytarilmaydi ham;
- yuklashda eski axlat avtomatik tozalanadi (`purge_meta_recipes`);
- kuchaytirilgan ko'rsatma tufayli model o'rganilgan javobni "tayyor fakt" deb
  ko'chirmaydi — sinovda o'sha savolga model baribir 2 ta tool chaqirdi.

Tekshirish: `GET /v1/self-improve` (bearer talab qiladi).

---

## 2. Kontekst (suhbat) xotirasi saqlanib qoldimi? — **Ha, va tozaroq ishlayapti**

Qanday ishlaydi ([agents/hermes_host.py](../agents/hermes_host.py)):

| Bosqich | Nima bo'ladi |
|---|---|
| Sessiya kaliti | `session_id` (Open WebUI chat id → header → barmoq izi) |
| Saqlash | RAM'dagi dict: har sessiya uchun oxirgi **12 xabar = 6 turlik** (`HERMES_SESSION_HISTORY_LIMIT=6 × 2`) |
| Seeding | Sessiya yangi bo'lsa, Open WebUI yuborgan transcript'dan tarix tiklanadi |
| Har turda | `system prompt + tarix + yangi savol` → modelga; javob tarixga qo'shiladi, eng eskisi siqib chiqariladi |

Yaxshilanish: ilgari `### Task...` so'rovlari ham shu 12 o'ringa yozilardi —
haqiqiy suhbatni siqib chiqarardi. Endi **yozilmaydi**
(isbot: meta-task'dan keyin `prior_history=0`).

**Saqlanib qolgan cheklov:** xotira RAM'da — konteyner restart bo'lsa barcha
sessiyalar o'chadi (Open WebUI seeding qisman tiklaydi). Doimiy xotira
(SQLite/Neo4j) — Faza 1 rejasida.

---

## 3. Har bir savolga necha marta LLM chaqiriladi?

Jonli logdan sanab chiqilgan — savol turiga bog'liq:

| Stsenariy | LLM chaqiruvlari | Tafsilot |
|---|---|---|
| Salomlashish / tool'siz javob | **1** | Faqat host |
| 1 ta `graph_ask` / `reconcile_check` | **2** | ① tool tanlash → tool (LLM'siz, Cypher/Python) → ② yakuniy javob |
| 1 ta `docs_ask` | **3** | ① tool tanlash → ② RAG ichidagi javob yozish ([rag_agent.py](../agents/rag_agent.py), `_generate_answer`) → ③ yakuniy javob |
| **Real misol:** `graph_ask` + `docs_ask` | **4** | Logda 09:19:52–09:20:08 oralig'ida roppa-rosa 4 ta `chat/completions`: ① host tool tanladi → ② host ikkinchi toolga o'tdi → ③ RAG ichki javobi → ④ host yakuni |
| Open WebUI xizmat so'rovi (title/tag/follow-up) | **1** (arzon) | Endi `HERMES_TASK_MODEL` (standart gpt-4.1-mini), tool'siz, tarixsiz |

Qo'shimcha:

- `docs_ask` ishlaganda **+1 embedding so'rovi** ketadi (embedding-service :8090
  orqali) — bu chat-LLM emas, arzon.
- Yuqori chegara: `HERMES_MAX_ITERATIONS=12` → langgraph recursion limiti 24 —
  agent cheksiz aylanib qola olmaydi.

**Umumiy manzara (1 foydalanuvchi savoli, Open WebUI bilan):**
~4 ta gpt-4.1 chaqiruvi (savolning o'zi) + 1–2 ta gpt-4.1-mini (title/follow-up) —
ilgari esa hammasi gpt-4.1 edi va meta-so'rovlar 12 xabarlik tarix bilan ketardi.
