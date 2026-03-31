import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { readFileSync } from 'fs';
import { isAbsolute, join } from 'path';
import { Repository } from 'typeorm';
import * as admin from 'firebase-admin';
import { PushDevice } from './push-device.entity';
import { User } from '../users/user.entity';
import {
  ClientNotificationPreferences,
  DEFAULT_CLIENT_NOTIFICATION_PREFS,
  NotificationChannel,
  mergeClientNotificationPrefs,
} from './client-notification-preferences';

function readServiceAccountJson(
  log: Logger,
  inlineEnv: string | undefined,
  pathEnv: string | undefined,
  label: string,
): string | null {
  const inline = inlineEnv?.trim();
  if (inline) return inline;
  const rel = pathEnv?.trim();
  if (!rel) return null;
  const abs = isAbsolute(rel) ? rel : join(process.cwd(), rel);
  try {
    return readFileSync(abs, 'utf8');
  } catch (e) {
    log.warn(`FCM ${label}: не удалось прочитать файл (${abs}): ${e}`);
    return null;
  }
}

function defaultFirebaseAppExists(): boolean {
  try {
    admin.app();
    return true;
  } catch {
    return false;
  }
}

function namedFirebaseAppExists(name: string): boolean {
  try {
    admin.app(name);
    return true;
  } catch {
    return false;
  }
}

@Injectable()
export class FcmPushService {
  private readonly log = new Logger(FcmPushService.name);
  private messagingClient: admin.messaging.Messaging | null = null;
  private messagingBusiness: admin.messaging.Messaging | null = null;

  constructor(
    @InjectRepository(PushDevice) private pushRepo: Repository<PushDevice>,
    @InjectRepository(User) private userRepo: Repository<User>,
  ) {
    const clientJson = readServiceAccountJson(
      this.log,
      process.env.FIREBASE_SERVICE_ACCOUNT_JSON,
      process.env.FIREBASE_SERVICE_ACCOUNT_PATH,
      'клиент',
    );
    if (clientJson?.length) {
      try {
        const cred = JSON.parse(clientJson) as admin.ServiceAccount;
        if (!defaultFirebaseAppExists()) {
          admin.initializeApp({ credential: admin.credential.cert(cred) });
        }
        this.messagingClient = admin.messaging();
        this.log.log('FCM: клиентский Firebase-проект инициализирован');
      } catch (e) {
        this.log.warn(`FCM клиент: ${e}`);
      }
    } else {
      this.log.warn(
        'FCM: задайте FIREBASE_SERVICE_ACCOUNT_JSON или FIREBASE_SERVICE_ACCOUNT_PATH (клиент) — пуши на клиентские токены отключены',
      );
    }

    const businessJson = readServiceAccountJson(
      this.log,
      process.env.FIREBASE_BUSINESS_SERVICE_ACCOUNT_JSON,
      process.env.FIREBASE_BUSINESS_SERVICE_ACCOUNT_PATH,
      'Business',
    );
    if (businessJson?.length) {
      try {
        const cred = JSON.parse(businessJson) as admin.ServiceAccount;
        if (!namedFirebaseAppExists('business')) {
          admin.initializeApp({ credential: admin.credential.cert(cred) }, 'business');
        }
        this.messagingBusiness = admin.messaging(admin.app('business'));
        this.log.log('FCM: Firebase-проект Business инициализирован');
      } catch (e) {
        this.log.warn(`FCM Business: ${e}`);
      }
    } else {
      this.log.warn(
        'FCM: FIREBASE_BUSINESS_SERVICE_ACCOUNT_PATH не задан — пуши на приложение Business отключены',
      );
    }
  }

  async getUserPrefs(userId: string): Promise<ClientNotificationPreferences> {
    const u = await this.userRepo.findOne({ where: { id: userId } });
    if (!u) return { ...DEFAULT_CLIENT_NOTIFICATION_PREFS };
    return mergeClientNotificationPrefs((u as any).notificationPreferences);
  }

  private channelAllowed(prefs: ClientNotificationPreferences, channel: NotificationChannel): boolean {
    if (!prefs.pushEnabled) return false;
    switch (channel) {
      case 'chat':
        return prefs.chatMessages;
      case 'order':
        return prefs.orderUpdates;
      case 'promotion':
        return prefs.promotions;
      case 'reminder':
        return prefs.reminders;
      default:
        return true;
    }
  }

  /**
   * Отправка data+notification на все токены пользователя.
   * Токены из проекта клиента и Business обрабатываются разными Firebase Messaging (разные google-services).
   */
  async sendToUser(
    userId: string,
    channel: NotificationChannel,
    title: string,
    body: string,
    data: Record<string, string>,
    collapse?: { androidTag?: string; apnsThreadId?: string },
  ): Promise<void> {
    const prefs = await this.getUserPrefs(userId);
    if (!prefs.pushEnabled) return;
    if (!this.channelAllowed(prefs, channel)) return;

    const devices = await this.pushRepo.find({ where: { userId } });
    const clientTokens = devices
      .filter((d) => (d.fcmApp ?? 'client') === 'client')
      .map((d) => d.deviceToken)
      .filter((t) => t && t.length > 8);
    const businessTokens = devices
      .filter((d) => d.fcmApp === 'business')
      .map((d) => d.deviceToken)
      .filter((t) => t && t.length > 8);

    const dataStr: Record<string, string> = { ...data };
    for (const k of Object.keys(dataStr)) {
      if (dataStr[k] == null) delete dataStr[k];
    }

    await this.sendMulticast(
      this.messagingClient,
      clientTokens,
      title,
      body,
      dataStr,
      collapse,
      'autohub_messages',
    );
    await this.sendMulticast(
      this.messagingBusiness,
      businessTokens,
      title,
      body,
      dataStr,
      collapse,
      'autohub_business',
    );
  }

  private async sendMulticast(
    messaging: admin.messaging.Messaging | null,
    tokens: string[],
    title: string,
    body: string,
    dataStr: Record<string, string>,
    collapse: { androidTag?: string; apnsThreadId?: string } | undefined,
    androidChannelId: string,
  ): Promise<void> {
    if (!messaging || !tokens.length) return;

    const androidNotif: Record<string, unknown> = {
      channelId: androidChannelId,
      sound: 'default',
      defaultSound: true,
      defaultVibrateTimings: true,
      visibility: 'public',
    };
    if (collapse?.androidTag) {
      androidNotif['tag'] = collapse.androidTag.slice(0, 64);
    }

    const apsPayload: Record<string, unknown> = {
      sound: 'default',
      badge: 1,
    };
    if (collapse?.apnsThreadId) {
      apsPayload['thread-id'] = collapse.apnsThreadId.slice(0, 128);
    }

    try {
      const res = await messaging.sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: dataStr,
        android: {
          priority: 'high',
          notification: androidNotif as admin.messaging.AndroidNotification,
        },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: {
            aps: apsPayload as admin.messaging.Aps,
          },
        },
      });
      if (res.failureCount > 0) {
        const first = res.responses.find((r) => !r.success);
        const detail = first?.error ? ` (${first.error.code}: ${first.error.message})` : '';
        this.log.warn(`FCM: ${res.failureCount}/${tokens.length} доставок с ошибкой${detail}`);
      }
    } catch (e) {
      this.log.warn(`FCM sendEachForMulticast: ${e}`);
    }
  }
}
