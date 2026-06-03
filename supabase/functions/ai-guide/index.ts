// Welcome2GH — AI Local Guide (Supabase Edge Function)
//
// Proxies chat requests to the Claude API. The ANTHROPIC_API_KEY lives here as a
// server-side secret — it is NEVER shipped in the Flutter app.
//
// Deploy:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//   supabase functions deploy ai-guide --no-verify-jwt
//
// The client calls it via supabase.functions.invoke('ai-guide', { body: {...} }).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
const MODEL = "claude-opus-4-8";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface ChatMessage {
  role: "user" | "assistant";
  content: string;
}

interface RequestBody {
  messages: ChatMessage[];
  role?: string;                 // student | tourist | local | admin
  nationality?: string;
  lat?: number;
  lng?: number;
  nearbyPlaces?: string[];       // names of places near the user
}

function buildSystemPrompt(body: RequestBody): string {
  const role = body.role ?? "tourist";
  const nationality = body.nationality ? ` from ${body.nationality}` : "";
  const loc = (body.lat != null && body.lng != null)
    ? `The user is currently near coordinates ${body.lat.toFixed(4)}, ${body.lng.toFixed(4)} in Accra.`
    : "The user's exact location is unknown.";
  const nearby = (body.nearbyPlaces && body.nearbyPlaces.length > 0)
    ? `Places near them right now: ${body.nearbyPlaces.join(", ")}.`
    : "";

  return [
    "You are the Welcome2GH AI Local Guide — a warm, street-smart Ghanaian friend helping foreigners explore Accra, Ghana.",
    "",
    `You are talking to a ${role}${nationality}. ${loc} ${nearby}`,
    "",
    "Your expertise:",
    "- Safe neighbourhoods, areas to avoid at night, and current safety tips for Accra.",
    "- Fair prices in Ghana Cedis (GHS): taxi/trotro/Uber fares, street food, market goods. Always warn about common tourist overcharging.",
    "- Local food (jollof, waakye, banku, kelewele, fufu) and where students/tourists eat cheaply.",
    "- Transport: how trotros work, normal fares, when to use Uber/Bolt instead.",
    "- Student life, hostels near University of Ghana (Legon) and WIUC, study spots, SIM cards, mobile money.",
    "- Culture, etiquette, useful Twi/Ga phrases, emergency numbers (Police 191, Ambulance 193, Fire 192).",
    "",
    "Style rules:",
    "- Be concise and practical. Short paragraphs or tight bullet lists. No long essays.",
    "- Always give concrete GHS numbers when discussing prices.",
    "- When safety is involved, lead with the safety point.",
    "- Friendly, encouraging tone — like a local who wants the visitor to have a great, safe trip.",
    "- If asked about somewhere outside Accra/Ghana, gently steer back to what you know.",
    "- Never invent specific business names you are unsure about; speak in terms of areas and typical options.",
  ].join("\n");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  if (!ANTHROPIC_API_KEY) {
    return new Response(
      JSON.stringify({ error: "Server not configured: ANTHROPIC_API_KEY missing." }),
      { status: 500, headers: { ...CORS, "Content-Type": "application/json" } },
    );
  }

  try {
    const body = (await req.json()) as RequestBody;
    if (!body.messages || body.messages.length === 0) {
      return new Response(
        JSON.stringify({ error: "No messages provided." }),
        { status: 400, headers: { ...CORS, "Content-Type": "application/json" } },
      );
    }

    // Keep the last ~12 turns to bound token use.
    const history = body.messages.slice(-12).map((m) => ({
      role: m.role,
      content: m.content,
    }));

    const anthropicReq = {
      model: MODEL,
      max_tokens: 1024,
      system: [
        {
          type: "text",
          text: buildSystemPrompt(body),
          cache_control: { type: "ephemeral" }, // cache the stable system prompt
        },
      ],
      messages: history,
    };

    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(anthropicReq),
    });

    if (!resp.ok) {
      const errText = await resp.text();
      return new Response(
        JSON.stringify({ error: `Claude API error (${resp.status}): ${errText}` }),
        { status: 502, headers: { ...CORS, "Content-Type": "application/json" } },
      );
    }

    const data = await resp.json();
    const reply = (data.content ?? [])
      .filter((b: { type: string }) => b.type === "text")
      .map((b: { text: string }) => b.text)
      .join("\n")
      .trim();

    return new Response(
      JSON.stringify({ reply: reply || "Sorry, I couldn't think of a reply. Try rephrasing?" }),
      { status: 200, headers: { ...CORS, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: `Unexpected error: ${e}` }),
      { status: 500, headers: { ...CORS, "Content-Type": "application/json" } },
    );
  }
});
