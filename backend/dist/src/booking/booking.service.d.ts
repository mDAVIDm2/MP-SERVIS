import { Repository } from 'typeorm';
import { StaffMember } from '../organizations/staff-member.entity';
import { MasterSchedule } from '../organizations/master-schedule.entity';
import { Order } from '../orders/order.entity';
import { OrderItem } from '../orders/order-item.entity';
import { OrganizationsService } from '../organizations/organizations.service';
export interface ServiceItemInput {
    service_id?: string;
    estimated_minutes: number;
    required_skill?: string;
}
export interface AvailableSlotsDto {
    organization_id: string;
    date: string;
    service_ids?: string[];
    items?: ServiceItemInput[];
}
export interface TimeSlot {
    start: string;
    end: string;
    master_id: string;
    master_name: string;
    scheduling_mode?: string;
}
export declare class BookingService {
    private staffRepo;
    private scheduleRepo;
    private orderRepo;
    private orderItemRepo;
    private orgService;
    constructor(staffRepo: Repository<StaffMember>, scheduleRepo: Repository<MasterSchedule>, orderRepo: Repository<Order>, orderItemRepo: Repository<OrderItem>, orgService: OrganizationsService);
    getAvailableSlots(dto: AvailableSlotsDto): Promise<{
        slots: TimeSlot[];
        total_minutes: number;
        required_skills: string[];
        slot_duration_minutes: number;
        work_day_start: string;
        work_day_end: string;
        scheduling_mode: string;
        bay_count?: number;
    }>;
    private computeBayBasedSlots;
    clearTestOrders(): Promise<{
        deletedOrders: number;
        deletedItems: number;
    }>;
}
