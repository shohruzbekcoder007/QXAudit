# QXAudit — OpenAI'dan lokal LLM'ga o'tish (Ollama / vLLM / LM Studio)

> Kod tahlili asosida tuzilgan yo'riqnoma (2026-08-19).
> Manba: `agents/hermes_host.py`, `agents/rag_agent.py`, `agents/embeddings.py`.

## Qisqa javob

**Qiyin emas** — kod allaqachon bunga tayyor qilib yozilgan. Hamma LLM chaqiruvi
OpenAI-mos klient orqali o'tadi va `base_url` sozlanadi. Ollama, vLLM, LM Studio
uchalasi ham OpenAI-mos API beradi, shuning uchun **kod o'zgartirish shart emas —
faqat `.env`**.

---

## Nima OpenAI'ga ulangan (4 nuqta, hammasi almashadi)

| Nuqta | Qayerda | Nima orqali |
|---|---|---|
| Host agent (tool-calling) | [hermes_host.py](../agents/hermes_host.py) | `ChatOpenAI` + `OPENAI_BASE_URL` |
| RAG javob yozuvchi | [rag_agent.py](../agents/rag_agent.py) `_generate_answer` | `ChatOpenAI` + `OPENAI_BASE_URL` |
| Meta-task (title/tag) | `_chat_meta_task` | o'sha `base_url` + `HERMES_TASK_MODEL` |
| Embeddings | [embeddings.py](../agents/embeddings.py) | `remote` / `openai` (`RAG_EMBED_BASE_URL` ham bor) / `local` |

---

## Qaysi birini tanlash

| | Ollama | vLLM | LM Studio |
|---|---|---|---|
| O'rnatish | 5 daqiqa | GPU + sozlash kerak | Desktop ilova |
| Tool-calling | ✅ (mos modellarda) | ✅ (`--enable-auto-tool-choice` bilan) | ✅ (0.3.x dan) |
| Server/prod uchun | Kichik yuk uchun ha | **Eng to'g'ri tanlov** (yuqori parallel, tez) | ❌ shaxsiy kompyuter uchun |
| URL | `:11434/v1` | `:8000/v1` | `:1234/v1` |

**Tavsiya:** sinab ko'rish uchun **Ollama**, keyin prod'ga **vLLM**.
LM Studio — faqat o'z noutbukingizda tajriba uchun.

---

## Qadam-baqadam (Ollama misolida)

### 1. Ollama + model

```bash
ollama pull qwen2.5:32b        # tool-calling va ko'p tillilik yaxshi
ollama pull qwen2.5:7b         # meta-task uchun arzon/tez
```

### 2. `.env` (bor-yo'g'i shu)

```env
OPENAI_BASE_URL=http://host.docker.internal:11434/v1
OPENAI_API_KEY=ollama                # bo'sh bo'lmasin — kod tekshiradi, qiymati farqsiz
LLM_MODEL=qwen2.5:32b
HERMES_TASK_MODEL=qwen2.5:7b
```

(`host.docker.internal` — chunki app konteynerda, Ollama hostda.)

### 3. Embedding — alohida qaror

Hozir embedding-service OpenAI'ga boradi. Uch yo'l:

1. embedding-service'ni lokal modelga o'tkazish (alohida loyiha `d:\GROK\embedding-service`);
2. yoki QXAudit'da `RAG_EMBED_PROVIDER=local` (bge-m3, `requirements-rag-local.txt` — README'da bor);
3. yoki:
   ```env
   RAG_EMBED_PROVIDER=openai
   RAG_EMBED_BASE_URL=http://host.docker.internal:11434/v1
   RAG_EMBED_MODEL=nomic-embed-text
   ```

**Majburiy:** embedding modeli o'zgargach — **to'liq reindex**
(`POST /v1/docs/reindex`). Kod buni to'g'ri boshqaradi
(`index_key` = `provider__model__dim`, eski indeks bilan aralashmaydi).

### 4. Restart va tekshiruv

```bash
docker compose up -d app
curl http://127.0.0.1:9090/ready
```

---

## Haqiqiy qiyinchilik — konfiguratsiya emas, SIFAT

Bu arxitekturaning hammasi **tool-calling'ga** tayanadi
(`graph_ask` / `docs_ask` / `reconcile_check`). Xavflar:

1. **Kichik modellar tool chaqirmaydi yoki argumentni buzadi.** 7B model
   "Don ekinlari formulasi?" ga tool o'rniga o'zidan javob berishi mumkin.
   Shuning uchun host uchun **kamida 32B** (qwen2.5:32b, llama3.3:70b) kerak —
   bu esa GPU talab qiladi (32B uchun ~20+ GB VRAM 4-bit'da).
2. **O'zbek tili.** GPT-4.1 o'zbekchada kuchli; lokal modellardan Qwen oilasi
   nisbatan yaxshi, Llama zaifroq. Foydalanuvchilar o'zbekcha so'raydi —
   bu jiddiy mezon.
3. **Yaxshi tomoni:** faktlar baribir buzilmaydi — raqamlar Neo4j/Chroma'dan
   keladi, `reconcile_check` hisobi Python'da. Model faqat "qaysi toolni
   chaqirish"da va matn sifatida yutqazishi mumkin.

### O'tkazgandan keyingi mini-eval (4 savol)

```text
1. "Don ekinlari uchun qanday formulalar ishlatiladi?"   → graph_ask chaqirdimi? formula+mazmun bormi?
2. "buyruqda nechta bob bor?"                            → docs_ask, javob "8 bob, 82 band"mi?
3. "Vv(A) to'g'ri jamlanganmi?"                          → reconcile_check, farq 3343.2 chiqdimi?
4. "Sut"                                                 → tanlov so'radimi (o'zi tanlamadimi)?
```

---

## Trade-off xulosasi

| | |
|---|---|
| **Yutasiz** | token narxi 0 · rate-limit yo'q · **nashr qilinmagan statistika tashqariga chiqmaydi** (audit 11-mezon) |
| **Yo'qotasiz** | javob sifati (ayniqsa o'zbekcha) va tool-tanlash aniqligi pasayadi · GPU xarajati · kechikish GPU'ga bog'liq |

**Vaqt bahosi:** konfiguratsiya — ~1 soat (reindex bilan).
Sifatni tekshirish va model tanlash — asosiy ish, 1–2 kun.
