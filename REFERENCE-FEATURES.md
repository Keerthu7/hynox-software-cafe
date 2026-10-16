# Billza reference inspection

Inspected the signed-in vendor portal at https://hynox-abcd.vercel.app/ on 13 October 2026.

## Observed features

- Mobile-number/password vendor sign-in.
- Vendor identity, owner name, plan label, mobile bottom navigation and desktop sidebar.
- Dashboard: sales, bill count, cash/UPI totals, comparison percentages, weekly sales chart, recent bills and quick actions.
- Billing: customer name and ten-digit mobile number, product search, category filters, add/increment/decrement items, subtotal, configured percentage tax, total, generated bill number and clear draft.
- Billing validates customer name/phone before continuing to payment.
- Products: create a product with name, price and category; catalog list with deletion controls.
- Settings: business name, phone, address, logo upload, GSTIN, tax rate, invoice prefix and WhatsApp greeting.
- The billing page explicitly says WhatsApp will open after bill creation. Automatic background PDF delivery was not verified.

## Visible but not verified as working

- Bills, Reports and Staff & roles change the section label but display the same dashboard.
- Mobile menu, Add custom item and Add discount did not reveal an interface when clicked.
- Payment completion, actual WhatsApp sending, logo upload and deletion were not executed; inspection did not create bills or send messages.
- No separate Hynox administration portal was visible in the inspected vendor account.

## Additional requirements from this project

- Separate team and vendor URLs, authenticated sessions and vendor isolation.
- Automatic PDF creation after confirmed payment.
- PDF includes bill, greeting and a clickable review link.
- WhatsApp delivery using a configured Business Platform sender; show actual connection/delivery status.
- Preserve the working pay-later, refund and order-history features already in Hynox.

Reference screen labels are evidence of requested functionality, not proof that the reference backend implements it. Report totals in Hynox must come from stored transactions rather than copying the reference's displayed numbers.
