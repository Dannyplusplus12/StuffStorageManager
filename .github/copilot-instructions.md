# Copilot Instructions

## Project Guidelines
- Mobile app must be a child app with role-based access: default VIEWER is read-only inventory only; STAFF (PIN 1111) can view inventory, debt, order history, and create draft orders for desktop approval/reject flow. 
- Mobile staff must not approve orders; only the desktop app can approve/reject. Mobile staff can only view past approved order history. 
- Do not reuse desktop UI layout on mobile.
- When adding mobile features, avoid breaking existing desktop functionality; desktop behavior must remain intact except for requested changes.
- Input fields should behave like normal text editing without automatic text selection/highlighting; keep both quantity controls: +/- buttons and direct typing.
- Action buttons, such as logout, must be clearly visible; use bright/active colors to avoid faded/disabled-looking styles.
- Ensure to read and record updates in `PROJECT_CONTEXT.md` for tracking changes and maintaining project integrity.
- Project organization preference: use `server-repo/` as canonical server backend, remove legacy `frontend/` desktop PyQt artifacts, and consolidate Excel/data scripts into a single folder under `backend/` for cleaner root structure.
- **Project structure changed**: Flutter source now lives in `frontend/`; `flutter_frontend/` is no longer used except for leftover build artifacts.
- For current big update planning, do not add/use `products.code`; keep migration and APIs without this column unless explicitly requested again.
- Big-update decision: keep `order_items.variant_info` for historical integrity; do not remove it because invoice history must still display correctly even if related `variant_id` is later deleted. Drop `variant_info` usage in future changes to avoid regressions.
- Implement a role/PIN-based employee management system: desktop adds staff-management CRUD (name, phone, role, random PIN), login by PIN loads role-specific UI, and order flow expands to pending->approved->assigned (received by picker)->delivered (with mandatory photo proof), with full desktop tracking/history including who/when/proof image.
- Mobile app entry must skip role selection and use PIN-only login that auto-detects and shows role UI. The picker must keep the inventory (`Kho hàng`) tab for lookup while processing orders.
- Mobile app login must be inline on the entry screen (PIN input + direct 'Vào app' button) instead of using a popup dialog.
- Set app name to 'fisd' across platforms, and use the provided logo as the launcher/external icon instead of the default Flutter icon.
- Manager role behavior should follow the picker flow, and order dispatch should skip staff approval and go directly to the picker queue.
- **Consider practical low-cost backup strategies**: store database and delivery images on Google Drive or Telegram in addition to local staff machine storage.
- **Deployment process**: Code changes should be made in the `backend/` directory of the main repository, then copied to the separate server directory/repo for pushing to Railway.

## UI/Feature Preferences
- UI/feature preference for current update: add dedicated `Khu vực` menu/page; debt screen layout should keep new-customer form on the left and customer list in the center; customer name input should open full dropdown on focus and filter while typing; area selection is required when creating/updating customers.
- Add a separate desktop Flutter page `Bán hàng` (same business intent as `Xuất hàng` but for different users) with table-style entry and immediate real-time dropdown+typing for item code/color/size; matching should be case-insensitive for convenience.
- Stock-in (`Nhập hàng`) must include explicit product code input and feature a fully refreshed layout. Focus on improving the alignment of `Nhập hàng` (not `Xuất hàng`), ensuring titles/values are straight and potentially adopting a grid-style layout similar to the debt history. Price input should not support mouse wheel increment/decrement to avoid accidental price changes.
- Popup edit/delete menus in `Khu vực` and `Xuất hàng/Kho hàng` should follow the same modern custom dialog style, visually synchronized with other modern dialogs: cleaner header, spacing, border/radius consistency, and overall more polished look.
- User prefers a cleaner, modern visual style with lighter font weights (avoid too much bold text) and softer colors; specifically wants `Xuất hàng` and `Nhập hàng` layouts to be fully re-arranged for a compact, modern, inspirational look rather than incremental tweaks.
- Change mobile orderer app bar title text from 'Người soạn đơn' to 'Order'.
- In the orderer 'Xem' popup, remove the top grouped summary lines (e.g., 'G97 • Màu Đen • 4 cái') as redundant.
- Desktop `Xuất hàng` right panel must group cart items by model + color for easier scanning.
- Quản lý > Lịch sử should use expandable order cards with Excel-style item detail tables and a wider history panel.
- Picker 'Nhận đơn' item listing must be grouped by color with multi-line, professional UI (avoid compressed one-line summaries). Quantity wheel scrolling should affect only the quantity control without moving parent lists.
- Order popups must be grouped clearly by model -> color -> size with a compact modern UI.
- Picker inventory popup (`Kho hàng` mobile) must be grouped by color then size with a compact modern card UI, including clear stock summaries, closely following the compact visual style of picker 'Nhận đơn' cards, with grouped color sections and size stock shown as chips/wrap for quick scanning. The picker inventory popup should be capped at 95% height.
- Revenue screen UI/labels must be fully in Vietnamese and support drill-down shortcut navigation by clicking breakdown rows: year → month → week → day.
- In the revenue screen, show full invoice list for the selected day with expandable Excel-style order details instead of hourly buckets. Replace 'Trung bình / đơn' with customer count, and customer filter should show 'Tất cả khách hàng' as hint but be empty/ready for typing on focus in searchable dropdown input.
- **Add a top-right back button in the revenue screen detail panel for quick reverse drill navigation (day→week→month→year).**
- In mobile picker confirm popup, place picker note input at the top (right below date and quantity summary).
- In desktop management page, hide raw image URL text and keep a cleaner modern layout with the same information structure.
- **Revenue date picker UI preference**: display day in standard calendar view only, removing custom month/year selector UI; keep a clean single-calendar layout and harmonious bottom date input styling (not oversized).
- **App dark mode** should use a modern dark-blue palette (not pure black), preserve readability, and avoid hurting text input usability; place a theme toggle in the far right of the bottom navigation area, visually separated from the main navigation tabs.

## Desktop UI Guidelines
- Interactive buttons in the desktop Flutter UI should show `SystemMouseCursors.click` cursor feedback (not `grab`).
- Stock-in page should support product image input (URL/path with quick paste) and only show add-product form (no inventory grid). Keep action buttons clustered to reduce mouse travel. The product image should be selected via file upload dialog (reuse existing behavior). 
- Stock-in UI preference: remove manual image path input; show image preview and a single upload button on the right side of the general info section; reuse the previous proven workflow that opens file dialog and stores image path via copied assets/images file. Keep form left-aligned with clear hierarchy (general info section above color groups), use 'Thêm màu' button below existing groups, remove top/right extra group/reset buttons, and use a larger prominent save button. Keep `Size` and `SL` fields adjacent for faster variant input.
- Debt page should open add-customer via popup and show selected customer's history inline on the right instead of a popup. Debt history should expand inline per record with order item details shown in dropdown.
- Pending approval screen preference: modernized card layout with clearer status/summary and more direct action controls.
- Orders screen preference: keep compact left-focused layout unchanged and only remove the `Xem` action button.

## Cronjob Repository
- For the cronjob repo, `requirements.txt` should contain only `requests==2.32.3`.