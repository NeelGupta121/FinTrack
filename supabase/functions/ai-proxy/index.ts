// FinTrack secure AI proxy (Supabase Edge Function).
//
// Why this exists: the Gemini API key must NEVER ship in the client (mobile
// binaries are decompilable; web bundles expose the network call). This function
// holds GEMINI_API_KEY as a server-side secret, requires an authenticated
// Supabase user (works with anonymous sign-in too), enforces a per-user daily
// quota, and forwards the request to Gemini. The client only ever sees the
// generated text — never the key.
//
// Deploy:
//   supabase secrets set GEMINI_API_KEY=<your-key>
//   supabase secrets set AI_DAILY_LIMIT=100          # optional (<= SQL ceiling)
//   supabase secrets set ALLOWED_ORIGINS=https://app.example.com  # web only, CSV
//   supabase functions deploy ai-proxy
// (SUPABASE_URL and SUPABASE_ANON_KEY are injected automatically.)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_MODEL = "gemini-2.0-flash-lite";
const GEMINI_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
const DAILY_LIMIT = Number(Deno.env.get("AI_DAILY_LIMIT") ?? "100");

// Request-body / field caps. A malicious caller can otherwise stuff huge or
// injection-laden strings into the prompt; cap them defensively. The SQL
// increment_ai_usage() function independently clamps the daily limit, so the
// quota cannot be bypassed even by calling the RPC directly via PostgREST.
const MAX_BODY_BYTES = 32 * 1024; // 32 KB is ample for headline/snippet/holdings
const MAX_HEADLINE = 300;
const MAX_SNIPPET = 2000;
const MAX_QUESTION = 1000;
const MAX_JSON_FIELD = 4000;

// Native mobile clients send no Origin (CORS is browser-only). For web callers,
// only origins explicitly listed in ALLOWED_ORIGINS get an allow-origin header;
// everything else is denied cross-origin access. A wildcard "*" would let any
// website fire credentialed requests on behalf of a logged-in user.
const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

function corsHeaders(req: Request): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
  const origin = req.headers.get("Origin");
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

function json(
  body: unknown,
  status: number,
  cors: Record<string, string>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

/** Cap a user-supplied string so prompts can't grow unbounded. */
function clampStr(v: unknown, max: number): string {
  return typeof v === "string" ? v.slice(0, max) : "";
}

/** Cap a user-supplied structure serialized into the prompt. */
function clampJson(v: unknown, max: number): string {
  try {
    return JSON.stringify(v ?? {}).slice(0, max);
  } catch {
    return "{}";
  }
}

/** Extract a JSON object from a possibly code-fenced or prose-wrapped reply. */
function extractJson(raw: string): Record<string, unknown> | null {
  let s = (raw ?? "").trim();
  const fence = s.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fence) s = fence[1].trim();
  const start = s.indexOf("{");
  const end = s.lastIndexOf("}");
  if (start !== -1 && end > start) s = s.slice(start, end + 1);
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
}

serve(async (req: Request): Promise<Response> => {
  const cors = corsHeaders(req);
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405, cors);

  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!geminiKey || !supabaseUrl || !anonKey) {
    return json({ error: "Server not configured" }, 500, cors);
  }

  // Reject oversized bodies before reading/parsing them.
  const contentLength = Number(req.headers.get("Content-Length") ?? "0");
  if (contentLength > MAX_BODY_BYTES) {
    return json({ error: "Request too large" }, 413, cors);
  }

  // Bind the Supabase client to the caller's JWT so auth.uid() resolves in the
  // quota RPC and RLS — the user cannot act as anyone else.
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: authErr } = await supabase.auth.getUser();
  if (authErr || !user) return json({ error: "Unauthorized" }, 401, cors);

  // Atomic per-user daily quota check. p_limit is only a hint — the SQL function
  // hard-clamps it, so a direct PostgREST call cannot raise its own ceiling.
  const { data: allowed, error: rlErr } = await supabase.rpc(
    "increment_ai_usage",
    { p_limit: DAILY_LIMIT },
  );
  if (rlErr) return json({ error: "Rate check failed" }, 500, cors);
  if (allowed === false) return json({ error: "Daily AI limit reached" }, 429, cors);

  let payload: Record<string, unknown>;
  try {
    const raw = await req.text();
    if (raw.length > MAX_BODY_BYTES) {
      return json({ error: "Request too large" }, 413, cors);
    }
    payload = JSON.parse(raw);
  } catch {
    return json({ error: "Invalid JSON body" }, 400, cors);
  }

  const action = payload?.action;
  let prompt: string;
  let wantJson = false;

  switch (action) {
    case "sentiment":
      wantJson = true;
      prompt =
        `Analyze financial sentiment. Return JSON: {"sentiment":"bullish|bearish|neutral","score":<-1to1>,"reason":"<brief>"}\n\n` +
        `Headline: ${clampStr(payload.headline, MAX_HEADLINE)}\n` +
        `Snippet: ${clampStr(payload.snippet, MAX_SNIPPET)}`;
      break;
    case "portfolioReview":
      prompt =
        `Review this Indian portfolio and give 3 actionable insights in 100 words:\n` +
        `${clampJson(payload.holdings, MAX_JSON_FIELD)}`;
      break;
    case "askQuestion":
      prompt = `Context: ${clampJson(payload.context, MAX_JSON_FIELD)}\n\n` +
        `Question: ${clampStr(payload.question, MAX_QUESTION)}`;
      break;
    default:
      return json({ error: "Unknown action" }, 400, cors);
  }

  let gData: Record<string, unknown>;
  try {
    const gRes = await fetch(`${GEMINI_URL}?key=${geminiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.3, maxOutputTokens: 512 },
      }),
    });
    if (!gRes.ok) return json({ error: "AI upstream error" }, 502, cors);
    gData = await gRes.json();
  } catch {
    return json({ error: "AI upstream unreachable" }, 502, cors);
  }

  // deno-lint-ignore no-explicit-any
  const candidates = (gData as any)?.candidates as any[] | undefined;
  const text =
    // deno-lint-ignore no-explicit-any
    (candidates?.[0]?.content?.parts?.[0]?.text as string | undefined) ?? "";

  if (wantJson) {
    const parsed = extractJson(text);
    return json(parsed ?? { sentiment: "neutral", score: 0, reason: "" }, 200, cors);
  }
  return json({ text }, 200, cors);
});
