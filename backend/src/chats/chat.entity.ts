import { Entity, PrimaryGeneratedColumn, Column, OneToMany, ManyToOne, JoinColumn, Index } from 'typeorm';
import { ChatMessage } from './chat-message.entity';
import { Order } from '../orders/order.entity';

@Entity('chats')
@Index('IDX_chats_org_client_phone', ['organizationId', 'clientPhone'])
export class Chat {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Только для превью (последний заказ в списке). Не использовать для поиска чата. */
  @Column({ name: 'order_id', type: 'uuid', nullable: true })
  lastOrderId: string | null;

  @ManyToOne(() => Order, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'order_id' })
  order: Order | null;

  @Column({ name: 'organization_id', type: 'uuid', nullable: true })
  organizationId: string | null;

  @Column({ name: 'client_phone', type: 'varchar', length: 32, nullable: true })
  clientPhone: string | null;

  /** Клиент открыл чат до этого момента — сообщения СТО после метки считаются непрочитанными (и отдельно — ожидающие ответа карточки). */
  @Column({ name: 'client_last_read_at', type: 'timestamptz', nullable: true })
  clientLastReadAt: Date | null;

  /** Сотрудник СТО открыл чат до этого момента — сообщения клиента после метки и новые заявки в ленте считаются непрочитанными. */
  @Column({ name: 'organization_last_read_at', type: 'timestamptz', nullable: true })
  organizationLastReadAt: Date | null;

  /** Оператор Control Center открыл чат поддержки (непрочитанное для вкладки «Поддержка»). */
  @Column({ name: 'internal_support_last_read_at', type: 'timestamptz', nullable: true })
  internalSupportLastReadAt: Date | null;

  @OneToMany(() => ChatMessage, (m) => m.chat, { cascade: true })
  messages: ChatMessage[];
}
