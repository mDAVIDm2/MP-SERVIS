import { StaffMember } from './staff-member.entity';
export declare class MasterSchedule {
    id: string;
    masterId: string;
    dayOfWeek: number;
    startTime: string;
    endTime: string;
    isWorkingDay: boolean;
    master: StaffMember;
}
