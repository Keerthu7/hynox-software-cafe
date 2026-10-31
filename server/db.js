import { neon } from '@neondatabase/serverless';

let schemaPromise;

export function database() {
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is not configured. Connect Neon to this Vercel project first.');
  }
  return neon(process.env.DATABASE_URL);
}

export async function ensureSchema() {
  if (!schemaPromise) {
    schemaPromise = (async () => {
      const sql = database();
      await sql`CREATE TABLE IF NOT EXISTS hynox_users (
        phone TEXT PRIMARY KEY,
        role TEXT NOT NULL CHECK (role IN ('team','vendor')),
        shop_id TEXT,
        password_salt TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        owner_name TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`;
      await sql`CREATE TABLE IF NOT EXISTS hynox_shops (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT NOT NULL DEFAULT '',
        state JSONB NOT NULL,
        revision INTEGER NOT NULL DEFAULT 1,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`;
      await sql`CREATE TABLE IF NOT EXISTS hynox_subscriptions (
        shop_id TEXT PRIMARY KEY REFERENCES hynox_shops(id) ON DELETE CASCADE,
        data JSONB NOT NULL DEFAULT '{}'::jsonb
      )`;
      await sql`CREATE TABLE IF NOT EXISTS hynox_plans (
        id TEXT PRIMARY KEY,
        data JSONB NOT NULL
      )`;
      await sql`CREATE TABLE IF NOT EXISTS hynox_admin_profiles (
        phone TEXT PRIMARY KEY REFERENCES hynox_users(phone) ON DELETE CASCADE,
        data JSONB NOT NULL DEFAULT '{}'::jsonb
      )`;
      await sql`CREATE TABLE IF NOT EXISTS hynox_sessions (
        token_hash TEXT PRIMARY KEY,
        phone TEXT NOT NULL REFERENCES hynox_users(phone) ON DELETE CASCADE,
        expires_at TIMESTAMPTZ NOT NULL
      )`;
      await sql`CREATE INDEX IF NOT EXISTS hynox_sessions_expiry_idx ON hynox_sessions(expires_at)`;
      await sql`CREATE TABLE IF NOT EXISTS whatsapp_connections (
        shop_id TEXT PRIMARY KEY REFERENCES hynox_shops(id) ON DELETE CASCADE,
        waba_id TEXT NOT NULL,
        phone_number_id TEXT NOT NULL,
        display_phone TEXT NOT NULL DEFAULT '',
        verified_name TEXT NOT NULL DEFAULT '',
        encrypted_token TEXT NOT NULL,
        token_expires_at TIMESTAMPTZ,
        status TEXT NOT NULL DEFAULT 'connected',
        connected_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`;
      await sql`ALTER TABLE whatsapp_connections ADD COLUMN IF NOT EXISTS token_expires_at TIMESTAMPTZ`;
      await sql`CREATE TABLE IF NOT EXISTS whatsapp_receipts (
        shop_id TEXT NOT NULL REFERENCES hynox_shops(id) ON DELETE CASCADE,
        order_id TEXT NOT NULL,
        status TEXT NOT NULL,
        message_id TEXT,
        error_code TEXT,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        PRIMARY KEY (shop_id, order_id)
      )`;
      await sql`CREATE INDEX IF NOT EXISTS whatsapp_receipts_message_idx ON whatsapp_receipts(message_id)`;
      await sql`DELETE FROM hynox_sessions WHERE expires_at < now()`;

      const plan = {
        id: 'starter', name: 'Starter', price: 9900,
        features: ['Billing', 'Customers', 'Reports', 'WhatsApp Bills'],
        active: true, version: 1,
      };
      await sql`INSERT INTO hynox_plans (id, data) VALUES (${plan.id}, ${JSON.stringify(plan)}::jsonb)
        ON CONFLICT (id) DO NOTHING`;

      const adminPhone = process.env.HYNOX_ADMIN_PHONE?.replace(/\D/g, '');
      const adminPassword = process.env.HYNOX_ADMIN_PASSWORD;
      if (adminPhone && adminPassword && /^\d{10}$/.test(adminPhone)) {
        const existing = await sql`SELECT phone FROM hynox_users WHERE phone = ${adminPhone} LIMIT 1`;
        if (existing.length === 0) {
          const salt = crypto.randomBytes(16).toString('hex');
          const passwordHash = await hashPassword(adminPassword, salt);
          await sql`INSERT INTO hynox_users (phone, role, password_salt, password_hash, owner_name)
            VALUES (${adminPhone}, 'team', ${salt}, ${passwordHash}, 'Hynox team')`;
        }
      }
    })().catch((error) => {
      schemaPromise = undefined;
      throw error;
    });
  }
  return schemaPromise;
}

import crypto from 'node:crypto';
import { promisify } from 'node:util';
const scrypt = promisify(crypto.scrypt);

export async function hashPassword(password, salt) {
  return (await scrypt(password, salt, 64)).toString('hex');
}

export function secureEqualHex(a, b) {
  if (!/^[0-9a-f]+$/i.test(a) || !/^[0-9a-f]+$/i.test(b) || a.length !== b.length) return false;
  return crypto.timingSafeEqual(Buffer.from(a, 'hex'), Buffer.from(b, 'hex'));
}

export function randomToken() {
  return crypto.randomBytes(32).toString('base64url');
}

export function tokenHash(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}
