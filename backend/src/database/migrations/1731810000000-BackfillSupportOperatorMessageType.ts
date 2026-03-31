import { MigrationInterface, QueryRunner } from 'typeorm';

/** Дублируем признак ответа поддержки в message_type для клиентов без поля is_from_support_operator в кэше/WS. */
export class BackfillSupportOperatorMessageType1731810000000 implements MigrationInterface {
  name = 'BackfillSupportOperatorMessageType1731810000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      UPDATE "chat_messages"
      SET "message_type" = 'support_operator_reply'
      WHERE "is_from_support_operator" = true
        AND ("message_type" IS NULL OR "message_type" = '')
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      UPDATE "chat_messages"
      SET "message_type" = NULL
      WHERE "message_type" = 'support_operator_reply'
        AND "is_from_support_operator" = true
    `);
  }
}
