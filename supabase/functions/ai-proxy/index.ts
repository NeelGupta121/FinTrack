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
//   supabase functions deploy ai-proxy
// (SUPABASE_URL and SUPABASE_ANON_KEY are injected automatically.)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_MODEL = "gemini-2.0-flash-lite";
const GEMINI_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
const DAILY_LIMIT = Number(Deno.env.get("AI_DAILY_LIMIT") ?? "100");

const cors: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
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
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!geminiKey || !supabaseUrl || !anonKey) {
    return json({ error: "Server not configured" }, 500);
  }

  // Bind the Supabase client to the caller's JWT so auth.uid() resolves in the
  // quota RPC and RLS — the user cannot act as anyone else.
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: authErr } = await supabase.auth.getUser();
  if (authErr || !user) return json({ error: "Unauthorized" }, 401);

  // Atomic per-user daily quota check.
  const { data: allowed, error: rlErr } = await supabase.rpc(
    "increment_ai_usage",
    { p_limit: DAILY_LIMIT },
  );
  if (rlErr) return json({ error: "Rate check failed" }, 500);
  if (allowed === false) return json({ error: "Daily AI limit reached" }, 429);

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const action = payload?.action;
  let prompt: string;
  let wantJson = false;

  switch (action) {
    case "sentiment":
      wantJson = true;
      prompt =
        `Analyze financial sentiment. Return JSON: {"sentiment":"bullish|bearish|neutral","score":<-1to1>,"reason":"<brief>"}\n\n` +
        `Headline: ${payload.headline ?? ""}\nSnippet: ${payload.snippet ?? ""}`;
      break;
    case "portfolioReview":
      prompt =
        `Review this Indian portfolio and give 3 actionable insights in 100 words:\n` +
        `${JSON.stringify(payload.holdings ?? {})}`;
      break;
    case "askQuestion":
      prompt = `Context: ${JSON.stringify(payload.context ?? {})}\n\n` +
        `Question: ${payload.question ?? ""}`;
      break;
    default:
      return json({ error: "Unknown action" }, 400);
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
    if (!gRes.ok) return json({ error: "AI upstream error" }, 502);
    gData = await gRes.json();
  } catch {
    return json({ error: "AI upstream unreachable" }, 502);
  }

  // deno-lint-ignore no-explicit-any
  const candidates = (gData as any)?.candidates as any[] | undefined;
  const text =
    // deno-lint-ignore no-explicit-any
    (candidates?.[0]?.content?.parts?.[0]?.text as string | undefined) ?? "";

  if (wantJson) {
    const parsed = extractJson(text);
    return json(parsed ?? { sentiment: "neutral", score: 0, reason: "" });
  }
  return json({ text });
});
