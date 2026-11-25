# EventHub Business Rules

## 1. User Journey
- User signs up or signs in -> browses events -> selects an event -> books tickets
- On booking: seat count reduces immediately, booking reference is generated
- Booking reference first character MUST match the event title's first character (e.g., Event "Tech Summit" -> Ref starts with "T")
- After booking, user can view bookings via "View My Bookings" link or "View Details"
- User can cancel (delete) individual bookings or "Clear All Bookings" in one action
- Users can also create events from the Admin UI or via API

## 2. User Sandbox Isolation
- Each user only sees their own dynamic events and bookings
- Static events (seeded) are shared across all users
- Cross-user access to bookings returns 403 Forbidden ("Access Denied")
- Deleting a user cascades to their events and bookings

## 3. Event Limits (FIFO Pruning)
- Max **6 user-created events** per account
- When limit reached, the OLDEST event is automatically deleted (FIFO replacement)
- Static events are not counted toward this limit
- Static events cannot be edited or deleted
- Events page shows max 9 events at a time with pagination

## 4. Booking Limits (FIFO Pruning)
- Max **9 bookings** per user
- When limit reached, the OLDEST booking is automatically deleted (FIFO replacement)
- Bookings page shows max 9 bookings at a time
- Booking deletion (cancellation) immediately frees seats
- "Clear All Bookings" button removes all bookings in one go

## 5. Sandbox Warning Banners
- **Events page**: Banner appears when user has close to or more than 6 events displayed, warning about sandbox limits ("sandbox holds up to 6 events and 9 bookings")
- **Bookings page**: Conditional banner also appears giving heads-up about booking limits
- Banners are hidden when counts are low (e.g., fewer than 5 events)

## 6. Per-User Seat Availability
- For static events: `availableSeats` is a fixed DB field
- For dynamic (user-created) events: computed as `totalSeats - sum(user's booking quantities for that event)`
- This allows the same user to book the same event multiple times for testing
- Seat count reduces immediately on booking confirmation

## 7. Booking Reference Format
- Pattern: `[FIRST_LETTER]-[6_RANDOM_ALPHANUMERIC]`
- **First letter comes from the event title (uppercase)** - this is a key business rule to validate
- Example: Event "Tech Summit" -> Ref: `T-A3B2C1`
- Guaranteed unique via collision retry

## 8. Refund Eligibility (Client-Side Logic)
_Updated 2026-11-25 per KAN-7 PO answers._
- Triggered from a text-style link (technically a button, `#check-refund-btn`) labelled exactly **"Check eligibility for refund?"** on the booking detail page
- On click, the link is replaced by a spinner with the text "Checking your refund eligibility…" for a fixed **4 seconds**, then the spinner is replaced by the result
- **Single ticket bookings (quantity = 1) -> Eligible**: "**Eligible for refund.** Single-ticket bookings qualify for a full refund."
- **Multi-ticket bookings (quantity > 1) -> Not eligible**: "**Not eligible for refund.** Group bookings (N tickets) are non-refundable." where N is the booking's ticket count (e.g. "Group bookings (3 tickets) are non-refundable.")
- The prefix ("Eligible for refund." / "Not eligible for refund.") is shown in bold
- Frontend-only logic based on ticket quantity: no backend API, so no failure/error state
- Information only: cancelling a booking does not issue a refund; refund processing does not exist
- Result is not saved: after the result appears the link is not shown again; reloading the page resets to the initial state

## 9. Price Calculation
- `totalPrice = event.price x quantity`
- Price is per-ticket in the Event model
