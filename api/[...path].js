import crypto from 'node:crypto';
import { database, ensureSchema, hashPassword, randomToken, secureEqualHex, tokenHash } from '../server/db.js';
import { encryptToken, exchangeSignupCode, sendReceiptForShop } from '../server/whatsapp.js';

function json(res, status, value) {
  res.status(status).setHeader('Content-Type', 'application/json; charset=utf-8').end(JSON.stringify(value));
}

function body(req) {
  if (!req.body) return {};
  if (typeof req.body === 'object') return req.body;
  try { return JSON.parse(req.body); } catch { return {}; }
}

function slugify(value) {
  const slug = String(value || '').toLowerCase().normalize('NFKD')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 36);
  return slug || `shop-${Date.now()}`;
}

async function auth(req, role) {
  const raw = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!raw || raw === 'local') throw Object.assign(new Error('Please sign in again.'), { status: 401 });
  const sql = database();
  const [user] = await sql`SELECT u.phone, u.role, u.shop_id, u.owner_name, u.email
    FROM hynox_sessions s JOIN hynox_users u ON u.phone = s.phone
    WHERE s.token_hash = ${tokenHash(raw)} AND s.expires_at > now() LIMIT 1`;
  if (!user) throw Object.assign(new Error('Your session expired. Please sign in again.'), { status: 401 });
  if (role && user.role !== role) throw Object.assign(new Error('This account cannot access that workspace.'), { status: 403 });
  return user;
}

async function subscription(sql, shopId) {
  const [row] = await sql`SELECT data FROM hynox_subscriptions WHERE shop_id = ${shopId} LIMIT 1`;
  const result = row?.data || { status: 'none' };
  const expiry = Date.parse(result.expiresAt || '');
  if (['active', 'trial'].includes(result.status) && Number.isFinite(expiry) && expiry <= Date.now()) {
    return { ...result, status: 'expired' };
  }
  return result;
}

async function plans(sql) {
  const rows = await sql`SELECT data FROM hynox_plans ORDER BY id`;
  return rows.map((row) => row.data);
}

async function adminDashboard(sql, user) {
  const rows = await sql`SELECT s.id AS slug, s.name, s.address, s.state,
      u.phone AS "loginPhone", u.owner_name AS owner, u.email,
      sub.data AS subscription
    FROM hynox_shops s LEFT JOIN hynox_users u ON u.shop_id = s.id AND u.role = 'vendor'
    LEFT JOIN hynox_subscriptions sub ON sub.shop_id = s.id ORDER BY s.created_at DESC`;
  const vendorList = rows.map((row) => ({
    slug: row.slug, name: row.name, address: row.address,
    phone: row.state?.profile?.phone || row.loginPhone || '', loginPhone: row.loginPhone,
    orders: Array.isArray(row.state?.orders) ? row.state.orders.length : 0,
    owner: row.owner || '', email: row.email || '',
    subscription: row.subscription || { status: 'none' },
  }));
  const profileRows = await sql`SELECT data FROM hynox_admin_profiles WHERE phone = ${user.phone} LIMIT 1`;
  const allPlans = await plans(sql);
  const statuses = ['active', 'trial', 'expired', 'none', 'cancelled'];
  return {
    vendors: vendorList,
    totalVendors: vendorList.length,
    plans: allPlans,
    profile: { name: 'Hynox team', email: user.email || '', contactPhone: user.phone,
      ...(profileRows[0]?.data || {}), loginPhone: user.phone },
    counts: {
      ...Object.fromEntries(statuses.map((status) => [status,
        vendorList.filter((vendor) => vendor.subscription.status === status).length])),
      pending: vendorList.filter((vendor) => vendor.subscription.requestStatus === 'pending').length,
    },
  };
}

async function paidCatalog(sql, user) {
  const activePlans = (await plans(sql)).filter((plan) => plan.active === true);
  return { plans: activePlans, subscription: await subscription(sql, user.shop_id) };
}

async function insertShop(sql, values, slug) {
  const now = new Date();
  const state = {
    businessName: String(values.name || 'My Café'),
    profile: { phone: String(values.phone || ''), address: String(values.address || '') },
    trialStartedAt: now.toISOString(),
    nextOrderNumber: 1001,
    menu: [], orders: [],
  };
  await sql`INSERT INTO hynox_shops (id, name, address, state) VALUES
    (${slug}, ${state.businessName}, ${state.profile.address}, ${JSON.stringify(state)}::jsonb)`;
  await sql`INSERT INTO hynox_subscriptions (shop_id, data) VALUES
    (${slug}, ${JSON.stringify({ status: 'trial', expiresAt: new Date(now.getTime() + 15 * 86400000).toISOString() })}::jsonb)`;
}

