---
name: bookify-fullstack-change
description: "Use when implementing a feature that touches both Flutter and Go, or when migrating Bookify behavior across UI, providers, services, handlers, routes, models, WebSocket payloads, or SQL schema."
argument-hint: "Describe the feature or migration you want to make"
---

# Bookify Full-Stack Change

Use this skill for cross-layer work in Bookify Rooms, especially when a feature touches `lib/` and `backend/` together.

## When to Use
- Adding or changing auth, room, booking, admin, or realtime behavior.
- Updating an API contract that Flutter consumes and Go serves.
- Migrating behavior from Firebase-centric code to the Go backend.
- Changing models, enums, status flows, or WebSocket payloads.

## Procedure
1. Identify the contract first.
   - Check the Flutter model, provider, and service that consume the data.
   - Check the Go route, handler, model, and SQL that produce or store it.
2. Decide whether the change is Flutter-only, Go-only, or shared.
   - Shared changes must stay aligned on field names, enums, and status values.
3. Update the backend side if the server contract changes.
   - Route wiring, handler logic, model structs, SQL, and migration files should move together.
4. Update the Flutter side to match.
   - Models, services, providers, and screens should be updated together when the payload changes.
5. Verify the result.
   - Run the smallest useful validation step for the affected area.

## Bookify Rules
- Keep roles as `user`, `booking`, `admin`, and `superadmin`.
- Keep booking status flow as `pending -> confirmed/rejected -> cancelled/completed`.
- Do not assume Firebase and Go are interchangeable unless the task says so.
- Treat WebSocket payloads and API JSON field names as part of the contract.

## Reference Files
- Flutter entry point: `./lib/main.dart`
- Flutter auth flow: `./lib/providers/auth_provider.dart`
- Backend routes: `./backend/internal/server/routes.go`
- Backend models: `./backend/internal/models/`
- Backend handlers: `./backend/internal/handlers/`

## Output Format
- What changed.
- Which layer changed.
- Which files need matching updates in the other layer.
- What was verified.