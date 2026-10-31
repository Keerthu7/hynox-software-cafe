import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtemp, rm } from 'node:fs/promises';
import { createWriteStream } from 'node:fs';
import { pipeline } from 'node:stream/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';

const run = promisify(execFile);
const root = process.cwd();
process.env.FLUTTER_SUPPRESS_ANALYTICS = 'true';
let flutter = process.env.FLUTTER_BIN || process.env.FLUTTER_ROOT && join(process.env.FLUTTER_ROOT, 'bin', 'flutter');
let tempRoot;

try {
  if (!flutter) {
    const response = await fetch('https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json');
    if (!response.ok) throw new Error(`Flutter release list request failed (${response.status}).`);
    const releases = await response.json();
    const stable = releases.releases?.find((release) => release.channel === 'stable');
    if (!stable) throw new Error('Could not find the current stable Flutter release.');
    tempRoot = await mkdtemp(join(tmpdir(), 'billdesk-flutter-'));
    const archive = join(tempRoot, 'flutter.tar.xz');
    const download = await fetch(`https://storage.googleapis.com/flutter_infra_release/releases/${stable.archive}`);
    if (!download.ok) throw new Error(`Flutter SDK download failed (${download.status}).`);
    await pipeline(download.body, createWriteStream(archive));
    await run('tar', ['-xf', archive, '-C', tempRoot], { maxBuffer: 10 * 1024 * 1024 });
    flutter = join(tempRoot, 'flutter', 'bin', 'flutter');
  }

  const common = { cwd: root, maxBuffer: 20 * 1024 * 1024 };
  // Vercel's build image can run as root while the extracted Flutter Git
  // checkout has a different owner. Git then blocks Flutter's version checks
  // as a dubious-ownership repository. Trust only this SDK checkout.
  const flutterRoot = dirname(dirname(flutter));
  await run('git', ['config', '--global', '--add', 'safe.directory', flutterRoot], common);
  await run(flutter, ['pub', 'get'], common);
  await run(flutter, [
    'build', 'web', '--release',
    '--dart-define=Hynox_REMOTE_API=true',
    `--dart-define=Hynox_META_APP_ID=${process.env.META_APP_ID || ''}`,
    `--dart-define=Hynox_META_CONFIG_ID=${process.env.META_CONFIG_ID || ''}`,
    `--dart-define=Hynox_BILLDESK_WEB_URL=${process.env.BILLDESK_WEB_URL || ''}`,
  ], common);
} catch (error) {
  process.stderr.write(`${error.stderr || ''}${error.message}\n`);
  process.exitCode = 1;
} finally {
  if (tempRoot) await rm(tempRoot, { recursive: true, force: true });
}
