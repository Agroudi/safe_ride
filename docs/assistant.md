# SafeRide AI — design and decisions (AI-01, AI-02)

An in-app assistant that explains SafeRide, helps prepare journeys and
troubleshoot, and points to Get help in an emergency. `CLAUDE.md` §16 holds the
decisions in short; this is the reasoning. Research date for every provider
fact below: **2026-11-09**, from Google's official documentation
(`ai.google.dev/gemini-api/docs/*`, which now redirects to
`aistudio.google.com/docs/*`).

## 1. Decisions

| Decision | Choice | Why |
|---|---|---|
| Provider | Google Gemini, **free tier only** (the owner's decision, AI-02) | No paid APIs. Consequences in §2 |
| Model | `gemini-3.5-flash-lite`, fallback `gemini-3.1-flash-lite` | Both stable with a free tier; 3.5 Flash-Lite is "recommended for new projects"; 1,048,576 input / 65,536 output tokens. Not 2.5 (deprecated, rerouted on 2026-12-01) and not previews (shut down without notice) |
| Where the provider is called | A SafeRide backend only — never the app | The key never ships; the server verifies the account and App Check and counts every question |
| Backend | Cloud Functions (callable, 2nd gen), a **separate codebase** `functions-ai/`, region `me-central2` | Same patterns as `functions/`; a separate codebase so an AI deploy can never deploy the undeployed escalation backend. Deploying needs Blaze (not enabled) |
| API surface | Interactions API with `store: false`; `generateContent` stays possible behind the provider | Interactions is Google's recommended interface (GA June 2026) and stores conversations by default — `store: false` keeps them off Google's interaction store |
| Conversation history | **On the phone only**, per account, newest 50 | Nothing to secure, retain or disclose on a server |
| Streaming | Not in the MVP | Short answers; a whole answer is easier to filter and count |
| Abstraction | `AssistantRepository` (app) and `AIProvider` (server) | Nothing provider-shaped crosses either; OpenAI or another provider is a server change |

## 2. What the free tier means (and what it obliges)

From the pricing page and the Gemini API Additional Terms:

- **Google uses free-tier prompts and answers to improve its products**, and
  human reviewers may read them. The terms say: do not submit sensitive,
  confidential or personal information to the unpaid services.
  → The in-app AI notice (AI-03) must say so plainly, before the first
  question. The server (AI-04/05) strips phone numbers and email addresses
  from questions before they reach the provider, and the app never sends
  location, contacts, journeys, tokens or records (§4).
- **Capacity is not guaranteed.** Free-tier limits are per Google Cloud
  project (not per key), are not published per model in the docs (they are
  read from the project's AI Studio page), reset at midnight Pacific time,
  and "are not guaranteed". → When they run out, SafeRide AI says it is
  resting for today; Get help is unaffected. Our own per-user (20/day) and
  global caps run on the server first.
- **Region.** The API is available in all seven countries SafeRide supports.
  The terms allow only paid services for users in the EEA, Switzerland and
  the UK. → Users there must not be served (to be decided with the owner:
  the chosen country, or a server-side region check).
- **Age.** The terms require users to be 18 or older and bar clients likely
  to be used by minors. → **Unresolved, a release blocker:** SafeRide has no
  age check.
- **No medical advice** (terms). → Emergency guidance points to Get help and
  emergency services; it never diagnoses.
- **Interactions stored for 1 day on the free tier by default** → always
  `store: false`.

## 3. Architecture

```
Flutter: AssistantPage → AssistantCubit → AssistantRepository
            (Mock now; CallableAssistantRepository from AI-04)
               └─ HTTPS callable (Firebase Auth + App Check) ─►
functions-ai: askSafeRideAI
   validate → limits (Firestore transaction) → prompt → AIProvider
        ├─ GeminiProvider (Interactions, store:false)
        ├─ MockProvider (Spark, CI)
        └─ another provider later
   → filter the answer → record usage (metadata only) → reply
```

## 4. What the app may send

Only: the question (≤ 1,000 characters), the recent conversation (≤ 12
messages, ≤ 4,000 characters), the language. From AI-07, and only when the
user turns on "Include app status" for that question: platform, app version,
app language, location permission state, whether a journey is in progress
(yes/no), tracking status, online/offline, notifications allowed/blocked.

Never: coordinates, routes, places, contacts, connections, messages, safety
checks or escalations, share or invite tokens, email, uid or any device id.

## 5. Safety rules for the assistant

- It has **no tools**: it cannot call, text, share, start or stop anything.
- It **never states an emergency number** — it points to Get help, where the
  checked numbers for the user's country are.
- It never says an accident happened, and never makes the user wait: emergency
  words are noticed **on the phone** (`EmergencySignal`) and Get help is
  offered before the question is even sent, with or without a network. Get
  help is always on the chat screen.
- It answers from a curated SafeRide guide kept with the backend, says when it
  does not know, and does not invent features.

## 6. Usage limits (all enforced by the server)

20 questions per account per UTC day; one every few seconds; a global daily
cap; at most 512 answer tokens; the input bounds above; a 30 s timeout. A
question retried with the same `requestId` is counted once. The app's limits
(`AssistantLimits`) only avoid sending what would be refused.

## 7. AI-02 — what exists

`lib/features/assistant/`: the provider-independent models (`AiMessage`,
`AiRequest`, `AiLanguage`, `AiReply`, `AiUsage`, `AiFailure`),
`AssistantLimits`, `EmergencySignal`; `AssistantRepository` and
`MockAssistantRepository` — **local only**, every answer a preview line that
says so, counting questions per day in memory like the server will;
`ConversationStore` / `FileConversationStore` (`assistant/<uid>.json`, erased
with the account); `AssistantCubit`. No screen, no route, no network, no key.

## 8. Roadmap

| Batch | Scope | Needs |
|---|---|---|
| AI-03 | Chat screen, entry points, AI notice (free-tier wording), Get help shortcut and banner, usage meter; ar / en, light / dark, 2× text | Spark |
| AI-04 | `functions-ai/` with the mock provider, validation, limits, error mapping; emulator tests; `CallableAssistantRepository` | Spark |
| AI-05 | Gemini provider (Interactions, `store:false`), curated guide, personal-data stripping, safety handling; local runs with synthetic questions only | Spark + a development AI Studio key in a local, ignored secret |
| AI-06 | App Check, Secret Manager, global counters, logging policy, deletion of usage records | Spark (emulator) |
| AI-07 | Opt-in app status, Egyptian Arabic tuning, evaluation set | Spark |
| AI-08 | Release: age and region decisions, budgets, staged rollout | **Blaze** (owner's approval) |
