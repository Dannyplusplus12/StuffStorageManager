# Copilot Instructions

## Project Guidelines
- Mobile app must be a child app with role-based access: default VIEWER is read-only inventory only; STAFF (PIN 1111) can view inventory, debt, order history, and create draft orders for desktop approval/reject flow. 
- Mobile staff must not approve orders; only the desktop app can approve/reject. Mobile staff can only view past approved order history. 
- Do not reuse desktop UI layout on mobile.
- When adding mobile features, avoid breaking existing desktop functionality; desktop behavior must remain intact except for requested changes.
- Input fields should behave like normal text editing without automatic text selection/highlighting; keep both quantity controls: +/- buttons and direct typing.
- Action buttons, such as logout, must be clearly visible; use bright/active colors to avoid faded/disabled-looking styles.
- Ensure to read and record updates in `PROJECT_CONTEXT.md` for tracking changes and maintaining project integrity.

## Desktop UI Guidelines
- Interactive buttons in the desktop Flutter UI should show `SystemMouseCursors.click` cursor feedback (not `grab`).
- Stock-in page should support product image input (URL/path with quick paste) and only show add-product form (no inventory grid). Keep action buttons clustered to reduce mouse travel. The product image should be selected via file upload dialog (reuse existing behavior). 
- Stock-in UI preference: remove manual image path input; show image preview and a single upload button on the right side of the general info section; reuse the previous proven workflow that opens file dialog and stores image path via copied assets/images file. Keep form left-aligned with clear hierarchy (general info section above color groups), use 'Thêm màu' button below existing groups, remove top/right extra group/reset buttons, and use a larger prominent save button. Keep `Size` and `SL` fields adjacent for faster variant input.
- Debt page should open add-customer via popup and show selected customer's history inline on the right instead of a popup. Debt history should expand inline per record with order item details shown in dropdown.
- Pending approval screen preference: modernized card layout with clearer status/summary and more direct action controls.
- Orders screen preference: keep compact left-focused layout unchanged and only remove the `Xem` action button.