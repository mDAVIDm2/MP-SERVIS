import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Chat } from './chat.entity';

@Entity('chat_messages')
export class ChatMessage {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'chat_id' })
  chatId: string;

  @ManyToOne(() => Chat, (c) => c.messages, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'chat_id' })
  chat: Chat;

  @Column({ type: 'text', default: '' })
  text: string;

  @Column({ name: 'is_from_client', default: false })
  isFromClient: boolean;

  /** Ответ оператора поддержки (internal API). В чате поддержки не путать с сообщением сотрудника СТО. */
  @Column({ name: 'is_from_support_operator', default: false })
  isFromSupportOperator: boolean;

  /** Источник обращения в поддержку: client | business (только для сообщений автора обращения). */
  @Column({ name: 'support_channel', type: 'varchar', length: 16, nullable: true })
  supportChannel: string | null;

  @Column({ name: 'is_system', default: false })
  isSystem: boolean;

  @Column({ type: 'timestamptz', default: () => 'CURRENT_TIMESTAMP' })
  at: Date;

  @Column({ name: 'approval_items', type: 'jsonb', nullable: true })
  approvalItems: unknown;

  @Column({ name: 'approval_status', type: 'varchar', length: 20, nullable: true })
  approvalStatus: string | null;

  /** Предложенное СТО время приёма (при подтверждении/корректировке заказа). */
  @Column({ name: 'proposed_date_time', type: 'timestamptz', nullable: true })
  proposedDateTime: Date | null;

  /** Заказ, к которому относится сообщение (карточка согласования и т.д.). */
  @Column({ name: 'order_id', type: 'uuid', nullable: true })
  orderId: string | null;

  /** Тип сообщения: 'booking_card' — заявка клиента (без кнопок согласования), 'approval_request' — запрос согласования от СТО. */
  @Column({ name: 'message_type', type: 'varchar', length: 32, nullable: true })
  messageType: string | null;

  /** Снимок списка услуг для карточки «Заявка отправлена» (только для message_type = booking_card). Не approval_items. */
  @Column({ name: 'order_items_snapshot', type: 'jsonb', nullable: true })
  orderItemsSnapshot: unknown;
}
