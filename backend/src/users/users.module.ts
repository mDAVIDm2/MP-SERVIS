import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './user.entity';
import { UserOrganizationMembership } from './user-organization-membership.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { OrganizationsModule } from '../organizations/organizations.module';
import { OrganizationInvitation } from '../organizations/organization-invitation.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, UserOrganizationMembership, StaffMember, OrganizationInvitation]),
    forwardRef(() => OrganizationsModule),
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
