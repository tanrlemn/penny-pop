import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type EnsureActiveHouseholdRow = {
  household_id: string;
  household_name: string;
  role: string; // 'admin' | 'member'
};

type SequenceAccount = Record<string, unknown>;

const corsHeaders: HeadersInit = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  headers.set("content-type", "application/json; charset=utf-8");
  for (const [k, v] of Object.entries(corsHeaders)) headers.set(k, v as string);
  return new Response(JSON.stringify(body), { ...init, headers });
}

function getEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`Missing env var: ${name}`);
  return v;
}

function pickString(
  obj: Record<string, unknown>,
  keys: string[],
): string | null {
  for (const k of keys) {
    const v = obj[k];
    if (typeof v === "string" && v.length > 0) return v;
    if (typeof v === "number" && Number.isFinite(v)) return String(v);
  }
  return null;
}

function getTypeValue(a: Record<string, unknown>): string | null {
  const v = a["type"] ?? a["accountType"] ?? a["account_type"];
  if (typeof v !== "string") return null;
  return v.trim();
}

function isPodType(typeValue: string | null): boolean {
  if (!typeValue) return false;
  const t = typeValue.toLowerCase();
  // Docs say this is "Pod" / "Income Source" / "Account". Be tolerant of variants.
  return t === "pod" || t.includes("pod");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, { status: 405 });
  }

  try {
    const supabaseUrl = getEnv("SUPABASE_URL");
    const supabaseAnonKey = getEnv("SUPABASE_ANON_KEY");
    const supabaseServiceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");
    const sequenceAccessToken = getEnv("SEQUENCE_ACCESS_TOKEN");

    // When verify_jwt=false at the gateway, we must validate the user ourselves.
    // Prefer Authorization header, but also support passing access_token in JSON body.
    const headerAuth = req.headers.get("authorization");
    let accessTokenFromBody: string | null = null;
    try {
      const body = await req.json();
      if (body && typeof body === "object") {
        const token = (body as Record<string, unknown>)["access_token"];
        if (typeof token === "string" && token.length > 0) {
          accessTokenFromBody = token;
        }
      }
    } catch {
      // No JSON body; ignore.
    }

    const tokenRawFromHeader = headerAuth?.toLowerCase().startsWith("bearer ")
      ? headerAuth.slice(7).trim()
      : (headerAuth?.trim() ?? null);

    const accessTokenRaw = tokenRawFromHeader || accessTokenFromBody;

    if (!accessTokenRaw) {
      return jsonResponse(
        {
          error:
            "Missing access token (send Authorization header or access_token in body)",
        },
        { status: 401 },
      );
    }

    const authHeader = `Bearer ${accessTokenRaw}`;

    // User-scoped client (RLS enforced) to check household role.
    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { authorization: authHeader } },
    });

    const { data: householdData, error: householdError } = await supabaseUser
      .rpc("ensure_active_household");

    if (householdError) {
      // If the JWT is invalid/expired, PostgREST will reject the request.
      // Surface that as a 401 so the client can prompt re-auth if needed.
      const msg = householdError.message ?? "Unknown error";
      const isAuthish = msg.toLowerCase().includes("jwt") ||
        msg.toLowerCase().includes("not authenticated") ||
        msg.toLowerCase().includes("unauthorized");
      return jsonResponse(
        { error: `ensure_active_household failed: ${msg}` },
        { status: isAuthish ? 401 : 400 },
      );
    }

    let householdRow: EnsureActiveHouseholdRow | null = null;
    if (Array.isArray(householdData) && householdData.length > 0) {
      householdRow = householdData[0] as EnsureActiveHouseholdRow;
    } else if (householdData && typeof householdData === "object") {
      householdRow = householdData as EnsureActiveHouseholdRow;
    }

    if (!householdRow?.household_id || !householdRow?.role) {
      return jsonResponse(
        { error: "Unexpected ensure_active_household response" },
        { status: 500 },
      );
    }

    if (householdRow.role !== "admin") {
      return jsonResponse({ error: "Only admins can sync pods" }, { status: 403 });
    }

    // Service-role client (bypasses RLS) to write pods.
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

    // Fetch accounts from Sequence.
    //
    // Sequence docs have historically varied on the exact base path; we've seen
    // deployments where POST /account returns 404. Be tolerant and try a few
    // likely variants.
    const candidateUrls = [
      // Confirmed working with Sequence: POST /accounts
      "https://api.getsequence.io/accounts",
      "https://api.getsequence.io/account",
      "https://api.getsequence.io/api/account",
      "https://api.getsequence.io/api/accounts",
      "https://api.getsequence.io/v1/account",
      "https://api.getsequence.io/v1/accounts",
      "https://api.getsequence.io/api/v1/account",
      "https://api.getsequence.io/api/v1/accounts",
    ];

    let sequenceResp: Response | null = null;
    let sequenceJson: unknown = null;
    let usedUrl: string | null = null;

    for (const url of candidateUrls) {
      const resp = await fetch(url, {
        method: "POST",
        headers: {
          "x-sequence-access-token": `Bearer ${sequenceAccessToken}`,
          "content-type": "application/json",
        },
        body: "{}",
      });

      const json = await resp.json().catch(() => null);
      if (resp.ok) {
        sequenceResp = resp;
        sequenceJson = json;
        usedUrl = url;
        break;
      }

      // If it's not-found, try next candidate. Otherwise fail fast.
      const msg = (json && typeof json === "object")
        ? (json as Record<string, unknown>)["message"]
        : null;
      const isNotFound = resp.status === 404 ||
        (typeof msg === "string" && msg.toLowerCase().includes("not found"));

      if (!isNotFound) {
        sequenceResp = resp;
        sequenceJson = json;
        usedUrl = url;
        break;
      }
    }

    if (!sequenceResp || !sequenceResp.ok) {
      return jsonResponse(
        {
          error: "Sequence API request failed",
          status: sequenceResp?.status ?? null,
          urlTried: usedUrl,
          tried: candidateUrls,
          body: sequenceJson,
        },
        { status: 502 },
      );
    }

    // Sequence response shapes we support:
    // - [...]
    // - { accounts: [...] } / { account: [...] }
    // - { data: { accounts: [...] } } (this is what the docs examples show)
    let accounts: SequenceAccount[] = [];
    let accountsFound = false;

    const tryExtractAccounts = (obj: Record<string, unknown>): boolean => {
      const a1 = obj["account"];
      const a2 = obj["accounts"];
      if (Array.isArray(a1)) {
        accounts = a1 as SequenceAccount[];
        return true;
      }
      if (Array.isArray(a2)) {
        accounts = a2 as SequenceAccount[];
        return true;
      }
      return false;
    };

    if (Array.isArray(sequenceJson)) {
      accounts = sequenceJson as SequenceAccount[];
      accountsFound = true;
    } else if (sequenceJson && typeof sequenceJson === "object") {
      const obj = sequenceJson as Record<string, unknown>;
      accountsFound = tryExtractAccounts(obj);

      if (!accountsFound) {
        const dataObj = obj["data"];
        if (dataObj && typeof dataObj === "object") {
          accountsFound = tryExtractAccounts(dataObj as Record<string, unknown>);
        }
      }
    }

    if (!accountsFound) {
      return jsonResponse(
        {
          error: "Unexpected Sequence response shape (accounts array not found)",
          sequenceUrl: usedUrl,
          body: sequenceJson,
        },
        { status: 502 },
      );
    }

    const now = new Date().toISOString();
    const balanceUpdatedAt = now;

    const typesSeen = new Set<string>();
    for (const a of accounts) {
      const t = getTypeValue(a);
      if (t) typesSeen.add(t);
    }

    const getBalanceInCents = (a: Record<string, unknown>): number | null => {
      const b = a["balance"];
      if (!b || typeof b !== "object") return null;
      const bal = b as Record<string, unknown>;
      const v = bal["amountInDollars"] ?? bal["amountInDollar"];
      if (typeof v !== "number" || !Number.isFinite(v)) return null;
      return Math.round(v * 100);
    };

    const getBalanceError = (a: Record<string, unknown>): string | null => {
      const b = a["balance"];
      if (!b || typeof b !== "object") return null;
      const bal = b as Record<string, unknown>;
      const e = bal["error"];
      if (e == null) return null;
      if (typeof e === "string" && e.trim().length > 0) return e.trim();
      return String(e);
    };

    const podRows = accounts
      .filter((a) => isPodType(getTypeValue(a)))
      .map((a) => {
        const sequenceAccountId = pickString(a, [
          "id",
          "accountId",
          "account_id",
          "sequenceAccountId",
          "sequence_account_id",
        ]);
        const name = pickString(a, ["name", "nickname", "displayName"]);
        const balanceCents = getBalanceInCents(a);
        const balanceError = getBalanceError(a);

        if (!sequenceAccountId || !name) return null;

        return {
          household_id: householdRow!.household_id,
          sequence_account_id: sequenceAccountId,
          name,
          is_active: true,
          last_seen_at: now,
          balance_amount_in_cents: balanceCents,
          balance_error: balanceError,
          balance_updated_at: balanceUpdatedAt,
        };
      })
      .filter((r): r is NonNullable<typeof r> => r !== null);

    // Upsert seen pods (reactivates any that were previously inactive).
    let upsertedIds: Array<{ id: string }> = [];
    if (podRows.length > 0) {
      const { data: upserted, error: upsertError } = await supabaseAdmin
        .from("pods")
        .upsert(podRows, { onConflict: "household_id,sequence_account_id" })
        .select("id");

      if (upsertError) {
        return jsonResponse(
          { error: `Upsert pods failed: ${upsertError.message}` },
          { status: 500 },
        );
      }

      upsertedIds = upserted ?? [];
    }

    // Deactivate pods not seen in this sync.
    const { data: deactivated, error: deactivateError } = await supabaseAdmin
      .from("pods")
      .update({ is_active: false })
      .eq("household_id", householdRow.household_id)
      .eq("is_active", true)
      .lt("last_seen_at", now)
      .select("id");

    if (deactivateError) {
      return jsonResponse(
        { error: `Deactivate missing pods failed: ${deactivateError.message}` },
        { status: 500 },
      );
    }

    return jsonResponse({
      householdId: householdRow.household_id,
      sequenceUrl: usedUrl,
      accountsCount: accounts.length,
      typesSeen: Array.from(typesSeen).slice(0, 20),
      seenPods: podRows.length,
      upserted: upsertedIds.length,
      deactivated: deactivated?.length ?? 0,
    });
  } catch (e) {
    return jsonResponse(
      { error: e instanceof Error ? e.message : String(e) },
      { status: 500 },
    );
  }
});


