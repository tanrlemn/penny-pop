### Sequence Remote API (External API) — Capabilities & Usage

This document summarizes what the **Sequence Remote API** (a.k.a. “External API”) is, what it can do, and how to use it safely in an integration.

Primary reference: [Sequence API Overview](https://support.getsequence.io/hc/en-us/articles/42813911824019-API-Overview)

---

### What it is

Sequence exposes a small **Remote API** designed to:

- Trigger **existing Sequence rules** from your system.
- Let your system **compute transfer amounts** for a rule (Sequence calls your endpoint, you return an amount).
- Fetch **account data** (IDs, names, balances, types) for the accounts visible in your Sequence workspace.

It is **not** a general-purpose banking API. You don’t get full CRUD over “everything”, and you generally initiate money movement by **triggering rules** you configured in the Sequence UI.

---

### What it’s capable of

#### Trigger a rule

You can invoke a rule you created in Sequence by calling:

- `POST https://api.getsequence.io/rules/{ruleId}/trigger`

Authentication uses the rule’s **API secret** in the header:

- `x-sequence-signature: Bearer <RULE_API_SECRET>`

This is how you “do things” in Sequence programmatically: your rule can contain actions like transfers, pod movements, etc., as configured in Sequence.

#### Delegate transfer amount calculation to your service (Remote API action)

Sequence can call _your_ HTTP endpoint as part of a rule. Your endpoint returns the amount (in cents) that Sequence should use when executing the rule.

Your server returns JSON:

```json
{ "amountInCents": 25000 }
```

This is useful when the transfer amount depends on business logic only your system knows (e.g., invoice totals, payroll calculations, thresholds).

#### Retrieve account data (balances, names, IDs)

You can query account data for all your accounts (including internal accounts like Pods/Income Sources and connected external accounts) via:

- `POST https://api.getsequence.io/accounts`

Authentication uses a user access token in the header:

- `x-sequence-access-token: Bearer <ACCESS_TOKEN>`

The response includes information like account `id`, `name`, `balance`, and `type`.

---

### What it’s _not_ (practical limitations)

Based on the public docs, the Remote API is intentionally narrow:

- You generally **cannot** arbitrarily “create / update / delete” Sequence entities via API.
- You generally **do not** send “transfer $X from A to B” directly; instead you **trigger a configured rule** (and optionally provide the transfer amount via the Remote API action).
- There’s no published “transaction history export API” in the overview; treat this API as **automation + account snapshot**, not a ledger interface.

If you need functionality beyond these three surfaces (rule trigger, remote amount, accounts list), you’ll likely need to rely on Sequence’s UI capabilities or contact Sequence support.

---

### Getting started (one-time setup)

1. Enable the Remote/External API in Sequence settings (per the [API Overview](https://support.getsequence.io/hc/en-us/articles/42813911824019-API-Overview)).
2. Create an **access token** for user-context requests (used for `/accounts`).
3. For each rule you want to trigger externally, copy its **API secret** (used for `/rules/{ruleId}/trigger`).
4. Store tokens/secrets **server-side** (environment variables or a secrets manager). Do not embed them in client apps.

---

### Example requests

#### Trigger a rule (curl)

```bash
curl -X POST "https://api.getsequence.io/rules/<RULE_ID>/trigger" \
  -H "Content-Type: application/json" \
  -H "x-sequence-signature: Bearer <RULE_API_SECRET>" \
  -d "{}"
```

#### List accounts (curl)

```bash
curl -X POST "https://api.getsequence.io/accounts" \
  -H "Content-Type: application/json" \
  -H "x-sequence-access-token: Bearer <ACCESS_TOKEN>" \
  -d "{}"
```

#### Remote API amount endpoint (your server)

Sequence will call your endpoint (configured in the rule’s Remote API action). Your handler should return:

```json
{ "amountInCents": 12345 }
```

Implementation notes:

- Return a valid JSON object with an integer `amountInCents`.
- Keep the endpoint fast and reliable—this call is part of a rule execution path.

For more details, see: [Remote API](https://support.getsequence.io/hc/en-us/articles/19332939859347-Remote-API)

---

### “Full capacity” / limits (what constrains throughput)

#### Rate limiting / throttling

The API overview indicates that repeatedly triggering the same rule in a short time can result in **HTTP 429 (Too Many Requests)**.

Practical guidance:

- Implement **exponential backoff** on 429/5xx.
- Prefer **queueing** and **deduplication** to avoid accidental trigger storms.
- Design triggers to be **idempotent** on your side (e.g., don’t trigger the same “invoice paid” event twice).

#### Funding limits (money movement caps)

Even if an API call succeeds, money movement is still constrained by Sequence’s plan-based funding limits (daily/monthly caps, etc.).

Reference: [What are my funding limits?](https://support.getsequence.io/hc/en-us/articles/11708484274963-What-are-my-funding-limits)

---

### Security & operational best practices

- **Never** expose Sequence secrets/tokens in a mobile/web client. Call Sequence from your backend.
- Log only non-sensitive metadata (rule IDs, timestamps, status codes). Avoid logging headers.
- Treat “trigger rule” calls as sensitive operations; add your own auth/allowlists in front of any internal endpoints that can initiate triggers.

---

### Troubleshooting checklist

- Getting 401/403:
  - Confirm you’re using the correct header (`x-sequence-access-token` vs `x-sequence-signature`) for the endpoint.
  - Confirm the value includes `Bearer ` and the correct token/secret.
- Getting 429:
  - Reduce trigger frequency, add backoff, and queue events.
- Transfers not happening:
  - Confirm the rule’s actions and conditions in the Sequence UI.
  - Check funding limits and any plan constraints.
