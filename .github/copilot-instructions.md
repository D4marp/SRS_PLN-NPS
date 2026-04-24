# Project Guidelines

## Codebase Shape
- The workspace is a hybrid Flutter + Go project.
- Flutter code lives in `lib/` and uses `Provider`, Firebase services, and a screen/provider/service structure.
- Backend code lives in `backend/` and uses Gin, `sql.DB`, MySQL, JWT auth, and WebSocket realtime updates.
- Keep Flutter and Go contracts aligned when an API, model, or status flow changes.

## Domain Rules
- Roles are `user`, `booking`, `admin`, and `superadmin`.
- Booking flow is `pending -> confirmed/rejected -> cancelled/completed`.
- Do not bypass approval flow or change role semantics unless the task explicitly asks for it.

## Flutter Conventions
- Reuse the existing theme, typography, and layout patterns already defined in the project.
- Prefer `Provider` and the existing service layer over introducing new state management libraries.
- Keep business logic out of widgets when it already belongs in a provider, service, or model.

## Go Conventions
- Keep handlers thin and route wiring centralized in `backend/internal/server/routes.go`.
- Use explicit SQL and the current `sql.DB` + MySQL approach rather than adding an ORM.
- Treat WebSocket payload shapes as part of the API contract.

## Build and Test
- `flutter analyze`
- `flutter test`
- `flutter run`
- `cd backend && go test ./...`
- `cd backend && go run ./cmd/server`

## Working Rule
- If a change touches shared behavior, update the Flutter side and the Go backend together instead of leaving them partially aligned.
