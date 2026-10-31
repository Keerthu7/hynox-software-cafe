import crypto from 'node:crypto';
import { database, ensureSchema } from '../server/db.js';

export const config = { api: { bodyParser: false } };

async function rawBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(Buffer.from(chunk));
  return Buffer.concat(chunks);
}

function safeEqualHex(left, right) {
  if (!left || !right || left.length !== right.length || !/^[0-9a-f]+$/i.test(left) || !/^[0-9a-f]+$/i.test(right)) return false;
  return crypto.timingSafeEqual(Buffer.from(left, 'hex'), Buffer.from(right, 'hex'));
}

export default async function handler(req, res) {
  try {
    await ensureSchema();
    if (req.method === 'GET') {
      const mode = req.query['hub.mode'];
      const token = req.query['hub.verify_token'];
      const challenge = req.query['hub.challenge'];
      if (mode === 'subscribe' && token && token === process.env.META_WEBHOOK_VERIFY_TOKEN) {
        return res.status(200).send(String(challenge || ''));
      }
      return res.status(403).send('Forbidden');
    }
    if (req.method !== 'POST') return res.status(405).end();

    const raw = await rawBody(req);
    const signature = String(req.headers['x-hub-signature-256'] || '');
    const appSecret = process.env.META_APP_SECRET || '';
    if (!appSecret || !signature.startsWith('sha256=')) return res.status(401).end();
    const expected = crypto.createHmac('sha256', appSecret).update(raw).digest('hex');
    if (!safeEqualHex(signature.slice(7), expected)) return res.status(401).end();

    const event = JSON.parse(raw.toString('utf8'));
    const sql = database();
    for (const entry of event.entry || []) {
      for (const change of entry.changes || []) {
        for (const item of change.value?.statuses || []) {
          if (!item.id || !item.status) continue;
          const status = ['sent', 'delivered', 'read', 'failed'].includes(item.status) ? item.status : 'accepted';
          const errorCode = item.errors?.[0]?.code ? String(item.errors[0].code) : null;
          await sql`UPDATE whatsapp_receipts SET status = ${status}, error_code = ${errorCode}, updated_at = now()
            WHERE message_id = ${item.id}`;
        }
      }
    }
    return res.status(200).json({ received: true });
  } catch (error) {
    console.error('WhatsApp webhook error:', error);
    return res.status(500).end();
  }
}
