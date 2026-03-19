# Copilot Instructions

## Project Guidelines
- Mobile app must be a child app with role-based access: default VIEWER is read-only inventory only; STAFF (PIN 1111) can view inventory, debt, order history, and create draft orders for desktop approval/reject flow. 
- Mobile staff must not approve orders; only the desktop app can approve/reject. Mobile staff can only view past approved order history. 
- Do not reuse desktop UI layout on mobile.
- When adding mobile features, avoid breaking existing desktop functionality; desktop behavior must remain intact except for requested changes.
- Input fields should behave like normal text editing without automatic text selection/highlighting; keep both quantity controls: +/- buttons and direct typing.
- Action buttons, such as logout, must be clearly visible; use bright/active colors to avoid faded/disabled-looking styles.
- Ensure to read and record updates in `PROJECT_CONTEXT.md` for tracking changes and maintaining project integrity.