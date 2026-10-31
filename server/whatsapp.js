import crypto from 'node:crypto';
import { database } from './db.js';

function encryptionKey() {
  const encoded = process.env.WHATSAPP_TOKEN_ENCRYPTION_KEY || '';
  const key = Buffer.from(encoded, 'base64');
  if (key.length !== 32) throw new Error('WHATSAPP_TOKEN_ENCRYPTION_KEY must be a base64-encoded 32-byte key.');
  return key;
}

export function encryptToken(value) {
  const key = encryptionKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
  return [iv.toString('base64url'), cipher.getAuthTag().toString('base64url'), encrypted.toString('base64url')].join('.');
}

export function decryptToken(value) {
  const [ivPart, tagPart, bodyPart] = value.split('.');
  if (!ivPart || !tagPart || !bodyPart) throw new Error('Stored WhatsApp credential is invalid.');
  const decipher = crypto.createDecipheriv('aes-256-gcm', encryptionKey(), Buffer.from(ivPart, 'base64url'));
  decipher.setAuthTag(Buffer.from(tagPart, 'base64url'));
  return Buffer.concat([
    decipher.update(Buffer.from(bodyPart, 'base64url')),
    decipher.final(),
  ]).toString('utf8');
}

function graphBase() {
  const version = String(process.env.META_GRAPH_API_VERSION || 'v25.0').trim();
  if (!/^v\d+\.\d+$/.test(version)) throw new Error('META_GRAPH_API_VERSION must look like v25.0.');
  return `https://graph.facebook.com/${version}`;
}

export async function exchangeSignupCode(code, wabaId, phoneNumberId) {
  const appId = String(process.env.META_APP_ID || '').trim();
  const appSecret = String(process.env.META_APP_SECRET || '').trim();
  if (!appId || !appSecret) throw new Error('Meta app credentials are not configured on the server.');
  if (!code || !wabaId) throw new Error('Meta did not return all WhatsApp signup details.');

  const url = new URL(`${graphBase()}/oauth/access_token`);
  url.searchParams.set('client_id', appId);
  url.searchParams.set('client_secret', appSecret);
  url.searchParams.set('code', code);
  const response = await fetch(url, { method: 'GET' });
  const result = await response.json();
  if (!response.ok || !result.access_token) {
    throw new Error(result.error?.message || 'Meta could not complete the WhatsApp connection.');
  }

  let resolvedPhoneNumberId = phoneNumberId;
  if (!resolvedPhoneNumberId) {
    const numbersUrl = new URL(`${graphBase()}/${encodeURIComponent(wabaId)}/phone_numbers`);
    const numbersResponse = await fetch(numbersUrl, { headers: { Authorization: `Bearer ${result.access_token}` } });
    const numbers = await numbersResponse.json();
    if (!numbersResponse.ok || !Array.isArray(numbers.data) || numbers.data.length !== 1) {
      throw new Error(numbers.error?.message || 'Meta did not identify one cafe phone number. Please reconnect and select the intended number.');
    }
    resolvedPhoneNumberId = numbers.data[0].id;
  }
  const infoUrl = new URL(`${graphBase()}/${encodeURIComponent(resolvedPhoneNumberId)}`);
  infoUrl.searchParams.set('fields', 'display_phone_number,verified_name');
  const infoResponse = await fetch(infoUrl, { headers: { Authorization: `Bearer ${result.access_token}` } });
  const info = await infoResponse.json();
  if (!infoResponse.ok) {
    throw new Error(info.error?.message || 'Meta authorized the account, but the phone details could not be read.');
  }
  const subscribeResponse = await fetch(`${graphBase()}/${encodeURIComponent(wabaId)}/subscribed_apps`, {
    method: 'POST', headers: { Authorization: `Bearer ${result.access_token}` },
  });
  const subscribed = await subscribeResponse.json();
  if (!subscribeResponse.ok) {
    throw new Error(subscribed.error?.message || 'The WhatsApp account was authorized, but delivery status webhooks could not be enabled.');
  }
  return {
    wabaId,
    phoneNumberId: resolvedPhoneNumberId,
    accessToken: result.access_token,
    tokenExpiresAt: Number.isFinite(Number(result.expires_in))
      ? new Date(Date.now() + Number(result.expires_in) * 1000).toISOString()
      : null,
    displayPhone: info.display_phone_number || '',
    verifiedName: info.verified_name || '',
  };
}

export async function sendReceiptForShop(shopId, payload) {
  const sql = database();
  const [connection] = await sql`SELECT phone_number_id, encrypted_token, status
    FROM whatsapp_connections WHERE shop_id = ${shopId} LIMIT 1`;
  if (!connection || connection.status !== 'connected') return { status: 'connection_needed' };
  if (payload.invoiceConsent !== true) return { status: 'consent_required' };
  if (!process.env.WHATSAPP_RECEIPT_TEMPLATE) return { status: 'template_not_configured' };
  if (!payload.customerPhone || !/^\+?[1-9]\d{7,14}$/.test(payload.customerPhone.replace(/[\s()-]/g, ''))) {
    return { status: 'phone_needed' };
  }
  const pdf = Buffer.from(payload.pdf || '', 'base64');
  // Base64 plus JSON overhead must remain below Vercel's request body limit.
  if (!pdf.length || pdf.length > 3 * 1024 * 1024) return { status: 'failed', errorCode: 'invalid_pdf' };

  const accessToken = decryptToken(connection.encrypted_token);
  const base = graphBase();
  const upload = new FormData();
  upload.append('messaging_product', 'whatsapp');
  upload.append('type', 'application/pdf');
  upload.append('file', new Blob([pdf], { type: 'application/pdf' }), `${payload.orderId}-receipt.pdf`);
  const mediaResponse = await fetch(`${base}/${encodeURIComponent(connection.phone_number_id)}/media`, {
    method: 'POST', headers: { Authorization: `Bearer ${accessToken}` }, body: upload,
  });
  const media = await mediaResponse.json();
  if (!mediaResponse.ok || !media.id) {
    return { status: 'failed', errorCode: String(media.error?.code || 'media_upload_failed') };
  }

  const recipient = payload.customerPhone.replace(/[\s()-]/g, '').replace(/^\+/, '');
  const templateName = process.env.WHATSAPP_RECEIPT_TEMPLATE;
  const language = process.env.WHATSAPP_RECEIPT_TEMPLATE_LANGUAGE || 'en';
  const total = String(payload.total || '');
  const messageResponse = await fetch(`${base}/${encodeURIComponent(connection.phone_number_id)}/messages`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      to: recipient,
      type: 'template',
      template: {
        name: templateName,
        language: { code: language },
        components: [
          { type: 'header', parameters: [{ type: 'document', document: { id: media.id, filename: `${payload.orderId}-receipt.pdf` } }] },
          { type: 'body', parameters: [
            { type: 'text', text: String(payload.customerName || 'Customer') },
            { type: 'text', text: String(payload.businessName || 'Cafe') },
            { type: 'text', text: total },
          ] },
        ],
      },
    }),
  });
  const sent = await messageResponse.json();
  if (!messageResponse.ok || !sent.messages?.[0]?.id) {
    return { status: 'failed', errorCode: String(sent.error?.code || 'send_failed') };
  }
  return { status: 'accepted', messageId: sent.messages[0].id };
}