async function handle(req, res) {
  await ensureSchema();
  const sql = database();
  const pathValue = req.query?.path;
  // Vercel's catch-all function does not populate `query.path` consistently
  // for every deployment configuration. Fall back to the actual request URL
  // so routes such as /api/login are still dispatched to the right handler.
  const path = pathValue !== undefined
    ? '/' + (Array.isArray(pathValue) ? pathValue.join('/') : String(pathValue))
    : new URL(req.url || '/', `https://${req.headers.host || 'localhost'}`).pathname
        .replace(/^\/api(?=\/|$)/, '') || '/';
  const values = body(req);

  if (path === '/health' && req.method === 'GET') return json(res, 200, { ok: true });

  if (path === '/login' && req.method === 'POST') {
    const phone = String(values.phone || '').replace(/\D/g, '');
    const password = String(values.password || '');
    if (!/^\d{10}$/.test(phone) || !password) return json(res, 400, { error: 'Enter your 10-digit mobile number and password.' });
    const [user] = await sql`SELECT phone, role, shop_id, password_salt, password_hash
      FROM hynox_users WHERE phone = ${phone} LIMIT 1`;
    if (!user) return json(res, 401, { error: 'Account not found. Ask the Hynox team to create your vendor account.' });
    const candidate = await hashPassword(password, user.password_salt);
    if (!secureEqualHex(candidate, user.password_hash)) return json(res, 401, { error: 'The password does not match.' });
    const token = randomToken();
    await sql`INSERT INTO hynox_sessions (token_hash, phone, expires_at)
      VALUES (${tokenHash(token)}, ${phone}, ${new Date(Date.now() + 30 * 86400000).toISOString()})`;
    return json(res, 200, { token, role: user.role, shop: user.shop_id });
  }

  if (path === '/logout' && req.method === 'POST') {
    const raw = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
    if (raw) await sql`DELETE FROM hynox_sessions WHERE token_hash = ${tokenHash(raw)}`;
    return json(res, 200, {});
  }

  if (path === '/whatsapp/config' && req.method === 'GET') {
    if (!process.env.META_APP_ID || !process.env.META_CONFIG_ID) {
      return json(res, 503, { error: 'Meta Embedded Signup is not configured yet.' });
    }
    return json(res, 200, {
      appId: process.env.META_APP_ID,
      configId: process.env.META_CONFIG_ID,
      webUrl: process.env.BILLDESK_WEB_URL || '',
    });
  }

  const user = await auth(req);

  if (path === '/state' && req.method === 'GET') {
    if (user.role !== 'vendor') return json(res, 403, { error: 'This account cannot access a café workspace.' });
    const [shop] = await sql`SELECT state, revision FROM hynox_shops WHERE id = ${user.shop_id} LIMIT 1`;
    if (!shop) return json(res, 404, { error: 'Vendor workspace not found.' });
    return json(res, 200, { state: shop.state, revision: shop.revision });
  }

  if (path === '/state' && req.method === 'POST') {
    if (user.role !== 'vendor') return json(res, 403, { error: 'This account cannot access a café workspace.' });
    const state = values.state;
    if (!state || typeof state !== 'object') return json(res, 400, { error: 'Workspace data is invalid.' });
    const rows = await sql`UPDATE hynox_shops SET state = ${JSON.stringify(state)}::jsonb,
      name = ${String(state.businessName || 'My Café')}, address = ${String(state.profile?.address || '')},
      revision = revision + 1 WHERE id = ${user.shop_id} AND revision = ${Number(values.revision)}
      RETURNING revision`;
    if (!rows.length) return json(res, 409, { error: 'This workspace changed in another session. Reload and try again.' });
    return json(res, 200, { revision: rows[0].revision });
  }

  if (path === '/catalog' && req.method === 'GET') {
    if (user.role !== 'vendor') return json(res, 403, { error: 'This account cannot access vendor plans.' });
    return json(res, 200, await paidCatalog(sql, user));
  }

  if (path === '/password' && req.method === 'POST') {
    const current = String(values.current || '');
    const next = String(values.new || '');
    if (next.length < 8) return json(res, 400, { error: 'Use at least 8 password characters.' });
    const [record] = await sql`SELECT password_salt, password_hash FROM hynox_users WHERE phone = ${user.phone}`;
    const oldHash = await hashPassword(current, record.password_salt);
    if (!secureEqualHex(oldHash, record.password_hash)) return json(res, 400, { error: 'Current password is incorrect.' });
    const salt = crypto.randomBytes(16).toString('hex');
    const newHash = await hashPassword(next, salt);
    await sql`UPDATE hynox_users SET password_salt = ${salt}, password_hash = ${newHash} WHERE phone = ${user.phone}`;
    await sql`DELETE FROM hynox_sessions WHERE phone = ${user.phone} AND token_hash <> ${tokenHash(String(req.headers.authorization || '').replace(/^Bearer\s+/i, ''))}`;
    return json(res, 200, {});
  }

  if (path === '/subscription/request' && req.method === 'POST') {
    if (user.role !== 'vendor') return json(res, 403, { error: 'This action is for vendor accounts.' });
    const [planRow] = await sql`SELECT data FROM hynox_plans WHERE id = ${String(values.planId || '')} LIMIT 1`;
    if (!planRow?.data?.active) return json(res, 400, { error: 'This plan is unavailable.' });
    const current = await subscription(sql, user.shop_id);
    const next = { ...current, requestedPlanId: planRow.data.id, requestedPlanName: planRow.data.name,
      requestedPrice: planRow.data.price, requestStatus: 'pending', requestedAt: new Date().toISOString() };
    await sql`INSERT INTO hynox_subscriptions (shop_id, data) VALUES (${user.shop_id}, ${JSON.stringify(next)}::jsonb)
      ON CONFLICT (shop_id) DO UPDATE SET data = EXCLUDED.data`;
    return json(res, 200, await paidCatalog(sql, user));
  }

  if (path === '/subscription/pay' && req.method === 'POST') {
    if (user.role !== 'vendor') return json(res, 403, { error: 'This action is for vendor accounts.' });
    const [planRow] = await sql`SELECT data FROM hynox_plans WHERE id = ${String(values.planId || '')} LIMIT 1`;
    if (!planRow?.data?.active) return json(res, 400, { error: 'This plan is unavailable.' });
    const current = await subscription(sql, user.shop_id);
    const currentExpiry = Date.parse(current.expiresAt || '');
    const now = Date.now();
    const expiresAt = new Date((Number.isFinite(currentExpiry) && currentExpiry > now ? currentExpiry : now) + 30 * 86400000).toISOString();
    const next = { status: 'active', planId: planRow.data.id, planName: planRow.data.name,
      price: planRow.data.price, expiresAt, paidAt: new Date().toISOString(), paymentMethod: values.method || 'UPI' };
    await sql`INSERT INTO hynox_subscriptions (shop_id, data) VALUES (${user.shop_id}, ${JSON.stringify(next)}::jsonb)
      ON CONFLICT (shop_id) DO UPDATE SET data = EXCLUDED.data`;
    return json(res, 200, await paidCatalog(sql, user));
  }

  if (path === '/admin' && req.method === 'GET') {
    if (user.role !== 'team') return json(res, 403, { error: 'This account cannot access the Hynox dashboard.' });
    return json(res, 200, await adminDashboard(sql, user));
  }

  if (path === '/admin/profile' && req.method === 'POST') {
    if (user.role !== 'team') return json(res, 403, { error: 'This action is for the Hynox team.' });
    await sql`INSERT INTO hynox_admin_profiles (phone, data) VALUES (${user.phone}, ${JSON.stringify(values)}::jsonb)
      ON CONFLICT (phone) DO UPDATE SET data = EXCLUDED.data`;
    return json(res, 200, await adminDashboard(sql, user));
  }

  if (path === '/admin/vendor' && req.method === 'POST') {
    if (user.role !== 'team') return json(res, 403, { error: 'This action is for the Hynox team.' });
    const phone = String(values.phone || '').replace(/\D/g, '');
    if (!/^\d{10}$/.test(phone)) return json(res, 400, { error: 'Enter a 10-digit mobile number.' });
    if (values.slug) {
      const shopId = String(values.slug);
      const [shop] = await sql`SELECT id FROM hynox_shops WHERE id = ${shopId} LIMIT 1`;
      if (!shop) return json(res, 404, { error: 'Vendor not found.' });
      await sql`UPDATE hynox_shops SET name = ${String(values.name || '')}, address = ${String(values.address || '')},
        state = jsonb_set(jsonb_set(state, '{businessName}', to_jsonb(${String(values.name || '')}::text)),
        '{profile,address}', to_jsonb(${String(values.address || '')}::text), true) WHERE id = ${shopId}`;
      await sql`UPDATE hynox_users SET owner_name = ${String(values.owner || '')}, email = ${String(values.email || '')}
        WHERE shop_id = ${shopId} AND role = 'vendor'`;
      return json(res, 200, await adminDashboard(sql, user));
    }
    if (String(values.password || '').length < 8) return json(res, 400, { error: 'Use at least 8 password characters for a new vendor.' });
    const [existing] = await sql`SELECT phone FROM hynox_users WHERE phone = ${phone} LIMIT 1`;
    if (existing) return json(res, 409, { error: 'This mobile number already has an account.' });
    const shopId = `${slugify(values.name)}-${crypto.randomBytes(3).toString('hex')}`;
    await insertShop(sql, { ...values, phone }, shopId);
    const salt = crypto.randomBytes(16).toString('hex');
    const passwordHash = await hashPassword(String(values.password), salt);
    await sql`INSERT INTO hynox_users (phone, role, shop_id, password_salt, password_hash, owner_name, email)
      VALUES (${phone}, 'vendor', ${shopId}, ${salt}, ${passwordHash}, ${String(values.owner || '')}, ${String(values.email || '')})`;
    return json(res, 200, await adminDashboard(sql, user));
  }

  if (path === '/admin/plan' && req.method === 'POST') {
    if (user.role !== 'team') return json(res, 403, { error: 'This action is for the Hynox team.' });
    const id = values.id ? String(values.id) : `plan-${Date.now()}`;
    let version = 1;
    if (values.id) {
      const [old] = await sql`SELECT data FROM hynox_plans WHERE id = ${id}`;
      if (!old) return json(res, 404, { error: 'Plan not found.' });
      version = Number(old.data.version || 0) + 1;
    }
    const plan = { ...values, id, version };
    await sql`INSERT INTO hynox_plans (id, data) VALUES (${id}, ${JSON.stringify(plan)}::jsonb)
      ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data`;
    return json(res, 200, await adminDashboard(sql, user));
  }

  if (path === '/admin/subscription' && req.method === 'POST') {
    if (user.role !== 'team') return json(res, 403, { error: 'This action is for the Hynox team.' });
    const shopId = String(values.shop || '');
    const status = String(values.status || 'none');
    const old = await subscription(sql, shopId);
    const next = { ...values };
    for (const key of ['requestStatus','requestedPlanId','requestedPlanName','requestedPrice','requestedAt']) delete next[key];
    if (['active', 'trial'].includes(status)) {
      const expiry = Date.parse(values.expiresAt || '');
      if (!Number.isFinite(expiry) || expiry <= Date.now()) return json(res, 400, { error: 'Enter a future expiry date.' });
      next.expiresAt = new Date(expiry).toISOString();
    }
    if (status === 'active') {
      const [planRow] = await sql`SELECT data FROM hynox_plans WHERE id = ${String(values.planId || '')}`;
      if (!planRow?.data || planRow.data.active === false) return json(res, 400, { error: 'Choose a published plan.' });
      next.planName = planRow.data.name; next.price = planRow.data.price;
    }
    if (!Object.keys(next).length) Object.assign(next, old);
    await sql`INSERT INTO hynox_subscriptions (shop_id, data) VALUES (${shopId}, ${JSON.stringify(next)}::jsonb)
      ON CONFLICT (shop_id) DO UPDATE SET data = EXCLUDED.data`;
    return json(res, 200, await adminDashboard(sql, user));
  }

  if (path === '/admin/subscription/accept' && req.method === 'POST') {
    if (user.role !== 'team') return json(res, 403, { error: 'This action is for the Hynox team.' });
    const shopId = String(values.shop || '');
    const current = await subscription(sql, shopId);
    const planId = String(values.planId || current.requestedPlanId || '');
    const [planRow] = await sql`SELECT data FROM hynox_plans WHERE id = ${planId}`;
    if (!planRow?.data || planRow.data.active === false) return json(res, 404, { error: 'Plan not found.' });
    const oldExpiry = Date.parse(current.expiresAt || '');
    const now = Date.now();
    const expiresAt = new Date((Number.isFinite(oldExpiry) && oldExpiry > now ? oldExpiry : now) + 30 * 86400000).toISOString();
    const next = { status: 'active', planId, planName: planRow.data.name, price: planRow.data.price,
      expiresAt, activatedAt: new Date().toISOString(), activatedBy: 'Hynox team' };
    await sql`INSERT INTO hynox_subscriptions (shop_id, data) VALUES (${shopId}, ${JSON.stringify(next)}::jsonb)
      ON CONFLICT (shop_id) DO UPDATE SET data = EXCLUDED.data`;
    return json(res, 200, await adminDashboard(sql, user));
  }

  if (path === '/whatsapp/status' && req.method === 'GET') {
    if (user.role !== 'vendor') return json(res, 403, { error: 'WhatsApp connection is available to vendor accounts.' });
    const [row] = await sql`SELECT display_phone, verified_name, status, connected_at, token_expires_at
      FROM whatsapp_connections WHERE shop_id = ${user.shop_id} LIMIT 1`;
    return json(res, 200, row ? { connected: row.status === 'connected', phone: row.display_phone,
      businessName: row.verified_name, connectedAt: row.connected_at,
      tokenExpiresAt: row.token_expires_at } : { connected: false });
  }

  if (path === '/whatsapp/connect' && req.method === 'POST') {
    if (user.role !== 'vendor') return json(res, 403, { error: 'WhatsApp connection is available to vendor accounts.' });
    const connected = await exchangeSignupCode(String(values.code || ''), String(values.wabaId || ''), String(values.phoneNumberId || ''));
    await sql`INSERT INTO whatsapp_connections (shop_id, waba_id, phone_number_id, display_phone, verified_name, encrypted_token, token_expires_at, status)
      VALUES (${user.shop_id}, ${connected.wabaId}, ${connected.phoneNumberId}, ${connected.displayPhone},
      ${connected.verifiedName}, ${encryptToken(connected.accessToken)}, ${connected.tokenExpiresAt}, 'connected')
      ON CONFLICT (shop_id) DO UPDATE SET waba_id = EXCLUDED.waba_id, phone_number_id = EXCLUDED.phone_number_id,
      display_phone = EXCLUDED.display_phone, verified_name = EXCLUDED.verified_name,
      encrypted_token = EXCLUDED.encrypted_token, token_expires_at = EXCLUDED.token_expires_at,
      status = 'connected', connected_at = now()`;
    return json(res, 200, { connected: true, phone: connected.displayPhone, businessName: connected.verifiedName });
  }

  if (path === '/whatsapp/disconnect' && req.method === 'POST') {
    if (user.role !== 'vendor') return json(res, 403, { error: 'WhatsApp connection is available to vendor accounts.' });
    await sql`DELETE FROM whatsapp_connections WHERE shop_id = ${user.shop_id}`;
    return json(res, 200, { connected: false });
  }

  if (path === '/receipts' && req.method === 'GET') {
    if (user.role !== 'vendor') return json(res, 403, { error: 'This account cannot view vendor receipts.' });
    const receipts = await sql`SELECT order_id, status FROM whatsapp_receipts WHERE shop_id = ${user.shop_id}`;
    return json(res, 200, { receipts });
  }

  if (path === '/receipt' && req.method === 'POST') {
    if (user.role !== 'vendor') return json(res, 403, { error: 'This account cannot send vendor receipts.' });
    const orderId = String(values.orderId || '');
    if (!orderId) return json(res, 400, { error: 'Receipt order ID is required.' });
    const result = await sendReceiptForShop(user.shop_id, { ...values, orderId });
    await sql`INSERT INTO whatsapp_receipts (shop_id, order_id, status, message_id, error_code)
      VALUES (${user.shop_id}, ${orderId}, ${result.status}, ${result.messageId || null}, ${result.errorCode || null})
      ON CONFLICT (shop_id, order_id) DO UPDATE SET status = EXCLUDED.status,
      message_id = EXCLUDED.message_id, error_code = EXCLUDED.error_code, updated_at = now()`;
    return json(res, 200, { orderId, status: result.status });
  }

  return json(res, 404, { error: 'API route not found.' });
}

export default async function handler(req, res) {
  try {
    await handle(req, res);
  } catch (error) {
    console.error('BillDesk API error:', error);
    json(res, error.status || 500, { error: error.status ? error.message : 'The server could not complete this request.' });
  }
}
