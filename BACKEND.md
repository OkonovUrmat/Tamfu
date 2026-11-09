# Backend integration guide

The iOS app is backend-ready: every feature depends on a protocol in
`Services/Protocols/Services.swift`. The mocks in `Services/Mock` mirror the
rules below so the UI already behaves like production.

## Services to implement

| Protocol | Responsibility | Suggested transport |
|---|---|---|
| `AuthServicing` | Sign up / sign in (Sign in with Apple, phone), session restore, 18+ verification, account deletion | REST + Keychain token |
| `ProfileServicing` | Profile CRUD, category visibility, settings sync | REST |
| `BottleDistributing` | Send, quota, shore check, accept, skip, sent history, events | REST + WebSocket / APNs |
| `DiscoveryServicing` | Candidate feed, like/pass, mutual match, connection requests | REST + events |
| `ChatServicing` | Conversations, messages, reveals, game moves, typing, read receipts | WebSocket |
| `MediaUploading` | Pre-signed upload to object storage, returns CDN URL | S3 / GCS / R2 |
| `ModerationServicing` | Text + media screening, block, report | Server-side |

## Random distribution (server-side, never on the client)

Mirrors `MockDatabase.pickRecipient` / `nextBottle`.

**On send**
1. Reject if the sender exceeded `dailySendLimit` (10) — enforced server-side.
2. Run text moderation (links, phone numbers, abuse, spam heuristics) and
   media moderation (NSFW / violence classifier). Pending media is not delivered.
3. Store the bottle with `expiresAt = now + 72h`, `deliveryAttempts = 0`.
4. Pick a recipient from the eligible set:
   - not the sender; adult (18+); account active;
   - not blocked in either direction;
   - `receiveBottles == true` and `receivedToday < dailyIncomingLimit` (5/20/50/100);
   - has not skipped this bottle before;
   - not picked by this sender within the cooldown window (7 days);
   - matches both users' age preferences (and language preference when
     `bottlesFromAnywhere == false`).
   Then choose uniformly at random among the **least-loaded half** of
   candidates to spread bottles fairly.
5. Deliver (push + `BottleEvent.incoming`), increment recipient counter.

**On accept** → create a conversation (origin `bottle`), mark bottle `accepted`,
notify the sender (`BottleEvent.found`).

**On skip** → add the user to `skippedBy`, increment `deliveryAttempts`,
return to the pool and re-run selection.

**Expiration** → a scheduled job marks bottles `expired` when
`now >= expiresAt` or `deliveryAttempts >= 12`.

Use a transactional queue (e.g. Postgres `SELECT … FOR UPDATE SKIP LOCKED`)
so one bottle is never offered to two people at once.

## Privacy guarantees enforced by the server

- Bottle teasers include only: first initial, age bracket, country, city
  (only if `showLocation`), up to 3 languages, status.
- Profile responses strip categories that are `hidden`, and `gradual`
  categories unless revealed in a conversation with the viewer.
- A reveal is created only by an explicit client request from the owner;
  the server stores a snapshot per conversation.
- Hidden city is removed from every payload (including search filters).

## Suggested data model

`users`, `profiles`, `profile_categories(user_id, category, visibility, items)`,
`bottles`, `bottle_deliveries(bottle_id, recipient_id, status, at)`,
`conversations`, `messages(type, payload jsonb)`, `reveals(conversation_id, user_id, category)`,
`game_sessions`, `connection_requests`, `blocks`, `reports`, `daily_counters`.
