import { MigrationInterface, QueryRunner, TableColumn } from 'typeorm';

export class UserNotificationPreferences1731900000000 implements MigrationInterface {
  name = 'UserNotificationPreferences1731900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.addColumn(
      'users',
      new TableColumn({
        name: 'notification_preferences',
        type: 'jsonb',
        isNullable: true,
      }),
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.dropColumn('users', 'notification_preferences');
  }
}
